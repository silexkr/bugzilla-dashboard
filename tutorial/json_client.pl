#!/usr/bin/env perl 

use 5.010;
use utf8;
use strict;
use warnings;

use Data::Dumper;
use HTTP::Cookies;
use JSON::RPC::Legacy::Client;

package JSON::RPC::Legacy::ReturnObject; {
	{
		no warnings 'redefine';
		sub new {
			my ($class, $obj, $json) = @_;
			my $content = ( $json || JSON->new->utf8 )->decode( $obj->content );

			my $self = bless {
				jsontext => $obj->content,
				content  => $content,
				obj      => $obj,
			}, $class;

			$content->{error} ? $self->is_success(0) : $self->is_success(1);
			$content->{version} ? $self->version(1.1) : $self->version(0);

			$self;
		}
	}

	sub obj {
		$_[0]->{obj} = $_[1] if defined $_[1];
		$_[0]->{obj};
	}

} 1;

package main;

my $client = JSON::RPC::Legacy::Client->new;
my $URI = "http://jehos.silex.kr/bugzilla/jsonrpc.cgi";

my $res = $client->call(
	$URI,
	{ # callobj
		method => 'User.login',
		params => {
			login	 => 'jeho.sung@silex.kr',
			password => 'action+vision',
		}
	}
);
die $client->status_line unless $res;
die "Error: " . $res->error_message if $res->is_error;

#
# extract cookie and add cookie
#
my $cookie_jar = HTTP::Cookies->new({});
$cookie_jar->extract_cookies( $res->obj );
$client->ua->cookie_jar($cookie_jar);

#
# get user info
#
$res = $client->call(
	$URI,
	{ # callobj
		method => 'User.get',
		params => {
			names => [ 'jeho.sung@silex.kr' ],
		},
	},
	$cookie_jar,
);

die $client->status_line unless $res;
die "Error: " . $res->error_message if $res->is_error;
say Dumper $res->result;

