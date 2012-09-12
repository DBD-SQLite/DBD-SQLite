#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More;
use Test::NoWarnings;

plan tests => (5 * 5) + (3 * 6 + 1) + 1;

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

{
	my $dbh = connect_ok();
	$dbh->do("create table foo (id integer primary key)");
	$dbh->do("attach database ':memory:' as remote");
	$dbh->do("create table remote.bar (name text, primary key(name))");
	$dbh->do("create temporary table baz (tmp primary key)");

	{
		my $sth = $dbh->primary_key_info(undef, undef, 'foo');
		my @pk_info;
		while(my $row = $sth->fetchrow_hashref) { push @pk_info, $row };
		is @pk_info => 1, "found 1 pk in a table";
		is $pk_info[0]{TABLE_SCHEM} => 'main', "scheme is correct";
		is $pk_info[0]{COLUMN_NAME} => 'id', "pk name is correct";
	}

	{
		my $sth = $dbh->primary_key_info(undef, 'main', undef);
		my @pk_info;
		while(my $row = $sth->fetchrow_hashref) { push @pk_info, $row };
		is @pk_info => 1, "found 1 pk in a table";
		is $pk_info[0]{TABLE_SCHEM} => 'main', "scheme is correct";
		is $pk_info[0]{COLUMN_NAME} => 'id', "pk name is correct";
	}

	{
		my $sth = $dbh->primary_key_info(undef, undef, 'bar');
		my @pk_info;
		while(my $row = $sth->fetchrow_hashref) { push @pk_info, $row };
		is @pk_info => 1, "found 1 pk in an attached table";
		is $pk_info[0]{TABLE_SCHEM} => 'remote', "scheme is correct";
		is $pk_info[0]{COLUMN_NAME} => 'name', "pk name is correct";
	}

	{
		my $sth = $dbh->primary_key_info(undef, 'remote', undef);
		my @pk_info;
		while(my $row = $sth->fetchrow_hashref) { push @pk_info, $row };
		is @pk_info => 1, "found 1 pk in an attached table";
		is $pk_info[0]{TABLE_SCHEM} => 'remote', "scheme is correct";
		is $pk_info[0]{COLUMN_NAME} => 'name', "pk name is correct";
	}

	{
		my $sth = $dbh->primary_key_info(undef, 'temp', undef);
		my @pk_info;
		while(my $row = $sth->fetchrow_hashref) { push @pk_info, $row };
		is @pk_info => 1, "found 1 pk in a table";
		is $pk_info[0]{TABLE_SCHEM} => 'temp', "scheme is correct";
		is $pk_info[0]{COLUMN_NAME} => 'tmp', "pk name is correct";
	}

	{
		my $sth = $dbh->primary_key_info(undef, undef, 'baz');
		my @pk_info;
		while(my $row = $sth->fetchrow_hashref) { push @pk_info, $row };
		is @pk_info => 1, "found 1 pk in an attached table";
		is $pk_info[0]{TABLE_SCHEM} => 'temp', "scheme is correct";
		is $pk_info[0]{COLUMN_NAME} => 'tmp', "pk name is correct";
	}
}