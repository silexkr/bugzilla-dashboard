package Bugzilla::Dashboard::Bug;

use utf8;
use strict;
use warnings;

use DateTime::Format::ISO8601;

my @exporting_methods = qw(
    priority
    creator
    blocks
    last_change_time
    assigned_to
    creation_time
    id
    depends_on
    resolution
    classification
    alias
    status
    summary
    deadline
    component
    product
    is_open
);

for my $method (@exporting_methods) {
    eval qq| sub $method { \$_[0]->{_$method}; } |;
}

sub new {
    my ( $class, @bug_infos ) = @_;

    my @bugs;
    for my $bug_info (@bug_infos) {
        next unless ref($bug_info) eq 'HASH';

        my %_rename = map { ( "_$_" => $bug_info->{$_} ) } keys %$bug_info;
        for my $key ( qw( last_change_time creation_time ) ) {
            next unless $bug_info->{$key};
            $_rename{"_$key"} = DateTime::Format::ISO8601->parse_datetime(
                $bug_info->{$key},
            );
        }
        my $bug = bless \%_rename, $class;

        push @bugs, $bug;
    }

    return @bug_infos == 1 ? $bugs[0] : @bugs;
}

1;
