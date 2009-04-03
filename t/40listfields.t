#!/usr/bin/perl

# This is a test for statement attributes being present appropriately.

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;

use vars qw($state $COL_KEY $COL_NULLABLE);

$COL_KEY = '';


#
#   Include lib.pl
#
do 't/lib.pl';
if ($@) {
	print STDERR "Error while executing lib.pl: $@\n";
	exit 10;
}


my @table_def = (
	      ["id",   "INTEGER",  4, $COL_KEY],
	      ["name", "CHAR",    64, $COL_NULLABLE]
	     );

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
my ($dbh, $table, $def, $cursor, $ref);
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
    #   Create a new table
    #
    Test($state or ($def = TableDefinition($table, @table_def),
		    $dbh->do($def)))
	   or DbiError($dbh->err, $dbh->errstr);


    Test($state or $cursor = $dbh->prepare("SELECT * FROM $table"))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
	   or DbiError($cursor->err, $cursor->errstr);

    my $res;
    Test($state or (($res = $cursor->{'NUM_OF_FIELDS'}) == @table_def))
	   or DbiError($cursor->err, $cursor->errstr);

    Test($state or ($ref = $cursor->{'NAME'})  &&  @$ref == @table_def
	            &&  (lc $$ref[0]) eq $table_def[0][0]
		    &&  (lc $$ref[1]) eq $table_def[1][0])
	   or DbiError($cursor->err, $cursor->errstr);

    Test($state or undef $cursor  ||  1);


    #
    #  Drop the test table
    #
    Test($state or ($cursor = $dbh->prepare("DROP TABLE $table")))
	or DbiError($dbh->err, $dbh->errstr);
    Test($state or $cursor->execute)
	or DbiError($cursor->err, $cursor->errstr);

    #  NUM_OF_FIELDS should be zero (Non-Select)
    Test($state or ($cursor->{'NUM_OF_FIELDS'} == 0));
    Test($state or (undef $cursor) or 1);
}
