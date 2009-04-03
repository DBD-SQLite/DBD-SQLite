#!/usr/bin/perl

# Tests basic login and pragma setting

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 6;
use t::lib::Test;

my $dbh = connect_ok();
ok( $dbh->{sqlite_version}, '->{sqlite_version} ok' );
is( $dbh->{AutoCommit}, 1, 'AutoCommit is on by default' );
diag("sqlite_version=$dbh->{sqlite_version}");
ok( $dbh->func('busy_timeout'), 'Found initial busy_timeout' );
ok( $dbh->func(5000, 'busy_timeout') );
is( $dbh->func('busy_timeout'), 5000, 'Set busy_timeout to new value' );

$dbh->disconnect;
