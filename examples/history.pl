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
    [ 'user|u=s',     'username' ],
    [ 'password|p=s', 'password' ],
    [ 'uri=s',        'the URI to connect to', ],
    [],
    [ 'help|h', 'print usage' ],
);
print($usage->text), exit if $opt->help;

my %connect_info;
$connect_info{user}     = $opt->user     if $opt->user;
$connect_info{password} = $opt->password if $opt->password;
$connect_info{uri}      = $opt->uir      if $opt->uri;

my $dashboard = Bugzilla::Dashboard->new(%connect_info)
    or die "cannot connect to json-rpc server\n";

my $history = $dashboard->history(185);

say Dumper $history;
