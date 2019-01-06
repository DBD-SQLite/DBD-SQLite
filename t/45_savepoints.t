use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

BEGIN { requires_sqlite('3.6.8') }

my $dbh = connect_ok(
	AutoCommit => 1,
	RaiseError => 1,
);

$dbh->begin_work;

$dbh->do("CREATE TABLE MST (id, lbl)");

$dbh->do("SAVEPOINT svp_0");

$dbh->do("INSERT INTO MST VALUES(1, 'ITEM1')");
$dbh->do("INSERT INTO MST VALUES(2, 'ITEM2')");
$dbh->do("INSERT INTO MST VALUES(3, 'ITEM3')");

my $ac = $dbh->{AutoCommit};

ok((not $ac), 'AC != 1 inside txn');

{
	local $dbh->{AutoCommit} = $dbh->{AutoCommit};

	$dbh->do("ROLLBACK TRANSACTION TO SAVEPOINT svp_0");

	is $dbh->{AutoCommit}, $ac,
		"rolling back savepoint doesn't alter AC";
}

is $dbh->selectrow_array("SELECT COUNT(*) FROM MST"), 0,
	"savepoint rolled back";

$dbh->rollback;

done_testing;
