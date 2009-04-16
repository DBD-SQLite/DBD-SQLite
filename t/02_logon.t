#!/usr/bin/perl

# Tests basic login and pragma setting

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More tests => 10;
use Test::NoWarnings;

# Ordinary connect
SCOPE: {
	my $dbh = connect_ok();
	ok( $dbh->{sqlite_version}, '->{sqlite_version} ok' );
	is( $dbh->{AutoCommit}, 1, 'AutoCommit is on by default' );
	diag("sqlite_version=$dbh->{sqlite_version}");
	ok( $dbh->func('busy_timeout'), 'Found initial busy_timeout' );
	ok( $dbh->func(5000, 'busy_timeout') );
	is( $dbh->func('busy_timeout'), 5000, 'Set busy_timeout to new value' );
}

# Attributes in the connect string
SKIP: {
	unless ( $] >= 5.008005 ) {
		skip( 'Unicode is not supported before 5.8.5', 2 );
	}
	my $dbh = DBI->connect( 'dbi:SQLite:dbname=foo;unicode=1', '', '' );
	isa_ok( $dbh, 'DBI::db' );
	is( $dbh->{unicode}, 1, 'Unicode is on' );
}

# Connect to a memory database
SCOPE: {
	my $dbh = DBI->connect( 'dbi:SQLite:dbname=:memory:', '', '' );
	isa_ok( $dbh, 'DBI::db' );	
}
