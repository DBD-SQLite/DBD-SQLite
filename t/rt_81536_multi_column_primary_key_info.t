#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More;
use Test::NoWarnings;

plan tests => 10 + 1;

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
	is @pk_info => 2, "found 1 pks";
	is $pk_info[0]{COLUMN_NAME} => 'type', "first pk name is type";
	is $pk_info[1]{COLUMN_NAME} => 'id', "second pk name is id";
}
