package Bugzilla::Dashboard::Attachment;

use utf8;
use strict;
use warnings;

use DateTime::Format::ISO8601;

my @exporting_methods = qw( 
    size
    creation_time
    last_change_time
    id
    bug_id
    file_name
    summary
    content_type
    is_private
    is_obsolete
    is_patch
    creator
);

for my $method (@exporting_methods) {
   eval qq| sub $method { \$_[0]->{_$method}; } |; 
}

sub new {
    my ( $class, @attachment_infos ) = @_;

    my @attachments;
    for my $ainfo (@attachment_infos) {
        next unless ref($ainfo) eq 'HASH';

        my %_rename = map { ( "_$_" => $ainfo->{$_} ) } keys %$ainfo;
        for my $key ( qw( last_change_time creation_time ) ) {
            next unless $ainfo->{$key};
            $_rename{"_$key"} = DateTime::Format::ISO8601->parse_datetime(
                $ainfo->{$key},
            );
        }
        my $attachment = bless \%_rename, $class;

        push @attachments, $attachment;
    }

    return @attachment_infos == 1 ? $attachments[0] : @attachments;
}

1;
