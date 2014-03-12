# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::GetLast::WebService;
use strict;
use warnings;
use base qw(Bugzilla::WebService);

use Bugzilla;
use Bugzilla::DB;

# This can be called as GetLast.bug() from the WebService.
sub bug {
    my $dbh = Bugzilla->switch_to_shadow_db();

    # prepare a query using DB methods
    my $sth = $dbh->prepare(
        'SELECT bug_id FROM bugs ORDER BY bug_id DESC ' . $dbh->sql_limit(1)
    );

    # Execute the query
    $sth->execute;

    my $rv = $sth->fetchrow_hashref;
    return 0 unless $rv;
    return $rv->{bug_id};
}

# This can be called as GetLast.comment() from the WebService.
sub comment {
    my $dbh = Bugzilla->switch_to_shadow_db();

    # prepare a query using DB methods
    my $sth = $dbh->prepare(
        'SELECT comment_id FROM longdescs ORDER BY comment_id DESC ' . $dbh->sql_limit(1)
    );

    # Execute the query
    $sth->execute;

    my $rv = $sth->fetchrow_hashref;
    return 0 unless $rv;
    return $rv->{comment_id};
}

# This can be called as GetLast.attachment() from the WebService.
sub attachment {
    my $dbh = Bugzilla->switch_to_shadow_db();

    # prepare a query using DB methods
    my $sth = $dbh->prepare(
        'SELECT attach_id FROM attachments ORDER BY attach_id DESC ' . $dbh->sql_limit(1)
    );

    # Execute the query
    $sth->execute;

    my $rv = $sth->fetchrow_hashref;
    return 0 unless $rv;
    return $rv->{attach_id};
}

1;
