#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use Getopt::Long::Descriptive;

use Bugzilla::Dashboard;

binmode STDOUT, ":utf8";

my ( $opt, $usage ) = describe_options(
    "%c %o ... ",
    [ 'user|u=s',      "username" ],
    [ 'password|p=s',  "password" ],
    [ 'uri=s',         "the URI to connect to", ],
    [],
    [ 'help|h', "print usage" ],
);
print($usage->text), exit if $opt->help;

my %connect_info;
$connect_info{user}     = $opt->user     if $opt->user;
$connect_info{password} = $opt->password if $opt->password;
$connect_info{uri}      = $opt->uri      if $opt->uri;
$connect_info{connect}  = 1;

my $dashboard = Bugzilla::Dashboard->new(%connect_info)
    or die "cannot connect to json-rpc server\n";

my $bug = $dashboard->get_last_bug_id;
say "last bug id: $bug";

my $comment = $dashboard->get_last_comment_id;
say "last comment id: $comment";

my $attachment = $dashboard->get_last_attachment_id;
say "last attachment id: $attachment";
