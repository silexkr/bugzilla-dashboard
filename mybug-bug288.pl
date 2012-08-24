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
#my $method_params = $opt->class . "." . $opt->method;

say $usage->text if $opt->help;

my $res = $client->call(
    $URI,
    { # callobj
        method => 'User.login',
        params => {
            login    => $user,
            password => $passwd,
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
    say ref($bug);
    say "ID: ", $bug->id;
    say "    SUMMARY: ", $bug->summary;
    say "    CREATOR: ", $bug->creator;
    say "     ASSIGN: ", $bug->assigned_to;
    say "     UPDATE: ", $bug->last_change_time;
    say "     CREATE: ", $bug->creation_time;
}


__DATA__


# case 1
use Bugzilla::Dashboard::Bug;

my @bugs;
for my $bug ( @{ $result->{bugs} } ) {
    my $bug_obj = Bugzilla::Dashboard::Bug->new( $bug );
    push @bugs, $bug_obj;
}

# case 2
use Bugzilla::Dashboard::Bug;

my @bugs = Bugzilla::Dashboard::Bug->new( @{ $result->{bugs} } );


Bugzilla::Dashboard

my $bug = Bugzilla::Dashboard::Bug->new( $hash_ref );

# read-only method
$bug->priority
$bug->creator
$bug->blocks
$bug->last_change_time
$bug->assigned_to
$bug->creation_time
$bug->id
$bug->depends_on
$bug->resolution
$bug->classification
$bug->alias
$bug->status
$bug->summary
$bug->deadline
$bug->component
$bug->product
$bug->is_open







#for my $bugs_array ( @{ $result->{bugs} } ) {
#    for my $bugs_attr ( keys %{ $bugs_array } ) {
#            if (defined $bugs_array->{$bugs_attr} ){
#                printf("%20s: %s\n", $bugs_attr, $bugs_array->{$bugs_attr});
#        }
#    }
#}

__DATA__

$res->result              # scalar = hash ref
$res->result->{bugs}      # scalar = array ref
$res->result->{bugs}->[0] # scalar = hash ref
$res->result->{bugs}[0]   # scalar = hash ref

my $result = $res->result;
$result                   # scalar = hash ref
$result->{bugs}           # scalar = array ref
$result->{bugs}->[0]      # scalar = hash ref
$result->{bugs}[0]        # scalar = hash ref

say for keys %{ $result->{bugs}[0] }; # standard way
say for keys $result->{bugs}[0];      # 5.14 only
