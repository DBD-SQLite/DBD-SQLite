#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More;
use Test::NoWarnings;

plan tests => 9;

my $dbh = connect_ok( RaiseError => 1 );
ok $dbh->do('create table foo (id integer, value integer)');

ok $dbh->do('insert into foo values(?, ?)',   undef, 1, 2);
ok $dbh->do('insert into foo values(?1, ?2)', undef, 2, 3);
ok $dbh->do('insert into foo values(:1, :2)', undef, 3, 4);
ok $dbh->do('insert into foo values(@1, @2)', undef, 4, 4);

SKIP: {
	skip "this placeholder requires SQLite 3.6.19 and newer", 2 
        unless $DBD::SQLite::sqlite_version_number && $DBD::SQLite::sqlite_version_number >= 3006019;
    ok $dbh->do(
		'update foo set id = $1 where value = $2 and id is not $1',
		undef, 3, 4
	);

    my ($count) = $dbh->selectrow_array(
    	'select count(id) from foo where id = ? and value = ?',
    	undef, 3, 4
    );

    ok $count == 2;
}
