#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More;
use Test::NoWarnings;

plan tests => 15 + 1;

# single column integer primary key
{
	my $dbh = connect_ok();
	$dbh->do("create table foo (id integer primary key, type text)");

	my $sth = $dbh->primary_key_info(undef, undef, 'foo');
	my @pk_info;
	while(my $row = $sth->fetchrow_hashref) { push @pk_info, $row };
	is @pk_info => 1, "found 1 pks";
	is $pk_info[0]{COLUMN_NAME} => 'id', "first pk name is id";
}

# single column not-integer primary key
{
	my $dbh = connect_ok();
	$dbh->do("create table foo (id text primary key, type text)");

	my $sth = $dbh->primary_key_info(undef, undef, 'foo');
	my @pk_info;
	while(my $row = $sth->fetchrow_hashref) { push @pk_info, $row };
	is @pk_info => 1, "found 1 pks";
	is $pk_info[0]{COLUMN_NAME} => 'id', "first pk name is id";
}

# multi-column primary key
{
	my $dbh = connect_ok();
	$dbh->do("create table foo (id id, type text, primary key(type, id))");

	my $sth = $dbh->primary_key_info(undef, undef, 'foo');
	my @pk_info;
	while(my $row = $sth->fetchrow_hashref) { push @pk_info, $row };
       is @pk_info => 2, "found 2 pks";
	is $pk_info[0]{COLUMN_NAME} => 'type', "first pk name is type";
	is $pk_info[1]{COLUMN_NAME} => 'id', "second pk name is id";
}

# multi-column primary key with quotes
{
	my $dbh = connect_ok();
	$dbh->do('create table foo (a, b, "c""d", unique(a, b, "c""d"), primary key( "c""d", [b], `a` ))');

	my $sth = $dbh->primary_key_info(undef, undef, 'foo');
	my @pk_info;
	while(my $row = $sth->fetchrow_hashref) { push @pk_info, $row };
	is @pk_info => 3, "found 3 pks";
	my @pk = map $_->{COLUMN_NAME}, @pk_info;
	is join(' ', sort @pk) => 'a b c"d', 'all pks are correct';
	is join(' ', @pk) => 'c"d b a', 'pk order is correct';
	@pk = map $_->{COLUMN_NAME}, sort {$a->{KEY_SEQ} <=> $b->{KEY_SEQ}} @pk_info;
	is join(' ', @pk) => 'c"d b a', 'pk KEY_SEQ is correct';
}
