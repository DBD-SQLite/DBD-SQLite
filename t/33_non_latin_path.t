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

my @subdirs = ('database', 'adatbázis');
plan tests => 1 + @subdirs * 2;

my $dir = tempdir( CLEANUP => 1 );

foreach my $subdir (@subdirs) {
	ok(mkdir(catdir($dir, $subdir)), "$subdir created");
	my $dbfile = catfile($dir, $subdir, 'db.db');
	eval {
		DBI->connect("dbi:SQLite:dbname=$dbfile");
	};
	ok(!$@, "Could connect to database in $subdir") or diag $@;
}


