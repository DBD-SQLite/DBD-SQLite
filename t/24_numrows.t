#!/usr/bin/perl

# This tests, whether the number of rows can be retrieved.

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;

use vars qw($state);

#
#   Include lib.pl
#
do 't/lib.pl';
if ($@) {
	print STDERR "Error while executing lib.pl: $@\n";
	exit 10;
}

sub ServerError() {
    print STDERR ("Cannot connect: ", $DBI::errstr, "\n",
	"\tEither your server is not up and running or you have no\n",
	"\tpermissions for acessing the DSN 'DBI:SQLite:dbname=foo'.\n",
	"\tThis test requires a running server and write permissions.\n",
	"\tPlease make sure your server is running and you have\n",
	"\tpermissions, then retry.\n");
    exit 10;
}


sub TrueRows($) {
    my ($sth) = @_;
    my $count = 0;
    while ($sth->fetchrow_arrayref) {
	++$count;
    }
    $count;
}


#
#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
my ($dbh, $table, $def, $cursor, $numrows);
while (Testing()) {
    #
    #   Connect to the database
    Test($state or ($dbh = DBI->connect('DBI:SQLite:dbname=foo', '',
					'')))
	or ServerError();

    #
    #   Find a possible new table name
    #
    Test($state or ($table = FindNewTable($dbh)))
	   or DbiError($dbh->err, $dbh->errstr);

    #
    #   Create a new table; EDIT THIS!
    #
    Test($state or ($def = TableDefinition($table,
					   ["id",   "INTEGER",  4, 0],
					   ["name", "CHAR",    64, 0]),
		    $dbh->do($def)))
	   or DbiError($dbh->err, $dbh->errstr);


    #
    #   This section should exercise the sth->rows
    #   method by preparing a statement, then finding the
    #   number of rows within it.
    #   Prior to execution, this should fail. After execution, the
    #   number of rows affected by the statement will be returned.
    #
    Test($state or $dbh->do("INSERT INTO $table"
			    . " VALUES( 1, 'Alligator Descartes' )"))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($cursor = $dbh->prepare("SELECT * FROM $table"
					   . " WHERE id = 1")))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
           or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($numrows = TrueRows($cursor)) == 1)
        	or ErrMsgF("Expected to fetch 1 rows, got %s.\n", $numrows);

    Test($state or $cursor->finish)
           or DbiError($dbh->err, $dbh->errstr);

    Test($state or undef $cursor or 1);

    Test($state or $dbh->do("INSERT INTO $table"
			    . " VALUES( 2, 'Jochen Wiedmann' )"))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($cursor = $dbh->prepare("SELECT * FROM $table"
					    . " WHERE id >= 1")))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($numrows = TrueRows($cursor)) == 2)
        	or ErrMsgF("Expected to fetch 2 rows, got %s.\n", $numrows);

    Test($state or $cursor->finish)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or undef $cursor or 1);

    Test($state or $dbh->do("INSERT INTO $table"
			    . " VALUES(3, 'Tim Bunce')"))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($cursor = $dbh->prepare("SELECT * FROM $table"
					    . " WHERE id >= 2")))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($numrows = TrueRows($cursor)) == 2)
	       or ErrMsgF("Expected to fetch 2 rows, got %s.\n", $numrows);

    Test($state or $cursor->finish)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or undef $cursor or 1);

    #
    #   Finally drop the test table.
    #
    Test($state or $dbh->do("DROP TABLE $table"))
	   or DbiError($dbh->err, $dbh->errstr);

}

