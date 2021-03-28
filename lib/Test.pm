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
	$r->route('/')->to( controller =>'respond', action =>'dispatch' );
	$r->route('/*path')->to( controller =>'respond', action =>'dispatch' );

	open my $fh, "< $sys_root/config/test.conf";			# Read config
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
	$self->helper( dbh => $dbh );
	$self->helper( logger => sub { return $logger } );
	$self->helper( mysqlmask => sub {		# Quote some characters that can't be stored in MySQL table
										my ($self, $value, $unmask) = @_;
										if ( $unmask ) {
											$value =~ s/%(\w{2})/pack( 'H*', $1)/gei;
										} else {
											$value =~ s/([\'\"\\\%;])/'%'.unpack( 'H*', $1 )/eg;
										}
										return $value;
									}
				);

	$self->hook( before_dispatch => sub {
						my $self = shift;
						$logger->debug(">>>> ".$self->req->headers->every_header('x-real-ip')->[0]." => ".
											$self->req->method.": ".$self->req->url->base.$self->req->url->path );
						foreach my $dir ( qw(js css) ) {			# Compose js/css version numbers to prevent browser caching
							$self->{'stats'}->{$dir} = (stat("$sys_root/htdocs/$dir"))[9];
						}

						my $pnames = $self->req->params->names;
						foreach my $par ( @$pnames) {
							$self->{'param'}->{$par} = $self->param($par);
							# Decode from IE shit
							$self->{'param'}->{$par} = encode_json( decode_json($self->param($par))) if $self->param($par) =~ /(\\u[\da-f]{4})+/i;
							if ( $self->{'param'}->{$par} =~ /^[\{\[].+[\]\}]$/ ) {		# Got JSON?
								my $data = $self->{'param'}->{$par};
								$data = url_unescape( $data );
								eval { $data = decode_json( encode_utf8($data) ) };
								unless ( $@ ) {
									$self->{'param'}->{$par} = $data;
								} else {
									$self->logger->debug("Decode param '$par' : $@");
								}
							}
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
	map { $date[$_] = sprintf('%02d', $date[$_]) } (0, 1, 2, 3, 4);

	return ($date[5], $date[4], $date[3],$date[2],$date[1],$date[0],$date[6]) if wantarray();
	return "$date[3]-$date[4]-$date[5] $date[2]:$date[1]:$date[0].$date[6]";
}
1;
