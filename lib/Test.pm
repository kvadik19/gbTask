package Test;
use 5.18.0;
use strict;
use utf8;

use Mojo::Base 'Mojolicious';
use Mojo::Base 'Mojolicious::Controller';
use FindBin;
use Mojo::JSON qw(j decode_json encode_json);
use Mojo::Util qw(url_escape url_unescape b64_encode  trim md5_sum);
use Time::HiRes;

use Data::Dumper;


use DBI;

our $sys;
our $sys_root;
our $logger;
our $dbh;

#################
sub startup {
#################
	my $self = shift;
# kill( 'SIGUSR2', $mypid)
	$self->config( hypnotoad => { listen => [ "http://127.0.0.1:9510",
											"https://127.0.0.1:9509" ],	# Need to be set in nginx map directive
								workers => 2,		# two worker processes per CPU core
								spare => 8,
								proxy => 0,
								} );
	$self->plugin('DefaultHelpers');
	$self->secrets( ['sug4hyg327ah243Hhjck'] );
	$self->plugin('PODRenderer');
	$sys_root = "$FindBin::Bin/..";

	my $r = $self->routes;
	$r->any(['GET', 'POST'] => '/' => sub { return loader( shift ) });
	$r->any(['GET', 'POST'] => '/*path' => sub { return loader( shift ) });

	open my $fh, "< $sys_root/test.conf";			# Read config
	while ( my $str = <$fh> ) {
		next if $str =~ /^\s*#/;
		my ($key, $val) = $str =~ /^\s*(.+)="(.+)"/;
		next unless $key;
		$sys->{$key} = $val;
	}
	close $fh;

	$logger = Mojo::Log->new( path => "$sys_root/log/$sys->{'logfile'}", level => 'debug');
	$logger->format(sub {
						my ($time, $level, @lines) = @_;
						return timestr()."\t$$\t".(join("\n",@lines))."\n";
					});

	my $dbh = sub {
					return DBI->connect("DBI:mysql:$sys->{'db_base'}:$sys->{'db_host'}", $sys->{'db_user'}, $sys->{'db_pass'},
										{mysql_enable_utf8 => 1,PrintError => 0, RaiseError => 1});
					};
	$self->helper(dbh => $dbh );
	$self->helper(logger => sub { return $logger } );

	$self->hook( before_dispatch => sub {
						my $self = shift;
						$logger->debug(">>>> ".$self->req->headers->every_header('x-real-ip')->[0]." => ".
											$self->req->method.": ".$self->req->url->base.$self->req->url->path );
						foreach my $dir ( qw(js css) ) {			# Compose js/css version numbers to prevent browser caching
							$self->{'stats'}->{$dir} = (stat("$sys_root/htdocs/$dir"))[9];
						}
						$self->stash(
								http_state => 200,
								stats => $self->{'stats'},
							);
						$self->layout('default');
					}
			);
	$logger->debug("Starting server pid $$ on defined ports.");
}

#################
sub loader {	#	All of queries operation
#################
	my $self = shift;
	my $http_state = 200;
	my $path = [split(/\//, $self->stash('path'))];

	$self->stash(
			http_state => $http_state,
		);

	$self->render( template => 'test/loader', status => $http_state );
}
#################
sub timestr {					#  Make string from serial date number
#################
my ($datetime, $gmt) = @_;

	$datetime = $datetime || Time::HiRes::time();
	$datetime = sprintf( '%.2f', $datetime );

	my @date = localtime( $datetime );		#  Further need
	@date = gmtime( $datetime ) if $gmt;		#  GMT

	$date[6] = substr($datetime,index($datetime, '.')+1) if $datetime =~ /\./;

	$date[5]+=1900;
	$date[4]++;
	map { $date[$_] = "0" x ( 2 - length( $date[$_] ) ) . $date[$_] } (0, 1, 2, 3, 4);

	return ($date[5], $date[4], $date[3],$date[2],$date[1],$date[0],$date[6]) if wantarray();
	return "$date[3]-$date[4]-$date[5] $date[2]:$date[1]:$date[0].$date[6]";
}
1;
