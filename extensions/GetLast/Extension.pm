# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Extension::GetLast;
use strict;
use base qw(Bugzilla::Extension);

# This code for this is in ./extensions/GetLast/lib/Util.pm
use Bugzilla::Extension::GetLast::Util;

our $VERSION = '0.01';

# See the documentation of Bugzilla::Hook ("perldoc Bugzilla::Hook" 
# in the bugzilla directory) for a list of all available hooks.
sub webservice {
    my ($self, $args) = @_;

    my $dispatch = $args->{dispatch};
    $dispatch->{'GetLast'} = 'Bugzilla::Extension::GetLast::WebService';
}

__PACKAGE__->NAME;
