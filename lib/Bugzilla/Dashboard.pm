package Bugzilla::Dashboard;

use 5.010;
use utf8;
use strict;
use warnings;

use HTTP::Cookies;
use JSON::RPC::Legacy::Client;
use List::Util qw( max );
use Try::Tiny;

use Bugzilla::Dashboard::Attachment;
use Bugzilla::Dashboard::Bug;
use Bugzilla::Dashboard::Comment;
use Bugzilla::Dashboard::Patch;

sub new {
    my $class  = shift;
    my %params = @_;

    my $self = bless {
        uri      => $ENV{BUGZILLA_DASHBOARD_URI},
        user     => $ENV{BUGZILLA_DASHBOARD_USER},
        password => $ENV{BUGZILLA_DASHBOARD_PASSWORD},
        connect  => 0,
        %params,
        _cookie  => HTTP::Cookies->new( {} ),
        _error   => q{},
        _jsonrpc => JSON::RPC::Legacy::Client->new,
    }, $class;

    if ( $self->{connect} ) {
        $self->connect or warn($self->error);
        return;
    }

    return $self;
}

sub _cookie {
    my $self = shift;
    return $self->{_cookie};
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

sub connect {
    my $self = shift;

    return unless $self->_jsonrpc;
    return unless $self->_cookie;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => 'User.login',
                params => {
                    login    => $self->user,
                    password => $self->password,
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

    #
    # extract cookie and add cookie
    #
    $self->_cookie->extract_cookies( $res->obj );
    $client->ua->cookie_jar( $self->_cookie );

    return $client;
}

sub search {
    my ( $self, %params ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->_cookie;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.search",
                params => {
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
            $self->_cookie,
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
    return unless $self->_cookie;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.get",
                params => {
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
            $self->_cookie,
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

    my @bugs = $self->search(
        assigned_to => [ $user || $self->user ],
        status      => [ qw( UNCONFIRMED CONFIRMED IN_PROGRESS ) ],
    );

    return @bugs;
}

sub history {
    my ( $self, @ids ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->_cookie;
    return unless @ids;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.history",
                params => {
                    ids => \@ids,
                },
            },
            $self->_cookie,
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
    return unless $self->_cookie;
    return unless @ids;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.attachments",
                params => {
                    attachment_ids => \@ids,
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
            $self->_cookie,
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

    my $result = $res->result;
    return unless $result;
    return unless $result->{attachments};

    my @attachments = Bugzilla::Dashboard::Attachment->new(
        map { $result->{attachments}{$_} } keys %{ $result->{attachments} }
    );

    return @attachments;
}

sub get_max_attachment_id {
    my ( $self, $basis ) = @_;

    $basis = 500 if !$basis || $basis < 500;

    my $max = $basis;
    my $end_point = 2 * $basis;
    while (1) {
        my @attachments = $self->attachments( $max .. $end_point );

        $max = max map { $_->id } @attachments;
        unless ($max) {
            $max       = 1;
            $end_point = $basis;
            next;
        }

        last if $max < $end_point;
        $end_point *= 2;
    }

    return $max;
}

sub recent_attachments {
    my ( $self, $count ) = @_;

    my $max_aid = $self->get_max_attachment_id;

    my $start       = $max_aid - $count + 1;
    my $end         = $max_aid;
    my @attachments = reverse sort { $a->id <=> $b->id } $self->attachments( $start .. $end );

    return @attachments;
}

sub comments {
    my ( $self, %params ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->_cookie;

    my $client = $self->_jsonrpc;
    my $res = try {
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.comments",
                params => {
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
                    %params,
                },
            },
            $self->_cookie,
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
    return unless $result->{comments} || $result->{bugs};

    if ( %{ $result->{comments} } ) {
        my @comments = Bugzilla::Dashboard::Comment->new(
            map {
                my $cinfo = $result->{comments}{$_};
                $cinfo ? $cinfo : ();
            } keys %{ $result->{comments} }
        );

        return @comments;
    }
    elsif ( %{ $result->{bugs} } ) {
        my %comments;
        for my $bugid ( keys %{ $result->{bugs} } ) {
            my $cinfo = $result->{bugs}{$bugid}{comments};
            if (@$cinfo) {
                $comments{$bugid} = [ Bugzilla::Dashboard::Comment->new(@$cinfo) ];
            }
        }

        return %comments;
    }

    return;
}

sub recent_comments {
    my ( $self, $dt, $limit ) = @_;

    return unless $dt;
    return unless $limit;

    my $iso8601_str = $dt->strftime('%Y-%m-%dT%H:%M:%S%z');

    my @bugs = $self->search(
        last_change_time => $iso8601_str,
        include_fields   => [qw( id )],
    );
    return unless @bugs;

    my %comments = $self->comments(
        ids       => [ map $_->id, @bugs ],
        new_since => $iso8601_str,
    );
    return unless %comments;

    my @comments;
    for my $bugid  ( keys %comments ) {
        push @comments, @{ $comments{$bugid} };
    }

    my $end_index = @comments < $limit ? $#comments : $limit - 1;
    @comments = ( sort { $b->id <=> $a->id } @comments )[ 0 .. $end_index ];

    return @comments;
}

sub create_bug {
    my ( $self, %params ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->_cookie;

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
                    %params,
                },
            },
            $self->_cookie,
        );
    };

    unless ($res) {
        $self->{_error} = 'Bug.create: ' . $client->status_line;
        return;
    }

    if ( $res->is_error ) {
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
    return unless $self->_cookie;

    $self->{_error} = 'Bug.update: ids is needed', return unless $params{ids};

    my $client = $self->_jsonrpc;
    my $res = try {
        # http://www.bugzilla.org/docs/tip/en/html/api/Bugzilla/WebService/Bug.html#update
        $client->call(
            $self->uri,
            { # callobj
                method => "Bug.update",
                params => {
                    %params,
                },
            },
            $self->_cookie,
        );
    };

    unless ($res) {
        $self->{_error} = 'Bug.update ' . $client->status_line;
        return;
    }

    if ( $res->is_error ) {
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

1;
