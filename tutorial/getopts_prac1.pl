#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Getopt::Long::Descriptive;

my %defines;

my ( $opt, $usage ) = describe_options(
    "$0 <category> <method> [ <params1> ... ]",

    [ 'category|c=s', "Category included method" ],
    [ 'method|m=s'  , "method to calling"	     ],
    #[ 'params|p=s' => \%defines,    "Parameter for method"      , ],
    #[ 'params|p=s'  , "Params"                   ],
    [],
    [ 'verbose|v'   ,  "print detail"    ],
    [ 'help|h'      ,  "print this"    ],
);

print($usage->text), exit if $opt->help;
#print($usage->text), exit unless @ARGV;

#my ( $opt, $usage ) = describe_options(
#    "$0 %o <command> [ <param1> ... ]",
#    [ 'from|f=s',     "mail from",     { default => $MAIL_FROM   } ],
#    [ 'to|t=s',       "mail to",       { default => $MAIL_TO     } ],
#    [ 'format=s',     "mail format",   { default => $MAIL_FORMAT } ],
#    [ 'sendmail|s=s', "sendmail path", { default => $SENDMAIL    } ],
#    [ 'host=s',       "host name",     { default => $HOST        } ],
#    [],
#    [ 'verbose|v',  "print extra stuff"            ],
#    [ 'help',       "print usage message and exit" ],
#);
