#!/usr/bin/env perl 

use 5.010;
use utf8;
use strict;
use warnings;

use Data::Dumper;
use HTTP::Cookies;
use JSON::RPC::Legacy::Client;
use Getopt::Long::Descriptive;

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

package main;

my ( $opt, $usage ) = describe_options(
    "$0 <category> <method> [ <params1> ... ]",

      [
         'user|u=s', "username", 
        { default => 'jeho.sung@silex.kr' } 
      ],
      [ 'passwd|w=s', "password" ],
      [
        'uri=s',
        "the URI to connect to",
        { default => "http://jehos.silex.kr/bugzilla/jsonrpc.cgi" }
      ],
      [ 'class|c=s',  "method class"   ],
      [ 'method|m=s', "method"         ],
      [],
      [ 'verbose|v', "print detail"  ],
      [ 'help|h',    "print this"    ],
);


my $client = JSON::RPC::Legacy::Client->new;
my $URI = $opt->uri;
my $user = $opt->user;
my $passwd = $opt->passwd;
my $method_params = $opt->class . "." . $opt->method;


say $method_params;


say $usage->text if $opt->help;

my $res = $client->call(
    $URI,
    { # callobj
        method => 'User.login',
        params => {
            login     => $user,
            password => $passwd,
        }
    }
);
die $client->status_line unless $res;
die "Error: " . $res->error_message if $res->is_error;

#
# extract cookie and add cookie
#
my $cookie_jar = HTTP::Cookies->new({});
$cookie_jar->extract_cookies( $res->obj );
$client->ua->cookie_jar($cookie_jar);

#
# get user info
#
$res = $client->call(
    $URI,
    { # callobj
        method => $method_params,
        params => {
            names => [ 'jeho.sung@silex.kr' ],
        },
    },
    $cookie_jar,
);

die $client->status_line unless $res;
die "Error: " . $res->error_message if $res->is_error;
say Dumper $res->result;

