# This is a simple insert/fetch test.

use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

# Create a database
my $dbh = connect_ok( PrintError => 0 );

# Create a database
ok( $dbh->do('CREATE TABLE one ( num INTEGER UNIQUE)'), 'create table' );

# Insert a row into the test table
ok( $dbh->do('INSERT INTO one ( num ) values ( 1 )'), 'insert' );

# Insert a duplicate
ok( ! $dbh->do('INSERT INTO one ( num ) values ( 1 )'), 'duplicate' );

done_testing;
