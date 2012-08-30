#!/usr/bin/env perl

use utf8;

use Mojolicious::Lite;

use DateTime::Format::ISO8601;
use DateTime;
use HTML::FillInForm::Lite ();
use Validator::Custom;

use Bugzilla::Dashboard;

my $vc = Validator::Custom->new;

my $dashboard = Bugzilla::Dashboard->new(
    uri      => $ENV{BZ_DASHBOARD_URI},
    user     => $ENV{BZ_DASHBOARD_USER},
    password => $ENV{BZ_DASHBOARD_PASSWORD},
) or die "cannot connect to bugzilla dashboard\n";

get '/' => 'index';

any '/recent-comments' => sub {
    my $self = shift;

    my $param = $self->req->params->to_hash;
    $param->{date}  ||= DateTime->now->add(days => -1)->ymd;
    $param->{limit} ||= 10;

    # Validation Rule
    my $rule = [
        date  => [ 'date_to_timepiece' ],
        limit => [ 'int' ],
    ];

    my $vresult = $vc->validate($param, $rule);
    if ($vresult->is_ok) {
        my @comments = $dashboard->recent_comments(
            DateTime::Format::ISO8601->parse_datetime($param->{date}),
            $param->{limit},
        );
        $self->stash( view => { comments => \@comments } );
    } else {
        $self->stash( view => { error => 'validation failed' } );
    }

    my $html = $self->render_partial('recent-comments')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html'
    );
};

any '/recent-attachments' => sub {
    my $self = shift;

    my $param = $self->req->params->to_hash;
    $param->{limit} ||= 10;

    # Validation Rule
    my $rule = [ limit => [ 'int' ] ];

    my $vresult = $vc->validate($param, $rule);
    if ($vresult->is_ok) {
        my @attachments = $dashboard->recent_attachments($param->{limit});
        $self->stash( view => { attachments => \@attachments } );
    } else {
        $self->stash( view => { error => 'validation failed' } );
    }

    my $html = $self->render_partial('recent-attachments')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html'
    );
};

any '/mybugs' => sub {
    my $self = shift;

    my $param = $self->req->params->to_hash;

    # Validation Rule
    my $rule = [ user => [ 'not_blank' ] ];

    my $vresult = $vc->validate($param, $rule);
    if ($vresult->is_ok) {
        my @mybugs = $dashboard->mybugs($param->{user});
        $self->stash( view => { bug => \@mybugs } );
    }
    else {
        $self->stash( view => { error => 'validation failed' } );
    }

    my $html = $self->render_partial('mybugs')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html'
    );
};

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
Welcome to the Mojolicious real-time web framework!
<ul>
  <li> <a href="/recent-comments">recent comments</a> </li>
  <li> <a href="/recent-attachments">recent attachments</a> </li>
  <li> <a href="/mybugs">mybugs</a> </li>
</ul>

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
<table class="table table-striped table-bordered table-hover">
  <thead>
    <tr>
      <th>버그 ID</th>
      <th>작성자</th>
      <th>변경시간</th>
      <th>댓글요약</th>
    </tr>
    % foreach my $comment (@{ $view->{comments} }) {
    <tr>
      <td><%= $comment->bug_id %></td>
      <td><%= $comment->creator %></td>
      <td><%= $comment->time %></td>
      <td title="<%= $comment->text %>"><%= substr($comment->text, 0, 10) %></td>
    </tr>
    % }
  </thead>
  <tbody>
  </tbody>
</table>


@@ recent-attachments.html.ep
% layout 'default';
% title '최근 추가된 첨부파일';
% if ($view->{error}) {
<div class="error"><%= $view->{error} %></div>
% }
<form method="post" enctype="application/x-www-form-urlencoded">
  <input type="text" name="limit" placeholder="갯수" />
  <input type="submit" value="새로고침" />
</form>
<table class="table table-striped table-bordered table-hover">
  <thead>
    <tr>
      <th>버그 ID</th>
      <th>파일명</th>
      <th>크기</th>
      <th>요약</th>
      <th>작성자</th>
      <th>수정시간</th>
    </tr>
    % foreach my $attachment (@{ $view->{attachments} }) {
    <tr>
      <td><%= $attachment->bug_id %></td>
      <td><%= $attachment->file_name %></td>
      <td><%= $attachment->size %></td>
      <td><%= $attachment->summary %></td>
      <td><%= $attachment->creator %></td>
      <td><%= $attachment->creation_time %></td>
    </tr>
    % }
  </thead>
  <tbody>
  </tbody>
</table>


@@ mybugs.html.ep
% layout 'default';
% title '내가 참여한 이슈';
% if ($view->{error}) {
<div class="error"><%= $view->{error} %></div>
% }
<form method="post" enctype="application/x-www-form-urlencoded">
  <input type="text" name="user" placeholder="검색할 사용자" />
  <input type="submit" value="새로고침" />
</form>
<table class="table table-striped table-bordered table-hover">
  <thead>
    <tr>
      <th>버그 ID</th>
      <th>작성자</th>
      <th>제목</th>
      <th>변경시간</th>
      <th>상태</th>
    </tr>
    % foreach my $bug (@{ $view->{bug} }) {
    <tr>
      <td><%= $bug->id %></td>
      <td><%= $bug->creator %></td>
      <td><%= $bug->summary %></td>
      <td><%= $bug->last_change_time %></td>
      <td><%= $bug->status %></td>
    </tr>
    % }
  </thead>
  <tbody>
  </tbody>
</table>


@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-type" content="text/html; charset=UTF-8">
    <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.0/css/bootstrap-combined.min.css" rel="stylesheet">
    <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.0/js/bootstrap.min.js"></script>
    <title><%= title %></title>
  </head>
  <body><%= content %></body>
</html>
