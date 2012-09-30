#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

use Getopt::Long::Descriptive;
use Encode qw/ decode_utf8 /;

use Bugzilla::Dashboard;

binmode STDIN,  ':utf8';
binmode STDOUT, ':utf8';

my ( $opt, $usage ) = describe_options(
    "%c %o ... ",
    [ 'user|u=s',      "username" ],
    [ 'password|p=s',  "password" ],
    [ 'uri=s',         "the URI to connect to", ],
    [],
    [ 'product=s',     "product", ],
    [ 'component=s',   "component", ],
    [ 'version=s',     "version", ],
    [ 'summary=s',     "summary", ],
    [],
    [ 'help|h', "print usage" ],
);
print($usage->text), exit if     $opt->help;
print($usage->text), exit unless $opt->product;
print($usage->text), exit unless $opt->component;
print($usage->text), exit unless $opt->summary;

my %connect_info;
$connect_info{user}     = $opt->user     if $opt->user;
$connect_info{password} = $opt->password if $opt->password;
$connect_info{uri}      = $opt->uri      if $opt->uri;
$connect_info{connect}  = 1;

my $dashboard = Bugzilla::Dashboard->new(%connect_info)
    or die "cannot connect to json-rpc server\n";

my $description;
while (<>) {
    chomp;
    last if m{^/quit$};
    $description .= "$_\n";
}
chomp $description;

my $summary   = decode_utf8( $opt->summary );
my $product   = decode_utf8( $opt->product );
my $component = decode_utf8( $opt->component );
my $version   = decode_utf8( $opt->version || q{} );

my $send = do {
    say "Create Bug ...";
    say "    SUMMARY: ", $summary;
    say "    PRODUCT: ", $product;
    say "  COMPONENT: ", $component;
    say "    VERSION: ", $version;
    say "DESCRIPTION:";

    my $text = $description;
    $text =~ s/^/        /gms;
    say $text;

    print "Send to Bugzilla? (y/n): ";
    my $input = <STDIN>;
    chomp $input;

    $input;
};

if ( $send =~ /^y$/i ) {
    my $bug = $dashboard->create_bug(
        product     => $product,
        component   => $component,
        version     => $version || q{},
        summary     => $summary,
        description => $description || q{},
    );

    if ($bug) {
        say "Posted to Bug $bug";
    }
    else {
        say "Error: " . $dashboard->error;
    }
}
