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
    [
        'password|w=s', "password",
        { default => '' }
    ],
    [
        'uri=s',     "the URI to connect to",
        { default => "http://bugs.silex.kr/jsonrpc.cgi" }
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
$dashboard->connect;
my $history = $dashboard->history(185);

use Data::Dumper;
say Dumper $history;
