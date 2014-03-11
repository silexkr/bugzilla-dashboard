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

my $DASHBOARD = Bugzilla::Dashboard->new( %{ app->defaults->{connect} } );

my $vc = Validator::Custom->new;

helper login => sub {
    my ( $self, $username, $password, $remember ) = @_;

    return unless $username;
    return unless $password;
    return unless $self->app->config->{users};
    return unless $self->app->config->{users}{data};

    my $email = $username;
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
        %{ $self->app->config->{connect} },
        user     => $email,
        password => $password,
        remember => 1,
    );

    unless ( $dashboard->connect ) {
        $self->app->log->warn(
            "cannot connect to bugzilla dashboard: " . $dashboard->error
        );
        return;
    }

    $DASHBOARD = $dashboard;
    $self->app->config->{users}{data}{$username}{password} = $password;

    $self->session(
        user         => $self->app->config->{users}{data}{$username},
        bugzilla_uri => dirname( $dashboard->uri ),
        expiration   => $remember ?  $self->app->config->{expire}{remember} : $self->app->config->{expire}{default},
    );

    $self->app->log->debug("login success");

    return 1;
};

helper linkify => sub {
    my ( $self, $text, $params ) = @_;

    return unless $text;

    use Mojo::Util qw(html_escape);

    my $result = html_escape($text);

    my $uri   = $self->session('bugzilla_uri');
    my $alink = qq{$uri/attachment.cgi?id=%d};
    my $blink = qq{$uri/show_bug.cgi?id=%d};
    my $clink = qq{$uri/show_bug.cgi?id=%d#c%d};

    # using url regexp
    # http://blog.mattheworiordan.com/post/13174566389/url-regular-expression-for-links-with-or-without-the
    my $sharp = chr 0x23;
    my $uri_regexp = qr<((([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+)((?:\/[\+~%\/.\w\-_]*)?\??(?:[-\+=&;%@.\w_]*)$sharp?(?:[.!/\w]*))?)>;

    # using email regexp
    my $email_regexp = qr<[A-Za-z0-9._%-]+\@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}>;

    $result =~ s{($uri_regexp)}{<a href="$1">$1</a>}g;
    $result =~ s{($email_regexp)}{<a href="mailto:$1">$1</a>}g;

    $result =~ s{
        (attachment) \s+ (\d+)
    }{
        my $link = sprintf $alink, $2;
        qq|<a href="$link">$&</a>|;
    }giex;

    $result =~ s{
        (Bug) \s+ (\d+)
        (?! \s+ Comment | \d )
    }{
        my $link = sprintf $blink, $2;
        qq|<a href="$link">$&</a>|;
    }giex;

    if ($params->{bug_id}) {
        my $bid = $params->{bug_id};
        $result =~ s{(comment) #(\d+)}{
            my $link = sprintf $clink, $bid, $2;
            qq|<a href="$link">$&</a>|;
        }gie;
    }

    $result =~ s{
        (Bug) \s+ (\d+)
        \s+
        (Comment) \s+ (\d+)
    }{
        my $link = sprintf $clink, $2, $4;
        qq|<a href="$link">$&</a>|;
    }giex;

    return $result;
};

any '/' => sub {
    my $self = shift;

    return $self->redirect_to('/mybugs') if $self->session('user');

    my $username = $self->param('username') // q{};
    my $password = $self->param('password') // q{};
    my $remember = $self->param('remember') // q{};

    return $self->render unless $self->login($username, $password, $remember);

    $self->redirect_to('/mybugs');
} => 'login';

get '/logout' => sub {
    my $self = shift;

    undef $DASHBOARD;
    $self->session(expires => 1);
    $self->redirect_to('/');
};

any '/recent-comments' => sub {
    my $self = shift;

    return $self->redirect_to('/') unless $self->session('user');

    my $param = $self->req->params->to_hash;
    $param->{date}  ||= DateTime->now->add(days => -1)->ymd;
    $param->{limit} ||= $self->app->config->{recent_comments_limit};

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

    return $self->redirect_to('/') unless $self->session('user');

    my $param = $self->req->params->to_hash;
    $param->{limit} ||= $self->app->config->{recent_attachments_limit};

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

    return $self->redirect_to('login') unless $self->session('user');

    my $param = $self->req->params->to_hash;
    $param->{user} ||= $self->session('user')->{email};

    # Validation Rule
    my $rule = [ user => [ 'not_blank' ] ];

    my $vresult = $vc->validate($param, $rule);
    if ($vresult->is_ok) {
        my @mybugs = $DASHBOARD->mybugs($param->{user});
        my %priority_table = (
            Highest => 5,
            High    => 4,
            Normal  => 3,
            Low     => 2,
            Lowest  => 1,
            '---'   => 0,
        );
        @mybugs = reverse sort {
            $priority_table{ $a->priority } cmp $priority_table{ $b->priority }
        } @mybugs;
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

    return $self->redirect_to('login') unless $self->session('user');

    my $param = $self->req->params->to_hash;

    my %search_params = $DASHBOARD->generate_query_params( $param->{query} );
    my @bugs = $DASHBOARD->search(%search_params);
    @bugs = reverse sort { $a->last_change_time->epoch cmp $b->last_change_time->epoch } @bugs;
    $self->stash(
        view   => { bug => \@bugs },
        active => '/search',
    );

    my $html = $self->render_partial('search')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html',
    );
};

get  '/create-bug' => sub {
    my $self = shift;

    return $self->redirect_to('login') unless $self->session('user');

    my $param = $self->req->params->to_hash;
    $param->{product}   ||= $self->app->config->{default_product}   || q{};
    $param->{component} ||= $self->app->config->{default_component} || q{};
    $param->{version}   ||= $self->app->config->{default_version}   || q{};

    # Validation Rule
    my $rule = [
        product   => { message => 'product is required' }   => ['not_blank'],
        component => { message => 'component is required' } => ['not_blank'],
        version   => { message => 'version is required' }   => ['not_blank'],
        blocks    => { message => 'invalid blocks', require => 0 } =>
            [ 'trim', { regex => qr/^([+\-]?\d+(,[+\-]?\d+)*|)$/ }, ],
    ];

    my %view = (
        product   => $param->{product},
        component => $param->{component},
        version   => $param->{version},
        blocks    => $param->{blocks},
    );

    my $vresult = $vc->validate($param, $rule);
    $view{error} = join '. ', values %{ $vresult->messages_to_hash } unless $vresult->is_ok;
    $self->stash(
        active => '/create-bug',
        view   => \%view,
    );

    my $html = $self->render_partial('create-bug')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill(\$html, $param),
        format => 'html',
    );
};

post '/create-bug' => sub {
    my $self = shift;

    return $self->redirect_to('login') unless $self->session('user');

    my $param = $self->req->params->to_hash;
    $param->{product}   ||= $self->app->config->{default_product};
    $param->{component} ||= $self->app->config->{default_component};
    $param->{version}   ||= $self->app->config->{default_version};

    # Validation Rule
    my $rule = [
        product     => { message => 'product is required' }     => ['not_blank'],
        component   => { message => 'component is required' }   => ['not_blank'],
        version     => { message => 'version is required' }     => ['not_blank'],
        summary     => { message => 'summary is required' }     => ['not_blank'],
        description => { message => 'description is required' } => ['not_blank'],
        blocks      => { message => 'invalid blocks', require => 0 } =>
            [ 'trim', { regex => qr/^([+\-]?\d+(,[+\-]?\d+)*|)$/ }, ],
    ];

    my %view = (
        product   => $param->{product},
        component => $param->{component},
        version   => $param->{version},
        blocks    => $param->{blocks},
    );

    my $vresult = $vc->validate($param, $rule);
    if ( $vresult->is_ok ) {
        my $bug = $DASHBOARD->create_bug(
            product     => $param->{product},
            component   => $param->{component},
            version     => $param->{version},
            summary     => $param->{summary},
            description => $param->{description},
        );

        if ($bug) {
            $view{success} = "Bug $bug was created";

            $view{summary}     = q{};
            $view{description} = q{};

            #
            # update bug dependency
            #
            if ( $param->{blocks} ) {
                my %blocks = (
                    add    => [],
                    remove => [],
                );
                for ( split /,/, $param->{blocks} ) {
                    push @{ $blocks{add} },    $1 when /^\+?(\d+)$/;
                    push @{ $blocks{remove} }, $1 when /^\-(\d+)$/;
                }

                my $bugs_info = $DASHBOARD->update_bug(
                    ids    => [ $bug ],
                    blocks => \%blocks,
                );

                unless ($bugs_info) {
                    $view{error} = $DASHBOARD->error;
                    $view{blocks} = q{};
                }
            }
        }
        else {
            $view{error} = $DASHBOARD->error;

            $view{product}   = $self->app->config->{default_product};
            $view{component} = $self->app->config->{default_component};
            $view{version}   = $self->app->config->{default_version};
        }
    }
    else {
        $view{error} = join '. ', values %{ $vresult->messages_to_hash };
    }

    $self->stash(
        active => '/create-bug',
        view   => \%view,
    );

    my $html = $self->render_partial('create-bug')->to_string;
    $self->render_text(
        HTML::FillInForm::Lite->fill( \$html, { %$param, %view } ),
        format => 'html',
    );
};

app->secrets( app->defaults->{secrets} );
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
        <a href="<%= session 'bugzilla_uri' %>/show_bug.cgi?id=<%= $comment->bug_id %>#c<%= $comment->count %>">
          B#<%= $comment->bug_id %> C#<%= $comment->count %>
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
          -
          <span>
            % use Mojo::Util qw(url_escape encode);
            %
            % my $create_params = sprintf(
            %   'blocks=%d&summary=%s&description=%s',
            %   $comment->bug_id,
            %   ( split "\n", $comment->text )[0],
            %   url_escape( encode('UTF-8', $comment->text) ),
            % );
            %
            % my $quote_params = do {
            %   my $description = do {
            %     my $header = 'From Bug ' . $comment->bug_id;
            %     my $content = $comment->text;
            %     $content =~ s/^/> /gms;
            %     "$header\n$content";
            %   };
            %   sprintf(
            %     'blocks=%d&summary=%s&description=%s',
            %     $comment->bug_id,
            %     ( split "\n", $comment->text )[0],
            %     url_escape( encode('UTF-8', $description) ),
            %   );
            % };
            <a class="dashboard-link-tooltip" href="/create-bug?<%= $create_params %>" data-title="버그 생성"> [C] </a>
            <a class="dashboard-link-tooltip" href="/create-bug?<%= $quote_params %>" data-title="인용 후 버그 생성"> [Q] </a>
            <a class="dashboard-link-tooltip" href="<%= session 'bugzilla_uri' %>/show_bug.cgi?id=<%= $comment->bug_id %>#comment" data-title="답글 달기"> [R] </a>
          </span>
        </div>
        % my $comment_text = $comment->text;
        % $comment_text
        %   = length($comment_text) > $config->{comments_string_length}
        %   ? substr($comment_text, 0, $config->{comments_string_length}) .  '...'
        %   : $comment_text
        %   ;
        % $comment_text = linkify $comment_text, { bug_id => $comment->bug_id };
        <pre><%== $comment_text %></pre>
      </td>
    </tr>
    % }
  </tbody>
</table>


@@ recent-comments.html.ep
% layout 'default', csses => [], jses => [];
% title '최근 변경 이력의 제공';
<form method="post" enctype="application/x-www-form-urlencoded" class="form-inline">
  <input class="input-medium datepicker" type="text" name="date" placeholder="검색을 시작할 날짜" />
  <input class="input-medium" type="text" name="limit" placeholder="갯수" />
  <input class="btn btn-primary" type="submit" value="찾기" />
</form>
%= include 'commenttable', comments => $view->{comments};


@@ recent-attachments.html.ep
% layout 'default', csses => [], jses => [];
% title '최근 추가된 첨부파일';
<form method="post" enctype="application/x-www-form-urlencoded" class="form-inline">
  <input class="input-medium" type="text" name="limit" placeholder="갯수" />
  <input class="btn btn-primary" type="submit" value="찾기" />
</form>
<table class="table table-striped table-bordered table-hover">
  <thead>
    <tr>
      <th>버그</th>
      <!--
        -- this is future bugzilla feature
      -->
      <!-- <th>크기</th> -->
      <th>파일</th>
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
      <!--
        -- this is future bugzilla feature
      -->
      <!-- <td><%= $attachment->size %></td> -->
      <td>
        <div>
          <%= $attachment->summary %>
        </div>
        <div>
          <a href="<%= session 'bugzilla_uri' %>/attachment.cgi?id=<%= $attachment->id %>">
            <%= $attachment->file_name %>
          </a>
        </div>
      </td>
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


@@ bugtable.html.ep
<table class="table table-striped table-bordered table-hover">
  <thead>
    <tr>
      <th>제품</th>
      <th>중요도</th>
      <th>담당자</th>
      <th colspan="2">버그</th>
      <th>변경시간</th>
      <th>상태</th>
      <th>해결</th>
    </tr>
  </thead>
  <tbody>
    % foreach my $bug (@$bugs) {
    <tr>
      <td><a href="/search?query=%3B<%= $bug->product %>"><%= $bug->product %></a></td>
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
      <td>
        <a href="<%= session 'bugzilla_uri' %>/show_bug.cgi?id=<%= $bug->id %>">
          B<%= $bug->id %> - <%= $bug->summary %>
        </a>
      </td>
      <td>
        % my $create_params = sprintf(
        %   'product=%s&component=%s&blocks=%d',
        %   $bug->product,
        %   $bug->component,
        %   $bug->id,
        % );
        <a class="dashboard-link-tooltip" href="/create-bug?<%= $create_params %>" data-title="버그 생성"> [C] </a>
        <a class="dashboard-link-tooltip" href="<%= session 'bugzilla_uri' %>/show_bug.cgi?id=<%= $bug->id %>#comment" data-title="답글 달기"> [R] </a>
      </td>
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
% layout 'default', csses => [], jses => [];
% title '내 버그';
%= include 'bugtable', bugs => $view->{bug};


@@ search.html.ep
% layout 'default', csses => [], jses => [];
% title '빠른 검색';
%= include 'bugtable', bugs => $view->{bug};


@@ create-bug.html.ep
% layout 'default', csses => [], jses => [];
% title '버그 만들기';
<div>
  <form action="/create-bug" method="post" class="form-horizontal">

    <div class="control-group">
      <label class="control-label" for="summary">Summary</label>
      <div class="controls"> <input type="text" class="span6" id="summary" name="summary"> </div>
    </div>

    <div class="control-group">
      <label class="control-label" for="description">Description</label>
      <div class="controls"> <textarea rows="20" class="span6" id="description" name="description"></textarea> </div>
    </div>

    <div class="control-group">
      <label class="control-label" for="blocks">Blocks</label>
      <div class="controls">
        <input type="text" class="" id="blocks" name="blocks">
        <span class="help-inline">(Optional)</span>
      </div>
    </div>

    <input type="hidden" id="product" name="product">
    <input type="hidden" id="component" name="component">
    <input type="hidden" id="version" name="version">

    <div class="form-actions">
      <input class="btn btn-primary" type="submit" value="Create a New Bug">
      <span>
        as
        <strong><%= $view->{product} %></strong> /
        <strong><%= $view->{component} %></strong> /
        <strong><%= $view->{version} %></strong>
      </span>
    </div>
  </form>
</div>


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

            <div class="widget">
              % if ($view->{error}) {
              <div class="alert alert-error"><%== $view->{error} %></div>
              % }
              % if ($view->{success}) {
              <div class="alert alert-success"><%== linkify $view->{success} %></div>
              % }

              <%= content %>

            </div> <!-- widget -->

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
<link type="text/css" rel="stylesheet" href="/themes/<%= $theme %>/bootstrap/css/bootstrap.min.css">
<link type="text/css" rel="stylesheet" href="/themes/<%= $theme %>/bootstrap/css/bootstrap-responsive.min.css">
<link type="text/css" rel="stylesheet" href="/css/bootstrap-datepicker.css">
<link type="text/css" rel="stylesheet" href="http://fonts.googleapis.com/css?family=Open+Sans:400italic,600italic,400,600">
<link type="text/css" rel="stylesheet" href="/themes/<%= $theme %>/font-awesome/font-awesome.css">
<link type="text/css" rel="stylesheet" href="/themes/<%= $theme %>/css/style.css">
% for my $css (@$csses) {
  <link type="text/css" rel="stylesheet" href="/themes/<%= $theme %>/css/<%= $css %>">
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
<script type="text/javascript" src="/js/jquery-1.8.2.min.js"></script>
<script type="text/javascript" src="/themes/<%= $theme %>/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/js/bootstrap-datepicker.js"></script>
% for my $js (@$jses) {
  <script type="text/javascript" src="/js/<%= $js %>"></script>
% }
<script>
  $(document).ready(function () {
    $('.datepicker').datepicker({
      format: 'yyyy-mm-dd'
    });
    $('.dashboard-link-tooltip').tooltip({ placement: 'top' });
  });
</script>

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
      Built by
        <a href="http://www.bugzilla.org/">Bugzilla</a>,
        <a href="http://mojolicio.us/">Mojolicious</a> &amp;
        <a href="http://www.perl.org/">Perl</a>
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
                <a href="/"> <i class="icon-lock"></i> Login </a>
            % }
          </li>
        </ul>

        <form action="/search" method="post" class="navbar-search pull-right" enctype="application/x-www-form-urlencoded">
          <input type="text" name="query" class="input-large search-query" placeholder="Search">
        </form>
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

          <div class="span2">
            %= include 'layouts/header'
          </div> <!-- span2 -->

          <div class="span10">
            <div class="error-container">
              <%= content %>
            </div> <!-- error-container >
          </div> <!-- span10 -->

        </div> <!-- /row -->
      </div>
    </div> <!-- /content -->

    %= include 'layouts/footer'
    %= include 'layouts/body-load'
  </body>
</html>


@@ not_found.html.ep
% layout 'error', csses => [ 'error.css' ], jses => [];
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
% layout 'login', csses => [ 'login.css' ], jses => [];
% title 'Login';
<div id="login-header">
  <h3> <i class="icon-lock"></i> Login </h3>
</div> <!-- /login-header -->

<div id="login-content" class="clearfix">

  <form action="/" method="post">
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
