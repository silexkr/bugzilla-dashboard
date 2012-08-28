#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use Data::Dumper;
use Getopt::Long::Descriptive;
use List::Util qw( max );

use Bugzilla::Dashboard;

binmode STDOUT, ':utf8';

my ( $opt, $usage ) = describe_options(
    "$0 <category> <method> [ <attachment id> ... ]",
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
) or die "cannot connect to json-rpc server\n";

my @attachments = $dashboard->recent_attachments(20); # number of recent attachments to fetch
for my $attachment (@attachments) {
    say "ID: ",                $attachment->id;
    say "    BUGID: ",         $attachment->bug_id;
    say "    CREATION_TIME: ", $attachment->creation_time;
    say "    UPDATE_TIME: ",   $attachment->last_change_time;
    say "    FILENAME: ",      $attachment->file_name;
    say "    SUMMARY: ",       $attachment->summary;
    say "    CONTENT_TYPE: ",  $attachment->content_type;
    say "    PRIVATE: ",       $attachment->is_private;
    say "    OBSOLETE: ",      $attachment->is_obsolete;
    say "    PATCH: ",         $attachment->is_patch;
    say "    CREATOR: ",       $attachment->creator;
}
