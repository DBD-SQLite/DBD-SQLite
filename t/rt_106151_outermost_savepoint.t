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
	$dbh->do("SAVEPOINT svp_0");
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->do("RELEASE svp_0");
	# should not spit the "Issuing rollback()" warning
}

{ # nested
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->do("SAVEPOINT svp_0");
	$dbh->do("SAVEPOINT svp_1");
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->do("RELEASE svp_1");
	$dbh->do("RELEASE svp_0");
	# should not spit the "Issuing rollback()" warning
}

{ # end with commit
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->do("SAVEPOINT svp_0");
	$dbh->do("SAVEPOINT svp_1");
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->do("COMMIT");
	# should not spit the "Issuing rollback()" warning
}

{ # end with rollback
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->do("SAVEPOINT svp_0");
	$dbh->do("SAVEPOINT svp_1");
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->do("ROLLBACK");
	# should not spit the "Issuing rollback()" warning
}

{ # end with outermost release
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->do("SAVEPOINT svp_0");
	$dbh->do("SAVEPOINT svp_1");
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->do("RELEASE svp_0");
	# should not spit the "Issuing rollback()" warning
}

{ # end by setting AutoCommit to true
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->do("SAVEPOINT svp_0");
	$dbh->do("SAVEPOINT svp_1");
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->{AutoCommit} = 1;
	# should not spit the "Issuing rollback()" warning
}

# prepare/execute

{ # simple case
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->prepare("SAVEPOINT svp_0")->execute;
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->prepare("RELEASE svp_0")->execute;
	# should not spit the "Issuing rollback()" warning
}

{ # nested
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->prepare("SAVEPOINT svp_0")->execute;
	$dbh->prepare("SAVEPOINT svp_1")->execute;
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->prepare("RELEASE svp_1")->execute;
	$dbh->prepare("RELEASE svp_0")->execute;
	# should not spit the "Issuing rollback()" warning
}

{ # end with commit
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->prepare("SAVEPOINT svp_0")->execute;
	$dbh->prepare("SAVEPOINT svp_1")->execute;
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->prepare("COMMIT")->execute;
	# should not spit the "Issuing rollback()" warning
}

{ # end with rollback
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->prepare("SAVEPOINT svp_0")->execute;
	$dbh->prepare("SAVEPOINT svp_1")->execute;
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->prepare("ROLLBACK")->execute;
	# should not spit the "Issuing rollback()" warning
}

{ # end with outermost release
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->prepare("SAVEPOINT svp_0")->execute;
	$dbh->prepare("SAVEPOINT svp_1")->execute;
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->prepare("RELEASE svp_0")->execute;
	# should not spit the "Issuing rollback()" warning
}

{ # end by setting AutoCommit to true
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->prepare("SAVEPOINT svp_0")->execute;
	$dbh->prepare("SAVEPOINT svp_1")->execute;
	$dbh->selectall_arrayref("SELECT * FROM sqlite_master");
	$dbh->{AutoCommit} = 1;
	# should not spit the "Issuing rollback()" warning
}

done_testing;
