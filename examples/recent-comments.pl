#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use DateTime;
use Getopt::Long::Descriptive;

use Bugzilla::Dashboard;

binmode STDOUT, ":utf8";

my $COUNT = 10;
my $PAGE  = 0;

my ( $opt, $usage ) = describe_options(
    "%c %o ... ",
    [ 'user|u=s',      "username" ],
    [ 'password|p=s',  "password" ],
    [ 'uri=s',         "the URI to connect to", ],
    [ 'count|c=i',     "count (default: $COUNT)", { default => $COUNT } ],
    [ 'page|p=i',      "page (default: $PAGE)",   { default => $PAGE  } ],
    [],
    [ 'help|h', "print usage" ],
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

my @comments = $dashboard->recent_comments( $opt->count, $opt->page );

for my $comment (@comments) {
    my $text = $comment->text;
    $text =~ s/^/        /gms;

    say "ID: ",                $comment->id;
    say "    BUG_ID: ",        $comment->bug_id;
    say "    ATTACHMENT_ID: ", $comment->attachment_id // q{}; # 4.4 only
    say "    COUNT: ",         $comment->count         // q{}; # 4.4 only
    say "    CREATOR: ",       $comment->creator;
    say "    TIME: ",          $comment->time;
    say "    CREATION_TIME: ", $comment->creation_time // q{}; # 4.4 only
    say "    IS_PRIVATE: ",    $comment->is_private;
    say "    TEXT:";
    say $text;
}
