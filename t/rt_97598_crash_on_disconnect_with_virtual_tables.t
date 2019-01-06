use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

BEGIN { requires_sqlite('3.7.7') }
BEGIN { plan skip_all => 'FTS is disabled for this DBD::SQLite' unless has_fts() }

my $dbh = connect_ok(AutoCommit => 0);

$dbh->do($_) for (
  'CREATE VIRTUAL TABLE test_fts USING fts4 (
     col1,
     col2,
  )',
  'INSERT INTO test_fts (col1, col2) VALUES ("abc", "123")',
  'INSERT INTO test_fts (col1, col2) VALUES ("def", "456")',
  'INSERT INTO test_fts (col1, col2) VALUES ("abc", "123")',
  'INSERT INTO test_fts (col1, col2) VALUES ("def", "456")',
  'INSERT INTO test_fts (col1, col2) VALUES ("abc", "123")',
);

my $sth = $dbh->prepare('SELECT * FROM test_fts WHERE col2 MATCh "123"');
$sth->execute;

while ( my @row = $sth->fetchrow_array ) {
   note join " ", @row;
}
#$sth->finish;

$dbh->commit;
$dbh->disconnect;

pass "all done without segfault";

done_testing;
