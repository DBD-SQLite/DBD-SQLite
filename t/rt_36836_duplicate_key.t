#!/usr/bin/perl

# This is a simple insert/fetch test.

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

#
#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
my ($dbh, $def, $table, $cursor);
while (Testing()) {

    #
    #   Connect to the database
    Test($state or $dbh = DBI->connect('DBI:SQLite:dbname=foo', '', ''),
	 'connect')
	or ServerError();

    #
    #   Find a possible new table name
    #
    Test($state or $table = FindNewTable($dbh), 'FindNewTable')
	or DbiError($dbh->err, $dbh->errstr);

    #
    #   Create a new table; EDIT THIS!
    #
    Test($state or ($def = TableDefinition($table,
                                           # CREATE TABLE nums (num INTEGER UNIQUE);
					   ["num",   "INTEGER",  4, 0],
					   ) and
		    $dbh->do($def)), 'create', $def)
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or ($dbh->do("CREATE UNIQUE INDEX idx_${table}_num ON $table (num)")))
	or DbiError($dbh->err, $dbh->errstr);


    #
    #   Insert a row into the test table.......
    #
    Test($state or $dbh->do("INSERT INTO $table (num)"
			    . " VALUES(1)" ), 'insert')
	or DbiError($dbh->err, $dbh->errstr);

    #
    #   Now try to insert a duplicate
    #
    Test($state or !$dbh->do("INSERT INTO $table (num)"
			    . " VALUES(1)" ), 'insert')
	;

    #
    #   Finally drop the test table.
    #
    Test($state or $dbh->do("DROP TABLE $table"), 'drop')
	or DbiError($dbh->err, $dbh->errstr);

}
