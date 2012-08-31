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
    [ 'keyword|k=s',  "search keyword" ],
    [
        'uri=s',
        "the URI to connect to",
        { default => "http://bugs.silex.kr/jsonrpc.cgi" },
    ],
    [],
    [ 'help|h', "print usage" ],
);

print($usage->text), exit unless $opt->user;
print($usage->text), exit unless $opt->password;

my $dashboard = Bugzilla::Dashboard->new(
    uri      => $opt->uri,
    user     => $opt->user,
    password => $opt->password,
) or die "cannot connect to json-rpc server\n";

my @bugs = $dashboard->quick_search( $opt->{keyword} );
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
