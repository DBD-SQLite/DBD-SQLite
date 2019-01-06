# I've disabled warnings, so theoretically warnings shouldn't be printed

use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

SCOPE: {
	my $dbh = connect_ok( RaiseError => 1, PrintWarn => 0, Warn => 0 );
	ok( ! $dbh->{PrintWarn}, '->{PrintWarn} is false' );
	ok( $dbh->do("CREATE TABLE f (f1, f2, f3)"), 'CREATE TABLE ok' );
	ok( $dbh->begin_work, '->begin_work' );
	ok(
		$dbh->do("INSERT INTO f VALUES (?, ?, ?)", {}, 'foo', 'bar', 1),
		'INSERT ok',
	);
}

done_testing;
