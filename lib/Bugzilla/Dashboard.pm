package Bugzilla::Dashboard;

use utf8;
use strict;
use warnings;

use HTTP::Cookies;
use JSON::RPC::Legacy::Client;
use List::Util qw( max );

use Bugzilla::Dashboard::Bug;
use Bugzilla::Dashboard::Attachment;

{
    package JSON::RPC::Legacy::ReturnObject; 
    {
        no warnings 'redefine';
        sub new {
            my ($class, $obj, $json) = @_;
            my $content = ( $json || JSON->new->utf8 )->decode( $obj->content );

            my $self = bless {
                jsontext => $obj->content,
                content  => $content,
                obj      => $obj,
            }, $class;

            $content->{error} ? $self->is_success(0) : $self->is_success(1);
            $content->{version} ? $self->version(1.1) : $self->version(0);

            $self;
        }
    }

    sub obj {
        $_[0]->{obj} = $_[1] if defined $_[1];
        $_[0]->{obj};
    }
}

sub new {
    my $class  = shift;
    my %params = @_;

    my $self = bless {
        %params,
        _cookie  => HTTP::Cookies->new( {} ),
        _error   => q{},
        _jsonrpc => JSON::RPC::Legacy::Client->new,
    }, $class;

    # 이해 안가는 부분
    $self->connect or return;

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
    my $res = $client->call(
        $self->{uri},
        { # callobj
            method => 'User.login',
            params => {
                login    => $self->{user},
                password => $self->{password},
            }
        }
    ); 

    unless ($res) {
        $self->{_error} = $client->status_line;
        return;
    }

    if ( $res->is_error ) {
        $self->{_error} = $res->error_message;
        return;
    }
        
    #
    # extract cookie and add cookie
    #
    $self->_cookie->extract_cookies( $res->obj );
    $client->ua->cookie_jar( $self->_cookie );

    return $client;
}

sub mybugs {
    my $self = shift;

    return unless $self->_jsonrpc;
    return unless $self->_cookie;

    #
    # get user info
    #
    my $client = $self->_jsonrpc;
    my $res = $client->call(
        $self->{uri},
        { # callobj
            method => "Bug.search",
            params => {
                assigned_to => [ $self->{user} ],
            },  
        },  
        $self->_cookie,
    );

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
    return unless $result->{bugs};

    my @bugs = Bugzilla::Dashboard::Bug->new( @{ $result->{bugs} } );

    return @bugs;
}

sub history {
    my ( $self, @ids ) = @_;

    return unless $self->_jsonrpc;
    return unless $self->_cookie;
    return unless @ids;

    my $client = $self->_jsonrpc;
    my $res = $client->call(
        $self->{uri},
        { # callobj
            method => "Bug.history",
            params => {
                ids => \@ids,
            },  
        },  
        $self->_cookie,
    );

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
    my $res = $client->call(
        $self->{uri},
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

1;
