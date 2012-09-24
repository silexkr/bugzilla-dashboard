package Bugzilla::Dashboard;

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
        %params,
        _cookie  => HTTP::Cookies->new( {} ),
        _error   => q{},
        _jsonrpc => JSON::RPC::Legacy::Client->new,
    }, $class;

    $self->connect or warn($self->error), return;

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

1;
