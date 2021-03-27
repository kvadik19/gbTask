#! /usr/bin/perl
# Site operations
# 2021 (c) mac-t@yandex.ru
package Test::Drive;
use utf8;
use Encode;
use strict;
use warnings;
use Cwd 'abs_path';
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(j decode_json encode_json);
use Mojo::Util qw(url_escape url_unescape b64_encode  trim md5_sum);
use File::Path qw(make_path mkpath remove_tree rmtree);
use Time::HiRes;

our $sys = $Drive::sys;

use Data::Dumper;

#################
sub dispatch {	# All of operations dispatcher for authorized user
#################
my $self = shift;
	my $out;
	my $template = 'loader';
	my $path = [ split(/\//, $self->stash('path')) ];
	my $action = shift( @$path) || 'default';

	eval { $out = $self->$action };
	if ( $@) {			# Special sub is not defined (yet?)
		$out = {'html_code' => "404 : Page $action not found yet", 'http_state' => 404 };
	}

	if ( ref($out) eq 'HASH' ) {
		if ( exists( $out->{'json'}) ) {
			$self->render( type => 'application/json', json => $out->{'json'} );
			return;
		} elsif( exists($out->{'redirect'})) {
			$self->redirect_to( $out->{'redirect'} );
			return;
		} else {
			while ( my ($key, $val) = each(%$out) ) {
				$self->stash( $key => $val );
			}
		}
	} else {
		$self->stash( 'html_code' => $out );
	}
	$self->render( template => $template, status => $self->stash('http_state') );
}
#################
sub quest {		# Select records from table
#################
my $self = shift;
	my $ret = {'json' => {'code' => 0, 'data' => []}};
	if ( $self->{'param'}->{'address'} ) {
		my $sql = "SELECT str FROM log LEFT JOIN message ON message.int_id=log.int_id ".
					"ORDER BY message.id,log.created";
	}

	return $ret
}
1
