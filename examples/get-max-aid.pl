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
    "$0 <category> <method> [ <attachment count> ... ]",
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

my $attachment_count = shift;

my $dashboard = Bugzilla::Dashboard->new(
    uri      => $opt->uri,
    user     => $opt->user,
    password => $opt->password,
);
#
# readonly get method
#
say $dashboard->uri;
say $dashboard->user;
say $dashboard->password;

my $max = $dashboard->get_max_attachment_id;
say $max;

my $ret = $dashboard->attachments( $max - 9 .. $max );
for my $aid ( reverse sort { $a <=> $b } keys %{ $ret->{attachments} } ) {
    printf(
        "Bug %d(%d): [%s]: %s\n",
        $ret->{attachments}{$aid}{bug_id},
        $ret->{attachments}{$aid}{id},
        $ret->{attachments}{$aid}{file_name},
        $ret->{attachments}{$aid}{summary},
    );
}
