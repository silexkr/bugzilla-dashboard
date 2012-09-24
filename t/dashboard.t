use Test::More tests => 14;
use DateTime;

BEGIN { use_ok('Bugzilla::Dashboard') }

my $bd = Bugzilla::Dashboard->new
    or die "cannot connect to json-rpc server\n";

ok($bd, 'create a new instance');
is($bd->uri, $uri, 'env uri set to object uri');
is($bd->user, $username, 'env username set to object user');
is($bd->password, $password, 'env passowrd set to object password');
my @bugs = $bd->mybugs;
ok(@bugs, 'How many bugs does user have? at least one for below test');
my $bug = pop @bugs;
isa_ok($bug, 'Bugzilla::Dashboard::Bug'); # specific 한 사항들은 env 에 따라 달라지기 때문에 테스트하기 어려움

my $history = $bd->history(298);
is(ref $history, 'HASH', 'history is a HashRef');
is($history->{bugs}[0]->{id}, 298, 'pickup id from the data structure');
is(ref $history->{bugs}[0]->{history}, 'ARRAY', 'the history from the data structure is a ArrayRef');

my @attachments = $bd->attachments(298);
my $attachment  = shift @attachments;
isa_ok($attachment, 'Bugzilla::Dashboard::Attachment');
is($bd->get_max_attachment_id, 856, 'max_attachment_id is 856');
@attachments = $bd->recent_attachments(5);
$attachment  = shift @attachments;
isa_ok($attachment, 'Bugzilla::Dashboard::Attachment');

my $dt = DateTime->now;
$dt->add(days => -1);

my @comments = $bd->recent_comments($dt, 5);
my $comment  = shift @comments;
isa_ok($comment, 'Bugzilla::Dashboard::Comment');
