#!/usr/bin/perl

# Test that everything compiles, so the rest of the test suite can
# load modules without having to check if it worked.

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 3;

use lib "t/lib";

use_ok('DBI');
use_ok('DBD::SQLite');
use_ok('SQLiteTest');

diag("\$DBI::VERSION=$DBI::VERSION");

if (my @compile_options = DBD::SQLite::compile_options()) {
    diag("Compile Options:");
    diag(join "", map { "  $_\n" } @compile_options);
}
