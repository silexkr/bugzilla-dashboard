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
    "%c %o <bug id> [ <bug id> ... ]",
    [ 'user|u=s',     "username" ],
    [ 'password|p=s', "password" ],
    [ 'uri=s',        "the URI to connect to" ],
    [],
    [ 'blocks|b=s',     "add/remove blocks" ],
    [],
    [ 'help|h', "print usage" ],
);

my @ids = @ARGV;

print($usage->text), exit if     $opt->help;
print($usage->text), exit unless @ids;
print($usage->text), exit unless $opt->blocks;

my %connect_info;
$connect_info{user}     = $opt->user     if $opt->user;
$connect_info{password} = $opt->password if $opt->password;
$connect_info{uri}      = $opt->uri      if $opt->uri;

my $dashboard = Bugzilla::Dashboard->new(%connect_info)
    or die "cannot connect to json-rpc server\n";

{
    my %blocks = (
        add    => [],
        remove => [],
    );
    for ( split /,/, $opt->blocks ) {
        push @{ $blocks{add} },    $1 when /^\+?(\d+)$/;
        push @{ $blocks{remove} }, $1 when /^\-(\d+)$/;
    }

    my $bugs_info = $dashboard->update_bug(
        ids    => \@ids,
        blocks => {
            add    => $blocks{add},
            remove => $blocks{remove},
        },
    );

    if ($bugs_info) {
        use Data::Dumper;
        say Dumper $bugs_info;
    }
    else {
        say "Error: " . $dashboard->error;
    }
}
