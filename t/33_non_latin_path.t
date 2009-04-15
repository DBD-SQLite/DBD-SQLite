#!/usr/bin/perl

# Tests path containing non-latine-1 characters
# currently fails on Windows

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}
use utf8;

use t::lib::Test;
use Test::More;
use Test::NoWarnings;
use File::Temp            qw(tempdir);
use File::Spec::Functions qw(catdir catfile);

my @words = ('database', 'adatbázis');
plan tests => 1 + @words * 3;

my $dir = tempdir( CLEANUP => 1 );

foreach my $subdir (@words) {
	ok(mkdir(catdir($dir, $subdir)), "subdir $subdir created");
	my $dbfile = catfile($dir, $subdir, 'db.db');
	eval {
		DBI->connect("dbi:SQLite:dbname=$dbfile", "", "", {RaiseError => 1, PrintError => 0});
	};
	ok(!$@, "Could connect to database in $subdir") or diag $@;
	
	# when the name of the database file has non-latin characters
	my $dbfilex = catfile($dir, "$subdir.db");
	eval {
		DBI->connect("dbi:SQLite:dbname=$dbfilex", "", "", {RaiseError => 1, PrintError => 0});
	};
	ok(!$@, "Could connect to database in $dbfilex") or diag $@;
}



