# Tests path containing non-latine-1 characters
# currently fails on Windows

use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";
use File::Temp ();
use File::Spec::Functions ':ALL';

use DBD::SQLite::Constants ':dbd_sqlite_string_mode';

my $unicode_opt = DBD_SQLITE_STRING_MODE_UNICODE_STRICT;

BEGIN { requires_unicode_support() }

my $dir = File::Temp::tempdir( CLEANUP => 1 );
foreach my $subdir ( 'longascii', 'adatbázis', 'name with spaces', '¿¿¿ ¿¿¿¿¿¿') {
	if ($^O eq 'cygwin') {
		next if (($subdir eq 'adatbázis') || ($subdir eq '¿¿¿ ¿¿¿¿¿¿'));
	}
	# rt48048: don't need to "use utf8" nor "require utf8"
	utf8::upgrade($subdir);
	ok(
		mkdir(catdir($dir, $subdir)),
		"$subdir created",
	);

	# Open the database
	my $dbfile = catfile($dir, $subdir, 'db.db');
	eval {
		my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", undef, undef, {
			RaiseError => 1,
			PrintError => 0,
		} );
		isa_ok( $dbh, 'DBI::db' );
	};
	is( $@, '', "Could connect to database in $subdir" );
	diag( $@ ) if $@;

	# Reopen the database
	eval {
		my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", undef, undef, {
			RaiseError => 1,
			PrintError => 0,
		} );
		isa_ok( $dbh, 'DBI::db' );
	};
	is( $@, '', "Could connect to database in $subdir" );
	diag( $@ ) if $@;

	unlink(_path($dbfile))  if -e _path($dbfile);

	# Repeat with the unicode flag on
	my $ufile = $dbfile;
	eval {
		my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", undef, undef, {
			RaiseError => 1,
			PrintError => 0,
			sqlite_string_mode => $unicode_opt,
		} );
		isa_ok( $dbh, 'DBI::db' );
	};
	is( $@, '', "Could connect to database in $subdir" );
	diag( $@ ) if $@;

	# Reopen the database
	eval {
		my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", undef, undef, {
			RaiseError => 1,
			PrintError => 0,
			sqlite_string_mode => $unicode_opt,
		} );
		isa_ok( $dbh, 'DBI::db' );
	};
	is( $@, '', "Could connect to database in $subdir" );
	diag( $@ ) if $@;

	unlink(_path($ufile))  if -e _path($ufile);
	
	# when the name of the database file has non-latin characters
	my $dbfilex = catfile($dir, "$subdir.db");
	eval {
		DBI->connect("dbi:SQLite:dbname=$dbfilex", "", "", {RaiseError => 1, PrintError => 0});
	};
	ok(!$@, "Could connect to database in $dbfilex") or diag $@;
	ok -f _path($dbfilex), "file exists: "._path($dbfilex)." ($dbfilex)";

	# Reopen the database
	eval {
		DBI->connect("dbi:SQLite:dbname=$dbfilex", "", "", {RaiseError => 1, PrintError => 0});
	};
	ok(!$@, "Could connect to database in $dbfilex") or diag $@;

	unlink(_path($dbfilex))  if -e _path($dbfilex);
}

# connect to an empty filename - sqlite will create a tempfile
eval {
	my $dbh = DBI->connect("dbi:SQLite:dbname=", undef, undef, {
		RaiseError => 1,
		PrintError => 0,
	} );
	isa_ok( $dbh, 'DBI::db' );
};
is( $@, '', "Could connect to temp database (empty filename)" );
diag( $@ ) if $@;

sub _path {  # copied from DBD::SQLite::connect
	my $path = shift;

	if ($^O =~ /MSWin32/) {
		require Win32;
		require File::Basename;

		my ($file, $dir, $suffix) = File::Basename::fileparse($path);
		my $short = Win32::GetShortPathName($path);
		if ( $short && -f $short ) {
			# Existing files will work directly.
			$path = $short;
		} elsif ( -d $dir ) {
			$path = join '', grep { defined } Win32::GetShortPathName($dir), $file, $suffix;
		}
	}
	return $path;
}

done_testing;
