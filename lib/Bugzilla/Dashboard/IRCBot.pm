package Bugzilla::Dashboard::IRCBot;

use 5.010;
use utf8;
 
use Moose;
use namespace::autoclean;

extends 'Bot::BasicBot';

use DateTime;
use Encode qw( decode_utf8 );
#use Text::WrapI18N;

use Bugzilla::Dashboard;

#$Text::WrapI18N::columns = 64;

has comment_length => (
    is         => 'ro',
    isa        => 'Int',
    lazy_build => 1,
);

has dashboard => (
    is         => 'ro',
    isa        => 'Bugzilla::Dashboard',
    lazy_build => 1,
);

sub bugzilla_uri {
    my $self = shift;

    my $uri = $self->dashboard->uri;
    $uri =~ s{/jsonrpc.cgi}{};

    return $uri;
}

sub _build_comment_length { 200 }

sub _build_dashboard {
    my $bd = Bugzilla::Dashboard->new(
        uri      => $ENV{BZ_DASHBOARD_URI}      || q{},
        user     => $ENV{BZ_DASHBOARD_USER}     || q{},
        password => $ENV{BZ_DASHBOARD_PASSWORD} || q{},
    ) or die "cannot connect to bugzilla\n";

    return $bd;
}

override said => sub {
    my ( $self, $params ) = @_;

    my $address  = $params->{address};
    my $body     = $params->{body};
    my $channel  = $params->{channel};
    my $raw_body = $params->{raw_body};
    my $raw_nick = $params->{raw_nick};
    my $who      = $params->{who};

    my @msgs;
    given ($body) {
        @msgs = $self->_recent_comments($1) when /^bug.recent_comments (\d+)/;
        default { @msgs = $self->_get_bug_comment($body) }
    }

    for my $msg (@msgs) {
        $self->say(
            channel => $channel,
            body    => $msg,
        );
    }

    return;
};

sub _recent_comments {
    my ( $self, $limit ) = @_;

    my @msgs;

    my $dt = DateTime->now;
    $dt->add( days => -5 );

    my @comments = $self->dashboard->recent_comments( $dt, $limit );

    for my $comment (@comments) {
        my $msg = sprintf(
            "B#%d: %s - %s, %s",
            $comment->bug_id,
            $self->_wrap_message( $comment->text ),
            $comment->time,
            ( split /@/, $comment->creator )[0],
        );
        push @msgs, $msg;
        warn "$msg\n";
    }

    return @msgs;
}

sub _get_bug_comment {
    my ( $self, $body ) = @_;

    my @msgs;

    # get bugs
    my @bug_ids;
    while ( $body =~ m/Bug (?<bug_id>\w+)/ig ) {
        my $bid = $+{bug_id};

        push @bug_ids, $bid;
    }

    # get comments
    my %comment_ids;
    while ( $body =~ m/Bug (?<bug_id>\w+) Comment (?<comment_id>\d+)/ig ) {
        my $bid = $+{bug_id};
        my $cid = $+{comment_id};

        $comment_ids{$bid} //= [];
        push @{ $comment_ids{$bid} }, $cid;
    }

    # permissive option does not work now
    #my %bugs = map { $_->id => $_ } $self->dashboard->bugs(@bug_ids);
    my %bugs;
    for my $bid (@bug_ids) {
        my ( $bug ) = $self->dashboard->bugs($bid);
        next unless $bug;

        $bugs{$bug->id} = $bug;

        if ($bug->alias) {
            if ($comment_ids{$bug->alias}) {
                $comment_ids{$bug->id} = $comment_ids{$bug->alias};
            }
        }
    }

    my %comments = $self->dashboard->comments( ids => [ keys %comment_ids ] );

    for my $bid ( sort { $a <=> $b } keys %bugs ) {
        next if grep { $bid == $_ } keys %comments;

        my $msg;

        $msg = sprintf(
            "B#%d: %s",
            $bid,
            $bugs{$bid}->summary,
        );
        push @msgs, $msg;
        warn "$msg\n";
    }

    for my $bid ( sort { $a <=> $b } keys %comments ) {
        next unless $bugs{$bid};

        my $msg;
        
        for my $cid ( sort { $a <=> $b } @{ $comment_ids{$bid} } ) {
            next unless $comments{$bid}[$cid];

            my $msg = $self->_wrap_message( "B#$bid,C#$cid: " . $comments{$bid}[$cid]->text );
            push @msgs, $msg;
            warn "$msg\n";
        }
    }

    return @msgs;
}

sub _wrap_message {
    my ( $self, $msg ) = @_;

    $msg =~ s/\s+/ /g;
    if ( length($msg) > $self->comment_length ) {
        my $limit = $self->comment_length - 3;
        $msg =~ s/^(.{$limit}).*$/$1.../;
    }
    #$msg = Text::WrapI18N::wrap(q{  }, q{  }, $msg);

    return $msg;
}

1;
