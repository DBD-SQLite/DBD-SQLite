use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok( RaiseError => 1 );
$dbh->do("CREATE TABLE f (f1, f2, f3)");
$dbh->do("INSERT INTO f VALUES (?, ?, ?)", {}, 'foo', 'bar', 1);

SCOPE: {
	my $sth = $dbh->prepare('SELECT f1 as "a.a", * FROM f', {});
	isa_ok( $sth, 'DBI::st' );
	ok( $sth->execute, '->execute ok' );
	my $row = $sth->fetchrow_hashref;
	is_deeply( $row, {
		'a.a' => 'foo',
		'f1'  => 'foo',
		'f2'  => 'bar',
		'f3'  => 1,
	}, 'Shortname row ok' );
}

$dbh->do("PRAGMA full_column_names = 1");
$dbh->do("PRAGMA short_column_names = 0");

SCOPE: {
	my $sth = $dbh->prepare('SELECT f1 as "a.a", * FROM f', {});
	isa_ok( $sth, 'DBI::st' );
	ok( $sth->execute, '->execute ok' );
	my $row = $sth->fetchrow_hashref;
	is_deeply( $row, {
		'a.a' => 'foo',
		'f.f1'  => 'foo',
		'f.f2'  => 'bar',
		'f.f3'  => 1,
	}, 'Shortname row ok' );
}

done_testing;
