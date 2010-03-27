#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More;
use Test::NoWarnings;

plan tests => 5 * 5 + 1;

for my $quote ('', qw/' " ` []/) {
	my ($begin_quote, $end_quote) = (substr($quote, 0, 1), substr($quote, -1, 1));
	my $dbh = connect_ok( RaiseError => 1 );
	ok $dbh->do(
		"create table ${begin_quote}foo${end_quote} (${begin_quote}id${end_quote} integer primary key)"
	);
	my $sth = $dbh->primary_key_info(undef, undef, 'foo');
	my $pk = $sth->fetchrow_hashref;
	ok $pk->{TABLE_NAME} eq 'foo'; # dequoted
	ok $pk->{COLUMN_NAME} eq 'id'; # dequoted

	($pk) = $dbh->primary_key(undef, undef, 'foo');
	ok $pk eq 'id';
}
