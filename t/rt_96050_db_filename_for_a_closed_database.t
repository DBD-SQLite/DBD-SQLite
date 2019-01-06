#!/usr/bin/env perl

use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

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

done_testing;
