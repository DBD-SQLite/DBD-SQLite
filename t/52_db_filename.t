#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok @CALL_FUNCS/;
use Test::More;
use Test::NoWarnings;

plan tests => 6 * @CALL_FUNCS + 1;

for my $func (@CALL_FUNCS) {
	{
		my $db = filename($func);
		ok !$db, "in-memory database";
	}

	{
		my $db = filename($func, dbfile => '');
		ok !$db, "temporary database";
	}

	{
		my $db = filename($func, dbfile => 'test.db');
		like $db => qr/test\.db[\d]*$/i, "test.db";
		unlink $db;
	}
}

sub filename {
	my $func = shift;
	my $dbh = connect_ok(@_);
	$dbh->$func('db_filename');
}
