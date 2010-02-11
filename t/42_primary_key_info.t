#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More;
use Test::NoWarnings;

plan tests => 4 * 5 + 1;

for my $quote ('', qw/' " `/) {
	my $dbh = connect_ok( RaiseError => 1 );
	ok $dbh->do(
		"create table ${quote}foo${quote} (${quote}id${quote} integer primary key)"
	);
	my $sth = $dbh->primary_key_info(undef, undef, 'foo');
	my $pk = $sth->fetchrow_hashref;
	ok $pk->{TABLE_NAME} eq 'foo'; # dequoted
	ok $pk->{COLUMN_NAME} eq 'id'; # dequoted

	($pk) = $dbh->primary_key(undef, undef, 'foo');
	ok $pk eq 'id';
}
