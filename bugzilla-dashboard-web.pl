#!/usr/bin/env perl

use 5.010;
use utf8;

use Mojolicious::Lite;

use DateTime::Format::ISO8601;
use DateTime;
use HTML::FillInForm::Lite ();
use Validator::Custom;

use Bugzilla::Dashboard;

my $config = plugin 'Config';

my $dashboard = Bugzilla::Dashboard->new(
    uri      => $config->{connect}{uri}      || q{},
    user     => $config->{connect}{user}     || q{},
    password => $config->{connect}{password} || q{},
) or die "cannot connect to bugzilla dashboard\n";

my $vc = Validator::Custom->new;

get '/' => 'index';

any '/recent-comments' => sub {
    my $self = shift;

    my $param = $self->req->params->to_hash;
    $param->{date}  ||= DateTime->now->add(days => -1)->ymd;
    $param->{limit} ||= $config->{recent_comments_limit};

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
    $param->{limit} ||= $config->{recent_attachments_limit};

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

any '/search' => sub {
    my $self = shift;

    my $param = $self->req->params->to_hash;

    # Validation Rule
    my $rule = [ query => [ 'not_blank' ] ];

    my $vresult = $vc->validate($param, $rule);
    if ($vresult->is_ok) {
        my %search_params = _gen_query_params( $param->{query} );
        my @mybugs = $dashboard->search(%search_params);
        $self->stash( view => { bug => \@mybugs } );
    }
    else {
        $self->stash( view => { error => 'validation failed' } );
    }

    my $html = $self->render_partial('search')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html'
    );
};

app->start;

sub _gen_query_params {
    my $query = shift;

    my @status = qw(
        UNCONFIRMED
        CONFIRMED
        IN_PROGRESS
        RESOLVED
        VERIFIED
    );

    my @resolution = qw(
        FIXED
        INVALID
        WONTFIX
        DUPLICATE
        WORKSFORME
    );

    my %params = (
        alias       => [],
        assigned_to => [],
        component   => [],
        id          => [],
        priority    => [],
        product     => [],
        resolution  => [],
        status      => [],
        summary     => [],
    );

    my @keywords = split(/ /, $query);
    for my $keyword (@keywords) {
        if ( $keyword eq 'OPEN' ) {
            push $params{status}, qw( UNCONFIRMED CONFIRMED IN_PROGRESS );
        }
        elsif ( $keyword ~~ \@status ) {
            push $params{status}, $keyword;
        }
        elsif ( $keyword ~~ \@resolution ) {
            push $params{resolution}, $keyword;
        }
        elsif ( $keyword =~ /^P(\d)$/ ) {
            given ($1) {
                push $params{priority}, 'HIGHEST' when 1;
                push $params{priority}, 'HIGH'    when 2;
                push $params{priority}, 'NORMAL'  when 3;
                push $params{priority}, 'LOW'     when 4;
                push $params{priority}, 'LOWEST'  when 5;
                default { push $params{priority}, '---'; }
            }
        }
        elsif ( $keyword =~ /^P(\d)-(\d)$/ ) {
            my $first  = $1;
            my $second = $2;
            my @priorities = $1 > $2 ? ( $2 .. $1 ) : ( $1 .. $2 );
            for (@priorities) {
                push $params{priority}, 'HIGHEST' when 1;
                push $params{priority}, 'HIGH'    when 2;
                push $params{priority}, 'NORMAL'  when 3;
                push $params{priority}, 'LOW'     when 4;
                push $params{priority}, 'LOWEST'  when 5;
                default { push $params{priority}, '---'; }
            }
        }
        elsif ( $keyword =~ /^@(.+)$/ ){
            push $params{assigned_to}, $1;
        }
        elsif ( $keyword =~ /^:(.+)$/ ){
            push $params{component}, $1;
        }
        elsif ( $keyword =~ /^;(.+)$/ ){
            push $params{product}, $1;
        }
        elsif ( $keyword =~ /^#(.+)$/ ){
            push $params{summary}, $1;
        }
        elsif ( $keyword =~ /^(\d+)$/ ) {
            push $params{id}, $keyword;
        }
        else {
            push $params{alias}, $keyword;
        }
    }

    my %filtered_params = map { @{ $params{$_} } ? ( $_ => $params{$_} ) : () } keys %params;

    return %filtered_params;
}

__DATA__

@@ header.html.ep
<ul>
  <li> <a href="/recent-comments">recent comments</a> </li>
  <li> <a href="/recent-attachments">recent attachments</a> </li>
  <li> <a href="/mybugs">mybugs</a> </li>
  <li> <a href="/search">search</a> </li>
</ul>

@@ index.html.ep
% layout 'default';
% title 'Bugzilla Dashboard';
Welcome to the Bugzilla Dashboard!

@@ commenttable.html.ep
<table class="table table-striped table-bordered table-hover">
  <thead>
    <tr>
      <th>커멘트 ID</th>
      <th>작성자</th>
      <th>변경시간</th>
      <th>댓글요약</th>
    </tr>
    % foreach my $comment (@{ $view->{comments} }) {
    <tr>
      <td><%= $comment->bug_id %> (<%= $comment->id %>)</td>
      <td><%= $comment->creator %></td>
      <td><%= $comment->time %></td>
      <td>
        <%=
          length($comment->text) > $config->{comments_string_length}
            ? substr($comment->text, 0, $config->{comments_string_length}) .  '...'
            : $comment->text
        %>
      </td>
    </tr>
    % }
  </thead>
  <tbody>
  </tbody>
</table>

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
%= include 'commenttable', comments => $view->{comments};

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

@@ bugtable.html.ep
<table class="table table-striped table-bordered table-hover">
  <thead>
    <tr>
      <th>제품</th>
      <th>버그 ID</th>
      <th>우선순위</th>
      <th>작성자</th>
      <th>제목</th>
      <th>변경시간</th>
      <th>상태</th>
      <th>해결</th>
    </tr>
    % foreach my $bug (@$bugs) {
    <tr>
      <td><a href="/search?query=%3B<%= $bug->product %>"><%= $bug->product %></a></td>
      <td><%= $bug->id %></td>
      <td><%= $bug->priority %></td>
      <td><%= $bug->creator %></td>
      <td><%= $bug->summary %></td>
      <td><%= $bug->last_change_time %></td>
      <td><%= $bug->status %></td>
      <td><%= $bug->resolution %></td>
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
%= include 'bugtable', bugs => $view->{bug};

@@ search.html.ep
% layout 'default';
% title '빠른 검색';
% if ($view->{error}) {
<div class="error"><%= $view->{error} %></div>
% }
<form method="post" enctype="application/x-www-form-urlencoded">
  <input type="text" name="query" placeholder="검색할 키워드" />
  <input type="submit" value="새로고침" />
</form>
%= include 'bugtable', bugs => $view->{bug};

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-type" content="text/html; charset=UTF-8">
    <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.0/css/bootstrap-combined.min.css" rel="stylesheet">
    <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.0/js/bootstrap.min.js"></script>
    <title><%= title %></title>
  </head>
  <body>
    %= include 'header';
    <%= content %>
  </body>
</html>
