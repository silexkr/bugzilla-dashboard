#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use Getopt::Long::Descriptive;

use Bugzilla::Dashboard;

binmode STDOUT, ':utf8';

my ( $opt, $usage ) = describe_options(
    "%c %o <comment id> [ <comment id> ... ]",
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

my @ids = @ARGV;
print($usage->text), exit unless @ids;

my $dashboard = Bugzilla::Dashboard->new(%connect_info)
    or die "cannot connect to json-rpc server\n";

my @comments = $dashboard->comments( comment_ids => \@ids );
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
