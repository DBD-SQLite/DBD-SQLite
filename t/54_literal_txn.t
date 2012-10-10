#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More;

my $dbh = connect_ok();

is $dbh->{AutoCommit}, 1,
	'AutoCommit=1 at connection';

$dbh->do('BEGIN TRANSACTION');

is $dbh->{AutoCommit}, '',
	"AutoCommit='' after 'BEGIN TRANSACTION'";

$dbh->do("SELECT 1 FROM sqlite_master LIMIT 1");

$dbh->do("\nCOMMIT");

is $dbh->{AutoCommit}, 1,
	'AutoCommit=1 after "\nCOMMIT"';

done_testing;
