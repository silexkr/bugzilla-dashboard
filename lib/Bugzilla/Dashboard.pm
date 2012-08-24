package Bugzilla::Dashboard;

use 5.010;
use utf8;
use strict;
use warnings;

use Data::Dumper;



sub new {
    my $class = shift;
    my %account = @_;

    return bless \%account, $class;
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

sub _common {
    # JSON::RPC 로 연결되는 공통부분을 또 빼야겠다..
}

sub connect {
    use HTTP::Cookies;
    use JSON::RPC::Legacy::Client;

    package JSON::RPC::Legacy::ReturnObject; {
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

    } 1;

    my $self = shift;
    my $client = JSON::RPC::Legacy::Client->new;
    my $URI = $self->{uri};
    my $user = $self->{user};
    my $password = $self->{password};

    my $res = $client->call(
        $URI,
        { # callobj
            method => 'User.login',
            params => {
                login    => $user,
                password => $password,
            }
        }
    );

    die $client->status_line unless $res;
    die "Error: " . $res->error_message if $res->is_error;

    #
    # extract cookie and add cookie
    #
    my $cookie_jar = HTTP::Cookies->new( {} );
    $cookie_jar->extract_cookies( $res->obj );
    $client->ua->cookie_jar($cookie_jar);

    return $client;
}

#sub mybugs {
#    my $self = shift;
#
#    #
#    # get user info
#    #
#    $res = $client->call(
#        $URI,
#        { # callobj
#            method => "Bug.search",
#            params => {
#                assigned_to => [ $self->{user} ],
#            },  
#        },  
#        $cookie_jar,
#    );
#
#    die $client->status_line unless $res;
#    die "Error: " . $res->error_message if $res->is_error;
#
#    return $res->result;
#}

1;
