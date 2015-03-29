#!/usr/bin/env perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;
use Test::NoWarnings;

my $tests = 2;
plan tests => 1 + $tests * @CALL_FUNCS + 1;

my $dbh = connect_ok( RaiseError => 1, PrintError => 0 );
for my $func (@CALL_FUNCS) {
	my $filename = eval { $dbh->$func('db_filename') };
	ok !$@, "no filename (because it's in-memory); no error";
}

$dbh->disconnect;

for my $func (@CALL_FUNCS) {
	my $filename = eval { $dbh->$func('db_filename') };
	ok !$@ && !$filename, "got no error; no filename; and no segfault";
}
