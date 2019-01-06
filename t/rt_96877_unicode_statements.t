# According to the sqlite doc, the SQL argument to sqlite3_prepare_v2
# should be in utf8, but DBD::SQLite does not ensure this (even with
# sqlite_unicode => 1). Only bind values are properly converted.

use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use Test::FailWarnings;

BEGIN { requires_unicode_support() }

my $dbh = connect_ok( sqlite_unicode => 1 );
is( $dbh->{sqlite_unicode}, 1, 'Unicode is on' );

ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE' );
CREATE TABLE foo (
	bar varchar(255)
)
END_SQL

foreach ( "A", "\xe9", "\x{20ac}" ) {
	note sprintf "testing \\x{%x}", ord($_);
	ok( $dbh->do("INSERT INTO foo VALUES ( ? )", {}, $_), 'INSERT with bind' );
	ok( $dbh->do("INSERT INTO foo VALUES ( '$_' )"),      'INSERT without bind' );
	my $vals = $dbh->selectcol_arrayref("SELECT bar FROM foo");
        is $vals->[0], $vals->[1], "both values are equal";

	ok( $dbh->do("DELETE FROM foo"), 'DELETE ok' );
}

done_testing;
