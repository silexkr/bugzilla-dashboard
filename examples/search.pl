#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use Getopt::Long::Descriptive;
use Encode qw( decode_utf8 );

use Bugzilla::Dashboard;

binmode STDOUT, ':utf8';

my ( $opt, $usage ) = describe_options(
    "%c %o <query>",
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
$connect_info{uri}      = $opt->uir      if $opt->uri;

my $query = shift;
print($usage->text), exit unless $query;

my $dashboard = Bugzilla::Dashboard->new(%connect_info)
    or die "cannot connect to json-rpc server\n";

my %search_params = $dashboard->generate_query_params( decode_utf8($query) );
my @bugs = $dashboard->search(%search_params);
for my $bug (@bugs) {
    say "ID: ", $bug->id;
    say "    SUMMARY: ", $bug->summary;
    say "    CREATOR: ", $bug->creator;
    say "     ASSIGN: ", $bug->assigned_to;
    say "     UPDATE: ", $bug->last_change_time;
    say "     CREATE: ", $bug->creation_time;
    say "  COMPONENT: ", $bug->component;
    say "    PRODUCT: ", $bug->product;
}

__DATA__

# AVAILABLE CRITERIA
alias
assigned_to
component
creation_time
creator
id
last_change_time
limit
offset
op_sys
platform
priority
product
resolution
severity
status
summary
target_milestone
qa_contact
url
version
whiteboard
