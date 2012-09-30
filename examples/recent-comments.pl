#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use DateTime;
use Getopt::Long::Descriptive;

use Bugzilla::Dashboard;

binmode STDOUT, ":utf8";

my $TIME_ZONE = 'Asia/Seoul';
my $FROM      = -1;
my $LIMIT     = 20;

my $dt = DateTime->now( time_zone => $TIME_ZONE );
$dt->add( days => $FROM );

my ( $opt, $usage ) = describe_options(
    "%c %o ... ",
    [ 'user|u=s',      "username" ],
    [ 'password|p=s',  "password" ],
    [ 'uri=s',         "the URI to connect to", ],
    [ 'limit|l=i',     "comments limit", { default => $LIMIT     } ],
    [ 'time_zone|t=s', "time_zone",      { default => $TIME_ZONE } ],
    [ 'from|f=s',      "Y-M-D",          { default => $dt->ymd   } ],
    [],
    [ 'help|h', "print usage" ],
);
print($usage->text), exit if $opt->help;

my ( $year, $month, $day );
if ( $opt->from =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
    $year  = $1;
    $month = $2;
    $day   = $3;
}

print( $usage->text ), exit unless $opt->limit > 0;
print( $usage->text ), exit unless $year >= 2012;
print( $usage->text ), exit unless $month;
print( $usage->text ), exit unless $day;

my %connect_info;
$connect_info{user}     = $opt->user     if $opt->user;
$connect_info{password} = $opt->password if $opt->password;
$connect_info{uri}      = $opt->uri      if $opt->uri;
$connect_info{connect}  = 1;

my $dashboard = Bugzilla::Dashboard->new(%connect_info)
    or die "cannot connect to json-rpc server\n";

my $user_dt = DateTime->new(
    year      => $year,
    month     => $month,
    day       => $day,
    time_zone => $opt->time_zone,
);
my $limit = $opt->limit;

my @comments = $dashboard->recent_comments( $user_dt, $limit );

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
