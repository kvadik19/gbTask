#! /usr/bin/perl
# Site operations
# 2021 (c) mac-t@yandex.ru
package Test::Respond;
use utf8;
use Encode;
use strict;
use warnings;
use Cwd 'abs_path';
use Mojo::Base 'Mojolicious::Controller';

our $sys = $Test::sys;

use Data::Dumper;

#################
sub dispatch {	# All of operations dispatcher for authorized user
#################
my $self = shift;
	my $out;
	my $template = 'loader';
	my $path = [ split(/\//, $self->stash('path')) ];
	my $action = shift( @$path) || 'root';

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
sub root {		# Default for site root
#################
my $self = shift;
	return;
}
#################
sub quest {		# Select records from table
#################
my $self = shift;
	my $ret = {'html_code' => "418 : I'm a teapot", 'http_state' => 418};
	my $from = $self->{'param'}->{'f'} || 0;
	my $qty = $self->{'param'}->{'q'} || $sys->{'msg_count'};

	if ( $self->{'param'}->{'address'} ) {
		my $addr = $self->mysqlmask( $self->{'param'}->{'address'} );
		my $total = $self->dbh->selectrow_arrayref( "SELECT COUNT(DISTINCT log.int_id) FROM log,message "
											."WHERE message.int_id=log.int_id AND log.address='$addr'" )->[0];
		my $sql = "SELECT DISTINCT message.str AS msg,log.str AS log,"
						."log.created AS logtime,message.created AS msgtime,"
						."message.id,log.int_id "
						."FROM log LEFT JOIN message ON message.int_id=log.int_id "
						."WHERE log.address='$addr' "
						."ORDER BY log.int_id,log.created";
		my $data = [];
		my $tabsize = 0;
		my $qw = $self->dbh->prepare( $sql);
		$qw->execute();

		my $id;				# Controls lines grouping
		while ( my $row_in = $qw->fetchrow_hashref() ) {			# Result may be too large
			my $logdata = {'time' => $row_in->{'logtime'}, 'str' =>  $self->mysqlmask($row_in->{'log'}, 1) };
			if ( $row_in->{'id'} && $row_in->{'id'} ne $id) {
				$id = $row_in->{'id'};
				my $row_out = {'id' => $id, 
							'int_id' => $row_in->{'int_id'}, 
							'str' =>  $self->mysqlmask( $row_in->{'msg'}, 1), 
							'time' => $row_in->{'msgtime'}, 
							'log' => [ $logdata ]
						};
				push( @$data, $row_out);
				$tabsize++;
			} elsif( $row_in->{'id'} ) {
				push( @{$data->[-1]->{'log'}}, $logdata );
			}
			last if $tabsize >= $qty;
		}
		$qw->finish();

		$ret = {'json' => {'qty' => scalar( @$data), 
							'address' => $self->{'param'}->{'address'}, 
							'total' => $total, 
							'data' => $data
							}
					};
	}

	return $ret
}
1
