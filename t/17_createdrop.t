#!/usr/bin/perl

# This is a skeleton test. For writing new tests, take this file
# and modify/extend it.

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;

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
#   Main loop; leave this untouched, put tests into the loop
#
use vars qw($state);
while (Testing()) {
    #
    #   Connect to the database
    my $dbh;
    Test($state or $dbh = DBI->connect('DBI:SQLite:dbname=foo', '', ''))
	or ServerError();

    #
    #   Find a possible new table name
    #
    my $table;
    Test($state or $table = 'table1')
	   or DbiError($dbh->err, $dbh->errstr);

    #
    #   Create a new table
    #
    my $def;
    if (!$state) {
	($def = TableDefinition($table,
				["id",   "INTEGER",  4, 0],
				["name", "CHAR",    64, 0]));
	print "Creating table:\n$def\n";
    }
    Test($state or $dbh->do($def))
	or DbiError($dbh->err, $dbh->errstr);


    #
    #   ... and drop it.
    #
    Test($state or $dbh->do("DROP TABLE $table"))
	   or DbiError($dbh->err, $dbh->errstr);

    #
    #   Finally disconnect.
    #
    Test($state or $dbh->disconnect())
	   or DbiError($dbh->err, $dbh->errstr);
}
