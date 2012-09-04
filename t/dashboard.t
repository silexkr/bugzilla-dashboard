use Test::More tests => 14;
use DateTime;

BEGIN { use_ok('Bugzilla::Dashboard') }

my $uri      = $ENV{BZ_DASHBOARD_URI}      || 'http://bugs.silex.kr/jsonrpc.cgi';
my $username = $ENV{BZ_DASHBOARD_USER} || '';
my $password = $ENV{BZ_DASHBOARD_PASSWORD} || '';

my $d = Bugzilla::Dashboard->new(
    uri      => $uri,
    user     => $username,
    password => $password,
) or die "cannot connect to json-rpc server\n";

ok($d, 'create a new instance');
is($d->uri, $uri, 'env uri set to object uri');
is($d->user, $username, 'env username set to object user');
is($d->password, $password, 'env passowrd set to object password');
my @bugs = $d->mybugs;
ok(@bugs, 'How many bugs does user have? at least one for below test');
my $bug = pop @bugs;
isa_ok($bug, 'Bugzilla::Dashboard::Bug'); # specific 한 사항들은 env 에 따라 달라지기 때문에 테스트하기 어려움

my $history = $d->history(298);
is(ref $history, 'HASH', 'history is a HashRef');
is($history->{bugs}[0]->{id}, 298, 'pickup id from the data structure');
is(ref $history->{bugs}[0]->{history}, 'ARRAY', 'the history from the data structure is a ArrayRef');

my @attachments = $d->attachments(298);
my $attachment  = shift @attachments;
isa_ok($attachment, 'Bugzilla::Dashboard::Attachment');
is($d->get_max_attachment_id, 856, 'max_attachment_id is 856');
@attachments = $d->recent_attachments(5);
$attachment  = shift @attachments;
isa_ok($attachment, 'Bugzilla::Dashboard::Attachment');

my $dt = DateTime->now;
$dt->add(days => -1);

my @comments = $d->recent_comments($dt, 5);
my $comment  = shift @comments;
isa_ok($comment, 'Bugzilla::Dashboard::Comment');
