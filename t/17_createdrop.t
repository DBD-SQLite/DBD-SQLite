# This is a skeleton test. For writing new tests, take this file
# and modify/extend it.

use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

# Create a database
my $dbh = connect_ok();

# Create a table
ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE' );
CREATE TABLE one (
    id INTEGER NOT NULL,
    name CHAR (64) NOT NULL
)
END_SQL

# Drop the table
ok( $dbh->do('DROP TABLE one'), 'DROP TABLE' );

done_testing;
