package Bugzilla::Dashboard::Comment;

use utf8;
use strict;
use warnings;

my @exporting_methods = qw(
    id
    bug_id
    attachment_id
    count
    text
    creator
    time
    creation_time
    is_private
);

for my $method (@exporting_methods) {
    eval qq| sub $method { \$_[0]->{_$method}; } |;
}

sub new {
    my ( $class, @comment_infos ) = @_;
    my @comments;

    for my $comment_info (@comment_infos) {
        next unless ref($comment_info) eq 'HASH';

        my %_rename = map { ( "_$_" => $comment_info->{$_} ) } keys %$comment_info;
        my $comment = bless \%_rename, $class;
        push @comments, $comment;
    }

    return @comment_infos == 1 ? $comments[0] : @comments;
}

1;
