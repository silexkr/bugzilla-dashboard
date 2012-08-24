#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use Data::Dumper;
use Getopt::Long::Descriptive;
use Bugzilla::Dashboard;

binmode STDOUT, ':utf8';

my ( $opt, $usage ) = describe_options(
    "$0 <category> <method> [ <params1> ... ]",
    [
        'user|u=s',  "username",
        { default => 'jeho.sung@silex.kr' }
    ],
    [ 'password|w=s', "password" ],
    [
        'uri=s',     "the URI to connect to",
        { default => "http://jehos.silex.kr/bugzilla/jsonrpc.cgi" }
    ],
    [ 'class|c=s',  "method class" ],
    [ 'method|m=s', "method" ],
    [],
    [ 'verbose|v', "print detail" ],
    [ 'help|h',    "print this" ],
);

my $dashboard = Bugzilla::Dashboard->new(
    uri      => $opt->uri,
    user     => $opt->user,
    password => $opt->password,
);


#
# readonly get method
#
say $dashboard->uri;
say $dashboard->user;
say $dashboard->password;

#
# must call connect()
# before calling another method like mybugs()
#
#say Dumper $dashboard->connect;

#
# retrurns Bugzilla::Dashboard::Bug items
#
my @bugs = $dashboard->mybugs;
for my $bug (@bugs) {
    say "ID: ", $bug->id;
    say "    SUMMARY: ", $bug->summary;
    say "    CREATOR: ", $bug->creator;
    say "     ASSIGN: ", $bug->assigned_to;
    say "     UPDATE: ", $bug->last_change_time;
    say "     CREATE: ", $bug->creation_time;
}
