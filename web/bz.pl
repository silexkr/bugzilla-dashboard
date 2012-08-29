#!/usr/bin/env perl
use utf8;
use Mojolicious::Lite;
use DateTime;
use Validator::Custom;
use DateTime::Format::ISO8601;
use HTML::FillInForm::Lite ();

my $vc = Validator::Custom->new;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

get '/' => sub {
  my $self = shift;
  $self->render('index');
};

any '/recent-comments' => sub {
    my $self = shift;

    my $param = $self->req->params->to_hash;
    $param->{date}  ||= DateTime->now->add(days => -1)->ymd;
    $param->{limit} ||= 10;

    # Validation Rule
    my $rule = [
        date => [
            'date_to_timepiece'
        ],
        limit => [
            'int'
        ],
    ];

    my $vresult = $vc->validate($param, $rule);
    if ($vresult->is_ok) {
        my @comments = recent_comments(DateTime::Format::ISO8601->parse_datetime($param->{date}), $param->{limit}) || ();

        $self->stash(view => {
            comments => \@comments,
        });
    } else {
        $self->stash(view => {
            error => 'validation failed',
        });
    }

    my $html = $self->render_partial('recent-comments')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html'
    );
};

sub recent_comments {
    my ($dt, $limit) = @_;
    # B::D::Comment 에 대한 array 를 주십시오
    ();
}

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
Welcome to the Mojolicious real-time web framework!

@@ recent-comments.html.ep
% layout 'default';
% title '최근 변경 이력의 제공';
% if ($view->{error}) {
<div class="error"><%= $view->{error} %></div>
% }
<form method="post" enctype="application/x-www-form-urlencoded">
  <input type="text" name="date" placeholder="검색을 시작할 날짜" />
  <input type="text" name="limit" placeholder="갯수" />
  <input type="submit" value="새로고침" />
</form>
<table>
  <thead>
    <tr>
      <th>버그 ID</th>
      <th>제목</th>
      <th>작성자</th>
      <th>변경시간</th>
      <th>댓글요약</th>
    </tr>
    % foreach my $comment (@{ $view->{comments} }) {
    <tr>
      <td><%= $comment->bug_id %></td>
      <td><em>TODO</em> 제목을 가져오는 method 는 Bugzilla::Dashboard::Comment 에 없습니다.</td>
      <td><%= $comment->creator %></td>
      <td><%= $comment->creation_time %></td>
      <td><%= $comment->text %></td>
    </tr>
    % }
    <tr>
      <td>286</td>
      <td>"최근변경이력"</td>
      <td>Jeho Sung</td>
      <td>12:23:00</td>
      <td>"완료하엿.."</td>
    </tr>
  </thead>
  <tbody>
  </tbody>
</table>


@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-type" content="text/html; charset=UTF-8">
    <title><%= title %></title>
  </head>
  <body><%= content %></body>
</html>
