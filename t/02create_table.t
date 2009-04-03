#!/usr/bin/perl

# Tests simple table creation

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 5;
use t::lib::Test;

my $dbh = sqlite_connect();
$dbh->{AutoCommit} = 1;
$dbh->do("CREATE TABLE f (f1, f2, f3)");

SCOPE: {
	my $sth = $dbh->prepare("SELECT f.f1, f.* FROM f");
	isa_ok( $sth, 'DBI::st' );
	ok( $sth->execute, '->execute ok' );
	my $names = $sth->{NAME};
	is( scalar(@$names), 4, 'Got 4 columns' );
	is_deeply( $names, [ 'f1', 'f1', 'f2', 'f3' ], 'Table prepending is disabled by default' );
}

$dbh->disconnect;
