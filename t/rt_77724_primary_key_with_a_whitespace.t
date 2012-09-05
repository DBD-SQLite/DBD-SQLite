#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More tests => 4;
use Test::NoWarnings;

my $dbh = connect_ok(RaiseError => 1, PrintError => 0);

$dbh->do($_) for
	q[CREATE TABLE "Country Info" ("Country Code" CHAR(2) PRIMARY KEY, "Name" VARCHAR(200))],
	q[INSERT INTO "Country Info" VALUES ('DE', 'Germany')],
	q[INSERT INTO "Country Info" VALUES ('FR', 'France')];

my $sth = $dbh->primary_key_info(undef, undef, "Country Info");
my $row = $sth->fetchrow_hashref;
ok $row, 'Found the primary key column.';

is $row->{COLUMN_NAME} => "Country Code",
	'Key column name reported correctly.'
	or note explain $row;
