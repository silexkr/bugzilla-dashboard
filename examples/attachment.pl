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

# fetch recent 20 attachments
my @attachments = $dashboard->recent_attachments(20);
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
