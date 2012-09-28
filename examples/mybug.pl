#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use Getopt::Long::Descriptive;

use Bugzilla::Dashboard;

binmode STDOUT, ':utf8';

my ( $opt, $usage ) = describe_options(
    "%c %o ... ",
    [ 'user|u=s',     "username" ],
    [ 'password|p=s', "password" ],
    [ 'uri=s',        "the URI to connect to", ],
    [],
    [ 'help|h', "print usage" ],
);
print($usage->text), exit if $opt->help;

my %connect_info;
$connect_info{user}     = $opt->user     if $opt->user;
$connect_info{password} = $opt->password if $opt->password;
$connect_info{uri}      = $opt->uri      if $opt->uri;

my $dashboard = Bugzilla::Dashboard->new(%connect_info)
    or die "cannot connect to json-rpc server\n";

my @bugs = $dashboard->mybugs( $connect_info{user} );
for my $bug (@bugs) {
    say "ID: ", $bug->id;
    say "    SUMMARY: ", $bug->summary;
    say "    CREATOR: ", $bug->creator;
    say "    PRODUCT: ", $bug->product;
    say "  COMPONENT: ", $bug->component;
    say "    VERSION: ", $bug->version || q{};
    say "     ASSIGN: ", $bug->assigned_to;
    say "     UPDATE: ", $bug->last_change_time;
    say "     CREATE: ", $bug->creation_time;
}
