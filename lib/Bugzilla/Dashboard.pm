package Bugzilla::Dashboard;

use 5.010;
use utf8;
use strict;
use warnings;

use CHI;
use HTTP::Cookies;
use JSON::RPC::Legacy::Client;
use List::Util qw( max );
use Try::Tiny;

use Bugzilla::Dashboard::Attachment;
use Bugzilla::Dashboard::Bug;
use Bugzilla::Dashboard::Comment;

sub new {
    my $class  = shift;
    my %params = @_;

    my $self = bless {
        uri      => $ENV{BUGZILLA_DASHBOARD_URI},
        user     => $ENV{BUGZILLA_DASHBOARD_USER},
        password => $ENV{BUGZILLA_DASHBOARD_PASSWORD},
        remember => 0,
        connect  => 0,
        token    => q{},
        %params,
        _cache   => CHI->new( driver => 'File', root_dir => './cache' ),
        _error   => q{},
        _jsonrpc => JSON::RPC::Legacy::Client->new,
    }, $class;

    if ( $self->{connect} ) {
        $self->do_connect or warn($self->error);
    }

    return $self;
}

sub _cache {
    my $self = shift;
    return $self->{_cache};
}

sub error {
    my $self = shift;
    return $self->{_error};
}

sub _jsonrpc {
    my $self = shift;
    return $self->{_jsonrpc};
}

sub uri {
    my $self = shift;
    return $self->{uri};
}

sub user {
    my $self = shift;
    return $self->{user};
}

sub password {
    my $self = shift;
    return $self->{password};
}

sub remember {
    my $self = shift;
    return $self->{remember};
}

sub connect {
    my $self = shift;
    return $self->{connect};
}

sub token {
    my $self = shift;
    return $self->{token};
}

sub do_connect {
    my $self = shift;

    $self->{_error} = 'invalid json rpc object', return unless $self->_jsonrpc;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => 'User.login',
                params => {
                    login    => $self->user,
                    password => $self->password,
                    remember => $self->remember,
                }
            }
        );
    };

    unless ($res) {
        $self->{_error} = $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        $self->{_error} = $res->error_message;
        warn $res->error_message;
        return;
    }

    $self->{connect} = 1;
    $self->{token}   = $res->content->{result}{token};

    return $self;
}

sub search {
    my ( $self, %params ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->token;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.search",
                params => {
                    Bugzilla_token => $self->token,
                    include_fields => [qw(
                        priority
                        creator
                        blocks
                        last_change_time
                        assigned_to
                        creation_time
                        id
                        depends_on
                        resolution
                        classification
                        alias
                        status
                        summary
                        deadline
                        component
                        product
                        is_open
                    )],
                    %params,
                },
            },
        );
    };

    unless ($res) {
        $self->{_error} = 'Bug.search: ' . $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        $self->{_error} = 'Bug.search: ' . $res->error_message;
        return;
    }

    my $result = $res->result;
    return unless $result;
    return unless $result->{bugs};

    my @bugs = Bugzilla::Dashboard::Bug->new( @{ $result->{bugs} } );

    return @bugs;
}

sub generate_query_params {
    my ( $self, $query ) = @_;

    my @status = qw(
        UNCONFIRMED
        CONFIRMED
        IN_PROGRESS
        RESOLVED
        VERIFIED
    );

    my @resolution = qw(
        FIXED
        INVALID
        WONTFIX
        DUPLICATE
        WORKSFORME
    );

    my %params = (
        alias       => [],
        assigned_to => [],
        component   => [],
        id          => [],
        priority    => [],
        product     => [],
        resolution  => [],
        status      => [],
        summary     => [],
    );

    my @keywords = split(/ /, $query);
    for my $keyword (@keywords) {
        use experimental qw( smartmatch );

        if ( $keyword eq 'OPEN' ) {
            push @{ $params{status} }, qw( UNCONFIRMED CONFIRMED IN_PROGRESS );
        }
        elsif ( $keyword ~~ \@status ) {
            push @{ $params{status} }, $keyword;
        }
        elsif ( $keyword ~~ \@resolution ) {
            push @{ $params{resolution} }, $keyword;
        }
        elsif ( $keyword =~ /^P([1-5\-])$/ ) {
            given ($1) {
                push @{ $params{priority} }, 'HIGHEST' when '1';
                push @{ $params{priority} }, 'HIGH'    when '2';
                push @{ $params{priority} }, 'NORMAL'  when '3';
                push @{ $params{priority} }, 'LOW'     when '4';
                push @{ $params{priority} }, 'LOWEST'  when '5';
                push @{ $params{priority} }, '---'     when '-';
                default { push @{ $params{priority} }, '---'; }
            }
        }
        elsif ( $keyword =~ /^P(\d)-(\d)$/ ) {
            my $first  = $1;
            my $second = $2;
            my @priorities = $1 > $2 ? ( $2 .. $1 ) : ( $1 .. $2 );
            for (@priorities) {
                push @{ $params{priority} }, 'HIGHEST' when 1;
                push @{ $params{priority} }, 'HIGH'    when 2;
                push @{ $params{priority} }, 'NORMAL'  when 3;
                push @{ $params{priority} }, 'LOW'     when 4;
                push @{ $params{priority} }, 'LOWEST'  when 5;
                default { push @{ $params{priority} }, '---'; }
            }
        }
        elsif ( $keyword =~ /^@(.+)$/ ){
            push @{ $params{assigned_to} }, $1;
        }
        elsif ( $keyword =~ /^:(.+)$/ ){
            push @{ $params{component} }, $1;
        }
        elsif ( $keyword =~ /^;(.+)$/ ){
            push @{ $params{product} }, $1;
        }
        elsif ( $keyword =~ /^#(.+)$/ ){
            push @{ $params{summary} }, $1;
        }
        elsif ( $keyword =~ /^(\d+)$/ ) {
            push @{ $params{id} }, $keyword;
        }
        else {
            push @{ $params{alias} }, $keyword;
        }
    }

    my %filtered_params = map { @{ $params{$_} } ? ( $_ => $params{$_} ) : () } keys %params;

    return %filtered_params;
}

sub bugs {
    my ( $self, @ids ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->token;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.get",
                params => {
                    Bugzilla_token => $self->token,
                    include_fields => [qw(
                        priority
                        creator
                        blocks
                        last_change_time
                        assigned_to
                        creation_time
                        id
                        depends_on
                        resolution
                        classification
                        alias
                        status
                        summary
                        deadline
                        component
                        product
                        is_open
                    )],
                    permissive => 1,
                    ids        => \@ids,
                },
            },
        );
    };

    unless ($res) {
        $self->{_error} = 'Bug.get: ' . $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        $self->{_error} = 'Bug.get: ' . $res->error_message;
        return;
    }

    my $result = $res->result;
    return unless $result;
    return unless $result->{bugs};

    my @bugs = Bugzilla::Dashboard::Bug->new( @{ $result->{bugs} } );

    return @bugs;
}

sub mybugs {
    my ( $self, $user ) = @_;

    my %search_params = $self->generate_query_params(
        sprintf( '@%s OPEN', $user || $self->user )
    );
    my @bugs = $self->search( %search_params );

    return @bugs;
}

sub history {
    my ( $self, @ids ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->token;
    return unless @ids;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.history",
                params => {
                    Bugzilla_token => $self->token,
                    ids            => \@ids,
                },
            },
        );
    };

    unless ($res) {
        $self->{_error} = $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        $self->{_error} = $res->error_message;
        return;
    }

    return $res->result;
}

sub attachments {
    my ( $self, @ids ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->token;
    return unless @ids;

    #
    # load from cache
    #
    my @uncached_ids;
    my %cached_ids;
    for my $id (@ids) {
        my $data = $self->_cache->get( "attachment.$id" );
        if ( defined $data ) {
            $cached_ids{$id} = $data;
            next;
        }

        push @uncached_ids, $id;
    }
    warn "attachment cached hit: " . join( ', ', sort keys %cached_ids ) . "\n" if %cached_ids;

    unless (@uncached_ids) {
        my @attachments = Bugzilla::Dashboard::Attachment->new(
            map { $cached_ids{$_} } @ids
        );

        return @attachments;
    }

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.attachments",
                params => {
                    Bugzilla_token => $self->token,
                    attachment_ids => \@uncached_ids,
                    include_fields => [qw(
                        bug_id
                        content_type
                        creation_time
                        creator
                        file_name
                        id
                        is_obsolete
                        is_patch
                        is_private
                        last_change_time
                        size
                        summary
                    )],
                },
            },
        );
    };

    unless ($res) {
        $self->{_error} = 'Bug.attachments: ' . $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        $self->{_error} = 'Bug.attachments: ' . $res->error_message;
        return;
    }

    my $result = $res->result;
    return unless $result;
    return unless $result->{attachments};

    #
    # save to cache
    #
    for my $id ( keys %{ $result->{attachments} } ) {
        next unless defined $result->{attachments}{$id};
        $self->_cache->set( "attachment.$id", $result->{attachments}{$id} );
    }

    my @attachments = Bugzilla::Dashboard::Attachment->new(
        map  {
            $cached_ids{$_}           ? $cached_ids{$_}
            : $result->{attachments}{$_} ? $result->{attachments}{$_}
            : ()
            ;
        } @ids,
    );

    return @attachments;
}

sub recent_attachments {
    my ( $self, $count, $page ) = @_;

    return unless $count;

    $page ||= 0;

    my $end   = $self->get_last_attachment_id - ( $count * $page );
    my $start = $end - $count + 1;

    return $self->attachments( reverse $start .. $end );
}

sub comments {
    my ( $self, @ids ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->token;
    return unless @ids;

    #
    # load from cache
    #
    my @uncached_ids;
    my %cached_ids;
    for my $id (@ids) {
        my $data = $self->_cache->get( "comment.$id" );
        if ( defined $data ) {
            $cached_ids{$id} = $data;
            next;
        }

        push @uncached_ids, $id;
    }
    warn "comment cached hit: " . join( ', ', sort keys %cached_ids ) . "\n" if %cached_ids;

    unless (@uncached_ids) {
        my @comments = Bugzilla::Dashboard::Comment->new(
            map { $cached_ids{$_} } @ids
        );

        return @comments;
    }

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.comments",
                params => {
                    Bugzilla_token => $self->token,
                    comment_ids    => \@uncached_ids,
                    include_fields => [qw(
                        id
                        bug_id
                        attachment_id
                        count
                        text
                        creator
                        time
                        creation_time
                        is_private
                    )],
                },
            },
        );
    };

    unless ($res) {
        $self->{_error} = 'Bug.comments: ' . $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        $self->{_error} = 'Bug.comments: ' . $res->error_message;
        return;
    }

    my $result = $res->result;
    return unless $result;
    return unless $result->{comments};

    #
    # save to cache
    #
    for my $id ( keys %{ $result->{comments} } ) {
        next unless defined $result->{comments}{$id};
        $self->_cache->set( "comment.$id", $result->{comments}{$id} );
    }

    my @comments = Bugzilla::Dashboard::Comment->new(
        map  {
            $cached_ids{$_}           ? $cached_ids{$_}
            : $result->{comments}{$_} ? $result->{comments}{$_}
            : ()
            ;
        } @ids,
    );

    return @comments;
}

sub recent_comments {
    my ( $self, $count, $page ) = @_;

    return unless $count;

    $page ||= 0;

    my $end   = $self->get_last_comment_id - ( $count * $page );
    my $start = $end - $count + 1;

    return $self->comments( reverse $start .. $end );
}

sub create_bug {
    my ( $self, %params ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->token;

    $self->{_error} = 'Bug.create: product is needed',     return unless $params{product};
    $self->{_error} = 'Bug.create: component is needed',   return unless $params{component};
    $self->{_error} = 'Bug.create: summary is needed',     return unless $params{summary};
    $self->{_error} = 'Bug.create: version is needed',     return unless $params{version};
    $self->{_error} = 'Bug.create: description is needed', return unless $params{description};

    my $client = $self->_jsonrpc;
    my $res = try {
        # http://www.bugzilla.org/docs/tip/en/html/api/Bugzilla/WebService/Bug.html#create
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.create",
                params => {
                    Bugzilla_token => $self->token,
                    %params,
                },
            },
        );
    };

    unless ($res) {
        $self->{_error} = 'Bug.create: ' . $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        use experimental qw( smartmatch );

        $self->{_error} = 'Bug.comments: ';
        given ( $res->obj->code ) {
            $self->{_error} .= '51 (Invalid Object)'            when 51;
            $self->{_error} .= '103 (Invalid Alias)'            when 103;
            $self->{_error} .= '104 (Invalid Field)'            when 104;
            $self->{_error} .= '105 (Invalid Component)'        when 105;
            $self->{_error} .= '106 (Invalid Product)'          when 106;
            $self->{_error} .= '107 (Invalid Summary)'          when 107;
            $self->{_error} .= '116 (Dependency Loop)'          when 116;
            $self->{_error} .= '120 (Group Restriction Denied)' when 120;
            $self->{_error} .= '504 (Invalid User)'             when 504;
            default { $self->{_error} .= $res->error_message; }
        }
        return;
    }

    my $result = $res->result;
    $self->{_error} = 'Bug.create: failed by unknwon reason', return unless $result;
    $self->{_error} = 'Bug.create: failed by unknwon reason', return unless $result->{id};

    return $result->{id};
}

sub update_bug {
    my ( $self, %params ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->token;

    $self->{_error} = 'Bug.update: ids is needed', return unless $params{ids};

    my $client = $self->_jsonrpc;
    my $res = try {
        # http://www.bugzilla.org/docs/tip/en/html/api/Bugzilla/WebService/Bug.html#update
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.update",
                params => {
                    Bugzilla_token => $self->token,
                    %params,
                },
            },
        );
    };

    unless ($res) {
        $self->{_error} = 'Bug.update ' . $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        use experimental qw( smartmatch );

        $self->{_error} = 'Bug.comments: ';
        given ( $res->obj->code ) {
            $self->{_error} .= '50 (Empty Field)'                when 50;
            $self->{_error} .= '52 (Input Not A Number)'         when 52;
            $self->{_error} .= '54 (Number Too Large)'           when 54;
            $self->{_error} .= '55 (Number Too Small)'           when 55;
            $self->{_error} .= '56 (Bad Date/Time)'              when 56;
            $self->{_error} .= '112 (See Also Invalid)'          when 112;
            $self->{_error} .= '115 (Permission Denied)'         when 115;
            $self->{_error} .= '116 (Dependency Loop)'           when 116;
            $self->{_error} .= '117 (Invalid Comment ID)'        when 117;
            $self->{_error} .= '118 (Duplicate Loop)'            when 118;
            $self->{_error} .= '119 (dupe_of Required)'          when 119;
            $self->{_error} .= '120 (Group Add/Remove Denied)'   when 120;
            $self->{_error} .= '121 (Resolution Required)'       when 121;
            $self->{_error} .= '122 (Resolution On Open Status)' when 122;
            $self->{_error} .= '123 (Invalid Status Transition)' when 123;
            default { $self->{_error} .= $res->error_message; }
        }
        return;
    }

    my $result = $res->result;
    $self->{_error} = 'Bug.update failed by unknwon reason', return unless $result;
    $self->{_error} = 'Bug.update failed by unknwon reason', return unless $result->{bugs};

    return $result->{bugs};
}

sub get_user {
    my ( $self, %params ) = @_;

    $self->{_error} = 'invalid json rpc object', return unless $self->_jsonrpc;
    $self->{_error} = 'invalid token',           return unless $self->token;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "User.get",
                params => {
                    Bugzilla_token => $self->token,
                    include_fields => [qw(
                        id
                        real_name
                        email
                        name
                        can_login
                        email_enabled
                        login_denied_text
                        groups
                        saved_searches
                        saved_reports
                    )],
                    %params,
                },
            },
        );
    };

    unless ($res) {
        $self->{_error} = 'User.get: ' . $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        use experimental qw( smartmatch );

        $self->{_error} = 'User.get: ';
        given ( $res->obj->code ) {
            $self->{_error} .= '51 (Bad Login Name or Group Name)'               when 51;
            $self->{_error} .= '304 (Authorization Required)'                    when 304;
            $self->{_error} .= '505 (User Access By Id or User-Matching Denied)' when 505;
            default { $self->{_error} .= $res->error_message; }
        }
        return;
    }

    my $result = $res->result;
    $self->{_error} = 'User.get failed by unknwon reason', return unless $result;
    $self->{_error} = 'User.get failed by unknwon reason', return unless $result->{users};

    my $users = $result->{users};

    return $users;
}

sub _get_last {
    my ( $self, $type, %params ) = @_;

    $self->{_error} = 'invalid json rpc object', return unless $self->_jsonrpc;
    $self->{_error} = 'invalid token',           return unless $self->token;

    my $method;
    {
        use experimental qw( smartmatch );
        given ($type) {
            $method = 'GetLast.bug'        when 'bug';
            $method = 'GetLast.comment'    when 'comment';
            $method = 'GetLast.attachment' when 'attachment';
        }
    }

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => $method,
                params => {
                    Bugzilla_token => $self->token,
                    # additional parameters
                    %params,
                },
            },
        );
    };

    unless ($res) {
        $self->{_error} = "$method " . $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        use experimental qw( smartmatch );

        $self->{_error} = "$method ";
        given ( $res->obj->code ) {
            $self->{_error} .= '51 (Bad Login Name or Group Name)'               when 51;
            $self->{_error} .= '304 (Authorization Required)'                    when 304;
            $self->{_error} .= '505 (User Access By Id or User-Matching Denied)' when 505;
            default { $self->{_error} .= $res->error_message; }
        }
        return;
    }

    my $result = $res->result;
    $self->{_error} = "$method no comment", return unless $result;

    return $result
}

sub get_last_bug_id {
    my ( $self, %params ) = @_;

    return $self->_get_last( 'bug', %params );
}

sub get_last_comment_id {
    my ( $self, %params ) = @_;

    return $self->_get_last( 'comment', %params );
}

sub get_last_attachment_id {
    my ( $self, %params ) = @_;

    return $self->_get_last( 'attachment', %params );
}

1;
