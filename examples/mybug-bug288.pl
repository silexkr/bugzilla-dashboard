#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use Data::Dumper;
use HTTP::Cookies;
use JSON::RPC::Legacy::Client;
use Getopt::Long::Descriptive;

use Bugzilla::Dashboard::Bug;

binmode STDOUT, ':utf8';

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
      [ 'password|w=s', "password" ],
      [
        'uri=s',
        "the URI to connect to",
        { default => "http://bugs.silex.kr/jsonrpc.cgi" }
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
my $password = $opt->password;
#my $method_params = $opt->class . "." . $opt->method;

say $usage->text if $opt->help;

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

#
# get user info
#
$res = $client->call(
    $URI,
    { # callobj
        method => "Bug.search",
        params => {
            assigned_to => [ 'jeho.sung@silex.kr' ],
        },
    },
    $cookie_jar,
);

die $client->status_line unless $res;
die "Error: " . $res->error_message if $res->is_error;

my $result = $res->result;

my @bugs = Bugzilla::Dashboard::Bug->new( @{ $result->{bugs} } );
for my $bug (@bugs) {
    say "ID: ", $bug->id;
    say "    SUMMARY: ", $bug->summary;
    say "    CREATOR: ", $bug->creator;
    say "     ASSIGN: ", $bug->assigned_to;
    say "     UPDATE: ", $bug->last_change_time;
    say "     CREATE: ", $bug->creation_time;
}
