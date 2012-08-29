#!/usr/bin/env perl
use Mojolicious::Lite;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

get '/' => sub {
  my $self = shift;
  $self->render('index');
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
Welcome to the Mojolicious real-time web framework!

@@ recent-comments.html.ep
% layout 'default';
% title '최근 변경 이력의 제공';
<form>
  <input type="text" placeholder="검색을 시작할 날짜" />
  <input type="text" placeholder="갯수" />
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
    <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.0/css/bootstrap-combined.min.css" rel="stylesheet">
    <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.0/js/bootstrap.min.js"></script>
    <title><%= title %></title>
  </head>
  <body><%= content %></body>
</html>
