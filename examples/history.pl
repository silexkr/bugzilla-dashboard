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
    "%c %o ... ",
    [ 'user|u=s',     "username" ],
    [ 'password|p=s', "password" ],
    [
        'uri=s',     "the URI to connect to",
        { default => "http://bugs.silex.kr/jsonrpc.cgi" },
    ],
    [],
    [ 'help|h',    "print usage" ],
);

print($usage->text), exit unless $opt->user;
print($usage->text), exit unless $opt->password;

my $dashboard = Bugzilla::Dashboard->new(
    uri      => $opt->uri,
    user     => $opt->user,
    password => $opt->password,
) or die "cannot connect to json-rpc server\n";

my $history = $dashboard->history(185);

say Dumper $history;
