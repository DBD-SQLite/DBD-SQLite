use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

BEGIN {
	eval {require APR::Table; 1};
	if ($@) {
		plan skip_all => 'requires APR::Table';
	}
}

my $dbh = connect_ok(
	AutoCommit => 1,
	RaiseError => 1,
);

eval { $dbh->do('SELECT 1') };
ok !$@, "no errors";
diag $@ if $@;

done_testing;
