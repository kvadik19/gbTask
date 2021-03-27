#!/usr/bin/env perl

use 5.18.0;
use strict;
use utf8;
use Encode;
use DBI;

my $fin = shift;
unless ( $fin && -r($fin) ) {			# Check input file
	say "File $fin is not readable";
	exit 1;
}

my $sys = {};
open my $fh, "< test.conf" || die "Can't read config!";			# Read config
while ( my $str = <$fh> ) {
	next if $str =~ /^\s*#/;
	my ($key, $val) = $str =~ /^\s*(.+)="(.+)"/;
	next unless $key;
	$sys->{$key} = $val;
}
close $fh;
#####

my $dbh = DBI->connect("DBI:mysql:$sys->{'db_base'}:$sys->{'db_host'}", $sys->{'db_user'}, $sys->{'db_pass'},
										{mysql_enable_utf8 => 1,PrintError => 0, RaiseError => 1});

eval { $dbh->do("DELETE message,log FROM message,log")};		# Prepare glade
if ( $@ ) {
	say "$@You must to run script/db_update.pl first!";
	exit 1;
}

my $flag = {
			'from'	=> '<=',
			'to'	=> '=>',
			'cc'	=> '->',
			'fail'	=> '**',
			'hold'	=> '==',
			'<='	=> 'from',
			'=>'	=> 'to',
			'->'	=> 'cc'	,
			'**'	=> 'fail',
			'=='	=> 'hold',
		};
my $datamap = {
		'message' => {
				'struct' => ['created',
							'id',
							'int_id',
							'str',
							'status'],
				'cache' => []
			},
		'log' => {
				'struct' => ['created',
							'int_id',
							'str',
							'address'],
				'cache' => []
			}
	};

my $maxlen = 0;
my $cnt = 1;
open( my $fh, "< $fin");
while( my $str = <$fh> ) {			# Now reading
	chomp($str);
	my @fields = split(/ /, $str);

	my $ins = { 'id' => $cnt++ };
	$ins->{'created'} = shift( @fields);			# Must be cutted from string
	$ins->{'created'} .= ' '.shift( @fields);

	$ins->{'int_id'} = $fields[0];
	$ins->{'flag'} = $fields[1];
	$ins->{'str'} = join(' ', @fields);			# Rejoin fields without timestamp

	my $strlen = length($ins->{'str'});
	$maxlen =  $strlen if $strlen > $maxlen;		# Just interesting
	$ins->{'address'} = '';

	$ins->{'address'} = $fields[2] if exists( $flag->{$ins->{'flag'}} );

	my $table = 'log';
	$table = 'message' if $ins->{'flag'} eq $flag->{'from'};

	push( @{$datamap->{$table}->{'cache'}}, $ins);
	flush_data( $table ) if scalar( @{$datamap->{$table}->{'cache'}} ) >= $sys->{'cache_size'};
}
close($fh);

foreach my $table ( keys( %$datamap) ) {		# Finally, purge possibly unflushed
	flush_data($table);
}

say "Longest line = $maxlen";
$dbh->disconnect();
exit 0;

#####################
sub flush_data {	#		Periodically flushes values stack
#####################
	my $table = shift;

	my $qty = scalar( @{$datamap->{$table}->{'cache'}} );
	if ( $qty ) {
		my $fields = join(',', @{$datamap->{$table}->{'struct'}} );
		my $values = '';
		while ( my $row = shift( @{$datamap->{$table}->{'cache'}}) ) {
			my $valrow = '';
			foreach my $fld ( @{$datamap->{$table}->{'struct'}} ) {
				my $val = mysqlmask( $row->{$fld} );
				$valrow .= ",'$val'";
			}
			$valrow =~ s/^,//;
			$values .= ",($valrow)";
		}
		$values =~ s/^,//;
		$dbh->do("INSERT INTO $table ($fields) VALUES $values");
	}
	return $qty;
}

#####################
sub mysqlmask {		# Quote some characters that can't be stored in MySQL table
#####################
my ($value, $unmask) = @_;
	if ( $unmask ) {
		$value =~ s/%(\w{2})/pack( 'H*', $1)/gei;
	} else {
		$value =~ s/([\'\"\\\%;])/'%'.unpack( 'H*', $1 )/eg;
	}
	return $value;
}
