use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use Test::FailWarnings;

BEGIN { requires_unicode_support(); }

my $dbh = connect_ok( sqlite_unicode => 1 );
is( $dbh->{sqlite_unicode}, 1, 'Unicode is on' );

ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE' );
CREATE TABLE foo (
	bar varchar(255)
)
END_SQL

foreach ( "\0", "A", "\xe9", "\x{20ac}" ) {
	ok( $dbh->do("INSERT INTO foo VALUES ( ? )", {}, $_), 'INSERT' );
	my $foo = $dbh->selectall_arrayref("SELECT bar FROM foo");
	is_deeply( $foo, [ [ $_ ] ], 'Value round-tripped ok' );
	my $len = $dbh->selectall_arrayref("SELECT length(bar) FROM foo");
	is $len->[0][0], 1 unless $_ eq "\0";
	my $match = $dbh->selectall_arrayref("SELECT bar FROM foo WHERE bar = ?", {}, $_);
	is $match->[0][0], $_;
	ok( $dbh->do("DELETE FROM foo"), 'DELETE ok' );
}

done_testing;
