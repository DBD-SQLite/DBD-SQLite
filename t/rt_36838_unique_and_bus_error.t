#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 3;
use t::lib::Test;

my $dbh = connect_ok( RaiseError => 1, PrintError => 0 );

$dbh->do("CREATE TABLE nums (num INTEGER UNIQUE)");

ok $dbh->do("INSERT INTO nums (num) VALUES (?)", undef, 1);

eval { $dbh->do("INSERT INTO nums (num) VALUES (?)", undef, 1); };
ok $@ =~ /column num is not unique/, $@;  # should not be a bus error
