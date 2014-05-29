#!/usr/bin/env perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More tests => 4;
use Test::NoWarnings;

my $dbh = connect_ok( RaiseError => 1, PrintError => 0 );
{
	my $filename = eval { $dbh->sqlite_db_filename };
	ok !$@, "no filename (because it's in-memory); no error";
}

$dbh->disconnect;

{
	my $filename = eval { $dbh->sqlite_db_filename };
	ok !$@ && !$filename, "got no error; no filename; and no segfault";
}
