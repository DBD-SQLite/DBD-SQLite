#!/usr/bin/perl

# Trigger locking error and test prepared statement is still valid afterwards

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok dbfile @CALL_FUNCS/;
use Test::More;
use Test::NoWarnings;

plan tests => 10 * @CALL_FUNCS + 1;

foreach my $call_func (@CALL_FUNCS) {

	my $dbh = connect_ok(
	    dbfile     => 'foo',
	    RaiseError => 1,
	    PrintError => 0,
	    AutoCommit => 0,
	);

	my $dbh2 = connect_ok(
	    dbfile     => 'foo',
	    RaiseError => 1,
	    PrintError => 0,
	    AutoCommit => 0,
	);

	my $dbfile = dbfile('foo');

	# NOTE: Let's make it clear what we're doing here.
	# $dbh starts locking with the first INSERT statement.
	# $dbh2 tries to INSERT, but as the database is locked,
	# it starts waiting. However, $dbh won't release the lock.
	# Eventually $dbh2 gets timed out, and spits an error, saying
	# the database is locked. So, we don't need to let $dbh2 wait
	# too much here. It should be timed out anyway.
	ok($dbh->$call_func(300, 'busy_timeout'));
	ok($dbh2->$call_func(300, 'busy_timeout'));

	$dbh->do("CREATE TABLE Blah ( id INTEGER )");
	$dbh->do("INSERT INTO Blah VALUES ( 1 )");
	$dbh->commit;
	my $sth;
	ok($sth = $dbh->prepare("SELECT id FROM Blah"));
	$sth->execute;
	{
	    my $row;
	    ok($row = $sth->fetch);
	    ok($row && $row->[0] == 1);
	}
	$sth->finish;
	$dbh->commit;
	$dbh2->do("BEGIN EXCLUSIVE");
	eval {
	    $sth->execute;
	};
	ok($@);
	if ($@) {
	    print "# expected execute failure : $@";
	    $sth->finish;
	    $dbh->rollback;
	}
	$dbh2->commit;
	$sth->execute;
	{
	    my $row;
	    ok($row = $sth->fetch);
	    ok($row && $row->[0] == 1);
	}
	$sth->finish;
	$dbh->commit;

	$dbh2->disconnect;
	undef($dbh2);
	$dbh->disconnect;
	undef($dbh);

	unlink $dbfile;
}
