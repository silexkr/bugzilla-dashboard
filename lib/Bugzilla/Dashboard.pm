package Bugzilla::Dashboard;

use utf8;
use strict;
use warnings;

use HTTP::Cookies;
use JSON::RPC::Legacy::Client;

use Bugzilla::Dashboard::Bug;

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

    return bless {
        %params,
        _cookie  => HTTP::Cookies->new( {} ),
        _error   => q{},
        _jsonrpc => JSON::RPC::Legacy::Client->new,
    }, $class;
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

1;
