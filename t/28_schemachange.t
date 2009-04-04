#!/usr/bin/perl

# This test works, but as far as I can tell this doesn't actually test
# the thing that the test was originally meant to test.

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 5;
use t::lib::Test;

my $create1 = 'CREATE TABLE table1 (id INTEGER NOT NULL, name CHAR (64) NOT NULL)';
my $create2 = 'CREATE TABLE table2 (id INTEGER NOT NULL, name CHAR (64) NOT NULL)';
my $drop1   = 'DROP TABLE table1';
my $drop2   = 'DROP TABLE table2';

# diag("Parent starting... ($$)");

# Create the tables
SCOPE: {
	my $dbh = DBI->connect('dbi:SQLite:dbname=foo', '', '') or die 'connect failed';
	$dbh->do($create1) or die '$create1 failed';
	$dbh->do($create2) or die '$create2 failed';
	$dbh->disconnect   or die 'disconnect failed';
}

my $pid;
# diag("Forking... ($$)");
if ( not defined( $pid = fork() ) ) {
	die("fork: $!");

} elsif ( $pid == 0 ) {
	# Child process
	# diag("Child starting... ($$)");
	my $dbh = connect_ok();
	ok( $dbh->do($drop2), $drop2 );
	ok( $dbh->disconnect, '->disconnect ok' );
	# diag("Child exiting... ($$)");
	exit(0);

} else {
	# Parent process
	# diag("Waiting for child... ($$)");
	ok( waitpid($pid, 0) != -1, "waitpid" );

}

# Make sure the child actually deleted table2
SCOPE: {
	my $dbh = connect_ok();
	ok( $dbh->do($drop1),   $drop1   );
	ok( $dbh->do($create2), $create2 );
	ok( $dbh->disconnect, '->disconnect ok' );
}
