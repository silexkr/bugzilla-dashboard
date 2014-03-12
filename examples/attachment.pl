#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use Getopt::Long::Descriptive;

use Bugzilla::Dashboard;

binmode STDOUT, ':utf8';

my $COUNT = 10;
my $PAGE  = 0;

my ( $opt, $usage ) = describe_options(
    "%c %o <count>",
    [ 'user|u=s',      "username" ],
    [ 'password|p=s',  "password" ],
    [ 'uri=s',         "the URI to connect to", ],
    [ 'count|c=i',     "count (default: $COUNT)", { default => $COUNT } ],
    [ 'page|p=i',      "page (default: $PAGE)",   { default => $PAGE  } ],
    [],
    [ 'help|h', 'print usage' ],
);
print($usage->text), exit if     $opt->help;
print($usage->text), exit unless $opt->count;

my %connect_info;
$connect_info{user}     = $opt->user     if $opt->user;
$connect_info{password} = $opt->password if $opt->password;
$connect_info{uri}      = $opt->uri      if $opt->uri;
$connect_info{connect}  = 1;

my $dashboard = Bugzilla::Dashboard->new(%connect_info)
    or die "cannot connect to json-rpc server\n";

my @attachments = $dashboard->recent_attachments( $opt->count, $opt->page );

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
