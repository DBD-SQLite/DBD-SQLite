use strict;
use warnings;
use Test::More;
use lib "t/lib";
use SQLiteTest;
use DBD::SQLite;
use if -d ".git", "Test::FailWarnings";

BEGIN {
	if (!has_compile_option('ENABLE_COLUMN_METADATA')) {
		plan skip_all => "Column metadata is disabled for this DBD::SQLite";
	}
}

my $dbh = connect_ok();

ok $dbh->do("CREATE TABLE foo (id INTEGER PRIMARY KEY NOT NULL, col1 varchar(2) NOT NULL, col2 varchar(2), col3 char(2) NOT NULL)");
my $sth = $dbh->prepare ('SELECT * FROM foo');
ok $sth->execute;

my $expected = {
    NUM_OF_FIELDS => 4,
    NAME_lc => [qw/id col1 col2 col3/],
    NULLABLE => [qw/0 0 1 0/],
};

for my $m (keys %$expected) {
    is_deeply($sth->{$m}, $expected->{$m});
}

done_testing;
