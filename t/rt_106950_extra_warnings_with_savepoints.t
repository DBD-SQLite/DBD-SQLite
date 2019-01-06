use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

BEGIN { requires_sqlite('3.6.8') }

{ # simple case
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->begin_work;
	$dbh->do("SAVEPOINT svp_0");
	$dbh->do("RELEASE SAVEPOINT svp_0");
	$dbh->commit;
	# should not spit the "Issuing rollback()" warning
}

done_testing;
