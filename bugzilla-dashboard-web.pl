#!/usr/bin/env perl

use 5.010;
use utf8;

use Mojolicious::Lite;

use DateTime::Format::ISO8601;
use DateTime;
use File::Basename;
use HTML::FillInForm::Lite ();
use Validator::Custom;

use Bugzilla::Dashboard;

my $config = plugin 'Config';
my %DEFAULT_STASH = (
    active => q{},
    %$config,
);
app->defaults(%DEFAULT_STASH);
$config = app->defaults;

my $DASHBOARD = Bugzilla::Dashboard->new( %{ $config->{connect} } )
    or die "cannot connect to bugzilla dashboard\n";

my $vc = Validator::Custom->new;

get '/' => 'login';

get '/logout' => sub {
    my $self = shift;

    undef $DASHBOARD;
    $self->session(expires => 1);
    $self->redirect_to( '/login' );
};

get  '/login' => sub {
    my $self = shift;

    $self->redirect_to( '/mybugs' ) if $self->session('user');
};

post '/login' => sub {
    my $self = shift;

    my $username = $self->param('username') // q{};
    my $password = $self->param('password') // q{};
    my $remember = $self->param('remember') // q{};
    my $email    = $self->param('username') // q{};

    $self->render( 'login' ), return unless $username;
    $self->render( 'login' ), return unless $password;
    $self->render( 'login' ), return unless $self->app->config->{users};
    $self->render( 'login' ), return unless $self->app->config->{users}{data};

    if ($username =~ /\@/) {
        for my $_username ( keys %{ $self->app->config->{users}{data} } ) {
            if ( $email eq $self->app->config->{users}{data}{$_username}{email} ) {
                $username = $_username;
                last;
            }
        }
    }
    else {
        $email = $self->app->config->{users}{data}{$username}{email};
    }

    my $dashboard = Bugzilla::Dashboard->new(
        %{ $config->{connect} },
        user     => $email,
        password => $self->param('password'),
    );

    if ($dashboard) {
        $DASHBOARD = $dashboard;
        $self->session(
            user         => $self->app->config->{users}{data}{$username},
            bugzilla_uri => dirname( $dashboard->uri ),
        );
        $self->app->log->debug("login success");
        $self->redirect_to( 'mybugs' );
    }
    else {
        $self->app->log->debug("login failed");
        $self->render( 'login' );
    }
};


any '/recent-comments' => sub {
    my $self = shift;

    $self->redirect_to( 'login' ) unless $self->session('user');

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
        my @comments = $DASHBOARD->recent_comments(
            DateTime::Format::ISO8601->parse_datetime($param->{date}),
            $param->{limit},
        );

        $self->stash(
            view   => { comments => \@comments },
            active => '/recent-comments',
        );
    }
    else {
        $self->stash(
            view   => { error => 'validation failed' },
            active => '/recent-comments',
        );
    }

    my $html = $self->render_partial('recent-comments')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html',
    );
};

any '/recent-attachments' => sub {
    my $self = shift;

    $self->redirect_to( 'login' ) unless $self->session('user');

    my $param = $self->req->params->to_hash;
    $param->{limit} ||= $config->{recent_attachments_limit};

    # Validation Rule
    my $rule = [ limit => [ 'int' ] ];

    my $vresult = $vc->validate($param, $rule);
    if ($vresult->is_ok) {
        my @attachments = $DASHBOARD->recent_attachments($param->{limit});
        $self->stash(
            view   => { attachments => \@attachments },
            active => '/recent-attachments',
        );
    }
    else {
        $self->stash(
            view   => { error => 'validation failed' },
            active => '/recent-attachments',
        );
    }

    my $html = $self->render_partial('recent-attachments')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html',
    );
};

any '/mybugs' => sub {
    my $self = shift;

    $self->redirect_to( 'login' ) unless $self->session('user');

    my $param = $self->req->params->to_hash;
    $param->{user} ||= $self->session('user')->{email};

    # Validation Rule
    my $rule = [ user => [ 'not_blank' ] ];

    my $vresult = $vc->validate($param, $rule);
    if ($vresult->is_ok) {
        my @mybugs = $DASHBOARD->mybugs($param->{user});
        @mybugs = reverse sort { $a->last_change_time->epoch cmp $b->last_change_time->epoch } @mybugs;
        $self->stash(
            view   => { bug => \@mybugs },
            active => '/mybugs',
        );
    }
    else {
        $self->stash(
            view   => { error => 'validation failed' },
            active => '/mybugs',
        );
    }

    my $html = $self->render_partial('mybugs')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html',
    );
};

any '/search' => sub {
    my $self = shift;

    $self->redirect_to( 'login' ) unless $self->session('user');

    my $param = $self->req->params->to_hash;
    $param->{query} ||= 'UNCONFIRMED CONFIRMED';

    # Validation Rule
    my $rule = [ query => [ 'not_blank' ] ];

    my $vresult = $vc->validate($param, $rule);
    if ($vresult->is_ok) {
        my %search_params = $DASHBOARD->generate_query_params( $param->{query} );
        my @mybugs = $DASHBOARD->search(%search_params);
        @mybugs = reverse sort { $a->last_change_time->epoch cmp $b->last_change_time->epoch } @mybugs;
        $self->stash(
            view   => { bug => \@mybugs },
            active => '/search',
        );
    }
    else {
        $self->stash(
            view   => { error => 'validation failed' },
            active => '/search',
        );
    }

    my $html = $self->render_partial('search')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html',
    );
};

app->start;

__DATA__

@@ commenttable.html.ep
<table class="table table-striped table-bordered table-hover">
  <thead>
    <tr>
      <th>커멘트</th>
      <th>댓글요약</th>
    </tr>
  </thead>
  <tbody>
    % foreach my $comment (@{ $view->{comments} }) {
    <tr>
      <td>
        <a href="<%= session 'bugzilla_uri' %>/show_bug.cgi?id=<%= $comment->bug_id %>">
          <%= $comment->bug_id %> (<%= $comment->id %>)
        </a>
      </td>
      <td>
        <div>
          <span>
            % my $user = session 'user';
            % my $dt = $comment->time;
            % $dt->set_time_zone($user->{time_zone});
            <%= $dt->ymd %>
            <%= $dt->hms %>
          </span>
          -
          <span>
            % my $creator = $comment->creator;
            % $creator =~ s/\@.*//;
            <a href="/search?query=@<%= $comment->creator %>">
              <%= $creator %>
            </a>
          </span>
        </div>
        % my $comment_text = $comment->text;
        % $comment_text
        %   = length($comment_text) > $config->{comments_string_length}
        %   ? substr($comment_text, 0, $config->{comments_string_length}) .  '...'
        %   : $comment_text
        %   ;
        %
        % use Mojo::Util qw(html_escape);
        % $comment_text = html_escape($comment_text);
        %
        % my $uri   = session 'bugzilla_uri';
        % my $alink = sprintf qq{$uri/attachment.cgi};
        % my $blink = sprintf qq{$uri/show_bug.cgi?id=%d}, $comment->bug_id;
        %
        % $comment_text =~ s{(attachment) (\d+)}{<a href="$alink?id=$2">$1 $2</a>}g;
        % $comment_text =~ s{(comment) #(\d+)}{<a href="$blink#c$2">$1 #$2</a>}g;
        %
        <pre><%== $comment_text %></pre>
      </td>
    </tr>
    % }
  </tbody>
</table>


@@ recent-comments.html.ep
% layout 'default', csses => [];
% title '최근 변경 이력의 제공';
<div class="widget">
  % if ($view->{error}) {
  <div class="error"><%= $view->{error} %></div>
  % }
  <form method="post" enctype="application/x-www-form-urlencoded">
    <input class="input-medium" type="text" name="date" placeholder="검색을 시작할 날짜" />
    <input class="input-medium" type="text" name="limit" placeholder="갯수" />
    <input class="btn btn-primary" type="submit" value="찾기" />
  </form>
  %= include 'commenttable', comments => $view->{comments};
</div> <!-- widget -->


@@ recent-attachments.html.ep
% layout 'default', csses => [];
% title '최근 추가된 첨부파일';
<div class="widget">
  % if ($view->{error}) {
  <div class="error"><%= $view->{error} %></div>
  % }
  <form method="post" enctype="application/x-www-form-urlencoded">
    <input class="input-medium" type="text" name="limit" placeholder="갯수" />
    <input class="btn btn-primary" type="submit" value="찾기" />
  </form>
  <table class="table table-striped table-bordered table-hover">
    <thead>
      <tr>
        <th>버그</th>
        <th>파일명</th>
        <!--
          -- this is future bugzilla feature
        -->
        <!-- <th>크기</th> -->
        <th>요약</th>
        <th>작성자</th>
        <th>변경시간</th>
      </tr>
    </thead>
    <tbody>
      % foreach my $attachment (@{ $view->{attachments} }) {
      <tr>
        <td>
          <a href="<%= session 'bugzilla_uri' %>/show_bug.cgi?id=<%= $attachment->bug_id %>">
            <%= $attachment->bug_id %>
          </a>
        </td>
        <td>
          <a href="<%= session 'bugzilla_uri' %>/attachment.cgi?id=<%= $attachment->id %>">
            <%= $attachment->file_name %>
          </a>
        </td>
        <!--
          -- this is future bugzilla feature
        -->
        <!-- <td><%= $attachment->size %></td> -->
        <td><%= $attachment->summary %></td>
        <td>
          % my $creator = $attachment->creator;
          % $creator =~ s/\@.*//;
          <a href="/search?query=@<%= $attachment->creator %>">
            <%= $creator %>
          </a>
        </td>
        <td>
          % my $user = session 'user';
          % my $dt = $attachment->creation_time;
          % $dt->set_time_zone($user->{time_zone});
          <%= $dt->ymd %>
          <%= $dt->hms %>
        </td>
      </tr>
      % }
    </tbody>
  </table>
</div> <!-- widget -->


@@ bugtable.html.ep
<table class="table table-striped table-bordered table-hover">
  <thead>
    <tr>
      <th>제품</th>
      <th>버그</th>
      <th>중요도</th>
      <th>담당자</th>
      <th>제목</th>
      <th>변경시간</th>
      <th>상태</th>
      <th>해결</th>
    </tr>
  </thead>
  <tbody>
    % foreach my $bug (@$bugs) {
    <tr>
      <td><a href="/search?query=%3B<%= $bug->product %>"><%= $bug->product %></a></td>
      <td><a href="<%= session 'bugzilla_uri' %>/show_bug.cgi?id=<%= $bug->id %>"><%= $bug->id %></a></td>
      <td>
        % my $priority;
        % given (uc $bug->priority) {
        %   $priority = 'P1' when 'HIGHEST';
        %   $priority = 'P2' when 'HIGH';
        %   $priority = 'P3' when 'NORMAL';
        %   $priority = 'P4' when 'LOW';
        %   $priority = 'P5' when 'LOWEST';
        %   $priority = 'P-' when '---';
        % }
        <a href="/search?query=<%= $priority %>">
          <%= $bug->priority %>
        </a>
      </td>
      <td>
        % my $assigned_to = $bug->assigned_to;
        % $assigned_to =~ s/\@.*//;
        <a href="/search?query=@<%= $bug->assigned_to %>">
          <%= $assigned_to %>
        </a>
      </td>
      <td><%= $bug->summary %></td>
      <td>
        % my $user = session 'user';
        % my $dt = $bug->last_change_time;
        % $dt->set_time_zone($user->{time_zone});
        <%= $dt->ymd %>
        <%= $dt->hms %>
      </td>
      <td><a href="/search?query=<%= $bug->status %>"><%= $bug->status %></a></td>
      <td><a href="/search?query=<%= $bug->resolution %>"><%= $bug->resolution %></a></td>
    </tr>
    % }
  </tbody>
</table>


@@ mybugs.html.ep
% layout 'default', csses => [];
% title '내 버그';
<div class="widget">
  % if ($view->{error}) {
    <div class="error"><%= $view->{error} %></div>
  % }
  %= include 'bugtable', bugs => $view->{bug};
</div> <!-- widget -->


@@ search.html.ep
% layout 'default', csses => [];
% title '빠른 검색';
<div class="widget">
  % if ($view->{error}) {
  <div class="error"><%= $view->{error} %></div>
  % }
  <form method="post" enctype="application/x-www-form-urlencoded">
    <input class="input-medium search-query" type="text" name="query" placeholder="검색할 키워드" />
    <input class="btn btn-primary" type="submit" value="찾기" />
  </form>
  %= include 'bugtable', bugs => $view->{bug};
</div> <!-- widget -->


@@ layouts/default.html.ep
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title><%= $project_name %> - <%= title %></title>
    %= include 'layouts/head-load'
  </head>

  <body>
    %= include 'layouts/nav'

    <div id="content">
      <div class="container">
        <div class="row">

          <div class="span2">
            %= include 'layouts/header'
          </div> <!-- span2 -->

          <div class="span10">
            <%= content %>
          </div> <!-- span10 -->

        </div> <!-- /row -->
      </div>
    </div> <!-- /content -->

    %= include 'layouts/footer'
    %= include 'layouts/body-load'
  </body>
</html>


@@ layouts/head-load.html.ep
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="description" content="">
<meta name="author" content="">

<!-- Le styles -->
<link type="text/css" rel="stylesheet" href="/adminia/css/bootstrap.min.css">
<link type="text/css" rel="stylesheet" href="/adminia/css/bootstrap-responsive.min.css">
<link type="text/css" rel="stylesheet" href="http://fonts.googleapis.com/css?family=Open+Sans:400italic,600italic,400,600">
<link type="text/css" rel="stylesheet" href="/adminia/css/font-awesome.css">
<link type="text/css" rel="stylesheet" href="/adminia/css/adminia.css">
<link type="text/css" rel="stylesheet" href="/adminia/css/adminia-responsive.css">
<link type="text/css" rel="stylesheet" href="/adminia/css/style.css">
% for my $css (@$csses) {
  <link type="text/css" rel="stylesheet" href="<%= $css %>">
% }

<!-- Le HTML5 shim, for IE6-8 support of HTML5 elements -->
<!--[if lt IE 9]>
  <script type="text/javascript" src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
<![endif]-->

<!-- Le fav and touch icons -->
<link type="image/x-icon" rel="shortcut icon" href="/favicon.ico" />
<link type="image/x-icon" rel="icon" href="/favicon.ico" />


@@ layouts/body-load.html.ep
<!-- Le javascript
================================================== -->
<!-- Placed at the end of the document so the pages load faster -->
<script type="text/javascript" src="/adminia/js/jquery-1.7.2.min.js"></script>
<script type="text/javascript" src="/adminia/js/excanvas.min.js"></script>
<script type="text/javascript" src="/adminia/js/jquery.flot.js"></script>
<script type="text/javascript" src="/adminia/js/jquery.flot.pie.js"></script>
<script type="text/javascript" src="/adminia/js/jquery.flot.orderBars.js"></script>
<script type="text/javascript" src="/adminia/js/jquery.flot.resize.js"></script>

<script type="text/javascript" src="/adminia/js/bootstrap.js"></script>
<script type="text/javascript" src="/adminia/js/charts/bar.js"></script>

% if ($google_analytics) {
  <!-- google analytics -->
  <script type="text/javascript">
    var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
    document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
  </script>
  <script type="text/javascript">
    try {
      var pageTracker = _gat._getTracker("<%= $google_analytics %>");
      pageTracker._trackPageview();
    } catch(err) {}
  </script>
% }


@@ layouts/header.html.ep
% my $user = session 'user';
<div class="account-container">

  <div class="account-avatar">
    <img src="<%= $user->{avatar} %>" alt="" class="thumbnail" />
  </div> <!-- /account-avatar -->

  <div class="account-details">
    <span class="account-name"> <%= $user->{name} %> </span>
    <span class="account-role"> <%= $user->{role} %> </span>
    <span class="account-actions"> </span>
  </div> <!-- /account-details -->

</div> <!-- /account-container -->

<hr />

<ul id="main-nav" class="nav nav-tabs nav-stacked">
  % for my $link (@$header_links) {
    % if ( $active eq $link->{url} ) {
      <li class="active"><a href="<%= $link->{url} %>"><i class="icon-<%= $link->{icon} %>"></i> <%= $link->{desc} %> </a></li>
    % }
    % else {
      <li><a href="<%= $link->{url} %>"><i class="icon-<%= $link->{icon} %>"></i> <%= $link->{desc} %> </a></li>
    % }
  % }
</ul>

<hr />

<div class="sidebar-extra">
  <p>
    <%= $project_desc %>
  </p>
</div> <!-- .sidebar-extra -->

<br />


@@ layouts/footer.html.ep
<div id="footer">
    <div class="container">
        <hr>
    <div class="span6">&copy; <%= $copyright %>. All Rights Reserved.</div>
    <div class="span4 offset1">
      <span class="pull-right">
      Built by <a href="http://www.perl.org/">Perl</a> &amp; <a href="http://mojolicio.us/">Mojolicious</a>
      </span>
    </div>
    </div> <!-- /container -->
</div> <!-- /footer -->


@@ layouts/nav.html.ep
% my $user = session 'user';
<div class="navbar navbar-fixed-top">
  <div class="navbar-inner">
    <div class="container">

      <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
      </a>

      <a class="brand" href="./"><%= $project_name %></a>

      <div class="nav-collapse">
        <ul class="nav">
          % for my $link (@$header_links) {
            <li><a href="<%= $link->{url} %>"> <%= $link->{title} %> </a></li>
          % }
        </ul>

        <ul class="nav pull-right">
          <li class="divider-vertical"></li>

          <li class="dropdown">
            % if ($user) {
                <a data-toggle="dropdown" class="dropdown-toggle " href="#"> <%= $user->{name} %> <b class="caret"></b> </a>

                <ul class="dropdown-menu">
                  <li> <a href="/logout"><i class="icon-off"></i> Logout</a> </li>
                </ul>
            % }
            % else {
                <a href="/login"> <i class="icon-lock"></i> Login </a>
            % }
          </li>

        </ul>
      </div> <!-- /nav-collapse -->

    </div> <!-- /container -->
  </div> <!-- /navbar-inner -->
</div> <!-- /navbar -->


@@ layouts/error.html.ep
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title><%= $project_name %> - <%= title %></title>
    %= include 'layouts/head-load'
  </head>

  <body>
    %= include 'layouts/nav'

    <div id="content">
      <div class="container">
        <div class="row">

          <div class="span3">
            %= include 'layouts/header'
          </div> <!-- span3 -->

          <div class="span9">
            <div class="error-container">
              <%= content %>
            </div> <!-- error-container >
          </div> <!-- span9 -->

        </div> <!-- /row -->
      </div>
    </div> <!-- /content -->

    %= include 'layouts/footer'
    %= include 'layouts/body-load'
  </body>
</html>


@@ not_found.html.ep
% layout 'error', csses => [ '/adminia/css/pages/error.css' ];
% title '404 Not Found';
<h2>404 Not Found</h2>

<div class="error-details">
  Sorry, an error has occured, Requested page not found!
</div> <!-- /error-details -->


@@ layouts/login.html.ep
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title><%= $project_name %> - <%= title %></title>
    %= include 'layouts/head-load'
  </head>

  <body>
    %= include 'layouts/nav'

    <div id="login-container">
      <%= content %>
    </div> <!-- login-container -->

    %= include 'layouts/footer'
    %= include 'layouts/body-load'

    <script type="text/javascript">
      $('#login-container input').first().focus();
    </script>

</script>
  </body>
</html>


@@ login.html.ep
% layout 'login', csses => [ '/adminia/css/pages/login.css' ];
% title 'Login';
<div id="login-header">
  <h3> <i class="icon-lock"></i> Login </h3>
</div> <!-- /login-header -->

<div id="login-content" class="clearfix">

  <form action="/login" method="post">
    <fieldset>
      <div class="control-group">
        <label class="control-label" for="username">Username</label>
        <div class="controls"> <input type="text" class="" id="username" name="username"> </div>
      </div>
      <div class="control-group">
        <label class="control-label" for="password">Password</label>
        <div class="controls"> <input type="password" class="" id="password" name="password"> </div>
      </div>
    </fieldset>

    <div id="remember-me" class="pull-left">
      <input type="checkbox" name="remember" id="remember" />
      <label id="remember-label" for="remember">Remember Me</label>
    </div>

    <div class="pull-right">
      <button type="submit" class="btn btn-warning btn-large"> Login </button>
    </div>
  </form>

</div> <!-- /login-content -->

<div id="login-extra">
  <p>Fotgot Password? <a href="mailto:keedi.k@gmail.com">Contact Us.</a></p>
</div> <!-- /login-extra -->
