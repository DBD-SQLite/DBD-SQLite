#!/usr/bin/perl

# This is a test for correctly handling NULL values.

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
use DBI;
use vars qw($COL_NULLABLE);

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

#
#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
my ($dbh, $table, $def, $cursor, $rv);
while (Testing()) {
    #
    #   Connect to the database
    Test($state or $dbh = DBI->connect('DBI:SQLite:dbname=foo', '', ''))
	or ServerError();

    #
    #   Find a possible new table name
    #
    Test($state or $table = FindNewTable($dbh))
	   or DbiError($dbh->err, $dbh->errstr);

    #
    #   Create a new table; EDIT THIS!
    #
    Test($state or ($def = TableDefinition($table,
				   ["id",   "INTEGER",  4, $COL_NULLABLE],
				   ["name", "CHAR",    64, 0]),
		    $dbh->do($def)))
	   or DbiError($dbh->err, $dbh->errstr);


    #
    #   Test whether or not a field containing a NULL is returned correctly
    #   as undef, or something much more bizarre
    #
    Test($state or $dbh->do("INSERT INTO $table VALUES"
	                    . " ( NULL, 'NULL-valued id' )"))
           or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor = $dbh->prepare("SELECT * FROM $table WHERE id IS NULL"))
           or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
           or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($rv = $cursor->fetchrow_arrayref))
	or DbiError($dbh->err, $dbh->errstr);

    Test($state or (!defined($$rv[0])  and  defined($$rv[1])))
	or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->finish)
           or DbiError($dbh->err, $dbh->errstr);

    Test($state or undef $cursor  ||  1);


    #
    #   Finally drop the test table.
    #
    Test($state or $dbh->do("DROP TABLE $table"))
	   or DbiError($dbh->err, $dbh->errstr);

}
