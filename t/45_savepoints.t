#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More tests => 5;
use Test::NoWarnings;

my $dbh = connect_ok(
	AutoCommit => 1,
	RaiseError => 1,
);

$dbh->begin_work;

$dbh->do("CREATE TABLE MST (id, lbl)");

$dbh->do("SAVEPOINT svp_0");

$dbh->do("INSERT INTO MST VALUES(1, 'ITEM1')");
$dbh->do("INSERT INTO MST VALUES(2, 'ITEM2')");
$dbh->do("INSERT INTO MST VALUES(3, 'ITEM3')");

my $ac = $dbh->{AutoCommit};

ok((not $ac), 'AC != 1 inside txn');

{
	local $dbh->{AutoCommit} = $dbh->{AutoCommit};

	$dbh->do("ROLLBACK TRANSACTION TO SAVEPOINT svp_0");

	is $dbh->{AutoCommit}, $ac,
		"rolling back savepoint doesn't alter AC";
}

is $dbh->selectrow_array("SELECT COUNT(*) FROM MST"), 0,
	"savepoint rolled back";

$dbh->rollback;
