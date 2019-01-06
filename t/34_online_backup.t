use strict;
use warnings;

use Test::More;
use lib "t/lib";
use SQLiteTest qw/connect_ok dbfile @CALL_FUNCS requires_sqlite/;

BEGIN { requires_sqlite('3.6.11') }

use if -d ".git", "Test::FailWarnings";
use DBI;

foreach my $call_func (@CALL_FUNCS) {
	# Connect to the test db and add some stuff:
	my $foo = connect_ok( dbfile => 'foo', RaiseError => 1 );
	my $dbfile = dbfile('foo');
	$foo->do(
	    'CREATE TABLE online_backup_test( id INTEGER PRIMARY KEY, foo INTEGER )'
	);
	$foo->do("INSERT INTO online_backup_test (foo) VALUES ($$)");

	# That should be in the "foo" database on disk now, so disconnect and try to
	# back it up:

	$foo->disconnect;

	my $dbh = DBI->connect(
	    'dbi:SQLite:dbname=:memory:',
	    undef, undef,
	    { RaiseError => 1 }
	);

	ok($dbh->$call_func($dbfile, 'backup_from_file'));

	{
	    my ($count) = $dbh->selectrow_array(
	        "SELECT count(foo) FROM online_backup_test WHERE foo=$$"
	    );
	    is($count, 1, "Found our process ID in backed-up table");
	}

	# Add more data then attempt to copy it back to file:
	$dbh->do(
	    'CREATE TABLE online_backup_test2 ( id INTEGER PRIMARY KEY, foo INTEGER )'
	);
	$dbh->do("INSERT INTO online_backup_test2 (foo) VALUES ($$)");

	# backup to file (foo):
	ok($dbh->$call_func($dbfile, 'backup_to_file'));

	$dbh->disconnect;

	# Reconnect to foo db and check data made it over:
	{
	    my $foo = connect_ok( dbfile => 'foo', RaiseError => 1 );

	    my ($count) = $foo->selectrow_array(
	        "SELECT count(foo) FROM online_backup_test2 WHERE foo=$$"
	    );
	    is($count, 1, "Found our process ID in table back on disk");

	    $foo->disconnect;
	}
	$dbh->disconnect;

	unlink $dbfile;
}

foreach my $call_func (@CALL_FUNCS) {
	# Connect to the test db and add some stuff:
	my $foo = connect_ok( dbfile => ':memory:', RaiseError => 1 );
	$foo->do(
	    'CREATE TABLE online_backup_test( id INTEGER PRIMARY KEY, foo INTEGER )'
	);
	$foo->do("INSERT INTO online_backup_test (foo) VALUES ($$)");

	my $dbh = DBI->connect(
	    'dbi:SQLite:dbname=:memory:',
	    undef, undef,
	    { RaiseError => 1 }
	);

	ok($dbh->$call_func($foo, 'backup_from_dbh'));

	{
	    my ($count) = $dbh->selectrow_array(
	        "SELECT count(foo) FROM online_backup_test WHERE foo=$$"
	    );
	    is($count, 1, "Found our process ID in backed-up table");
	}

	# Add more data then attempt to copy it back to file:
	$dbh->do(
	    'CREATE TABLE online_backup_test2 ( id INTEGER PRIMARY KEY, foo INTEGER )'
	);
	$dbh->do("INSERT INTO online_backup_test2 (foo) VALUES ($$)");

	# backup to dbh (foo):
	ok($dbh->$call_func($foo, 'backup_to_dbh'));

	$dbh->disconnect;

	my ($count) = $foo->selectrow_array(
	    "SELECT count(foo) FROM online_backup_test2 WHERE foo=$$"
	);
	is($count, 1, "Found our process ID in table back on disk");

	$foo->disconnect;
}

done_testing;
