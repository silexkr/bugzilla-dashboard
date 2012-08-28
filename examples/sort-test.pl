#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use warnings;

my @users = (
    {
        id  => 'keedi',
        age => '32',
    },
    {
        id  => 'rumidier',
        age => '29',
    },
    {
        id  => 's_jeho',
        age => '27',
    },
    {
        id  => 'jeen',
        age => '29',
    },
    {
        id  => 'aanoaa',
        age => '31',
    },
);
my @sorted = bb_sort(sub { $_[0]{id} cmp $_[1]{id} }, @users);

say join( ", ", map( "$_->{id}($_->{age})", @users ) );
say join( ", ", map( "$_->{id}($_->{age})", @sorted ) );


sub bb_sort {
    my ( $cmp_func, @numbers ) = @_;

    $cmp_func = { $_[0] cmp $_[1] } unless $cmp_func;

    for ( my $i = 0; $i < @numbers; ++$i ) {
        for ( my $j = $i; $j < @numbers; ++$j ) {
            if ( $cmp_func->( $numbers[$i], $numbers[$j] ) > 0 ) {
                ( $numbers[$j], $numbers[$i] ) = ( $numbers[$i], $numbers[$j] );
            }
        }
    }

    return @numbers;
}
