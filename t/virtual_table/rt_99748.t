use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok $sqlite_call has_sqlite/;
use Test::More;
use if -d ".git", "Test::FailWarnings";

# tests that the MATCH operator does not allow code injection
my @interpolation_attempts = (
  '@{[die -1]}',
  '(foobar',      # will die - incorrect regex
  '(?{die 999})', # will die - Eval-group not allowed at runtime
  '$foobar',
  '$self->{row_ix}',
  '$main::ARGV[ die 999 ]',
  '@main::ARGV',
  '$0',
  '$self',
 );

# sample data
our $perl_rows = [
  [1, 2, 'three'],
  [4, undef, 'six'  ],
  [7, 8, undef ],
  [10, undef, '}'],
  [11, undef,  '\}'],
  [12, undef,  "data\nhas\tspaces"],
];

my $dbh = connect_ok( RaiseError => 1, AutoCommit => 1 );

# create a regular table so that we can compare results with the virtual table
$dbh->do("CREATE TABLE rtb(a INT, b INT, c TEXT)");
my $sth = $dbh->prepare("INSERT INTO rtb(a, b, c) VALUES (?, ?, ?)");
$sth->execute(@$_) foreach @$perl_rows;

# create the virtual table
ok $dbh->$sqlite_call(create_module =>
                        perl => "DBD::SQLite::VirtualTable::PerlData"),
   "create_module";
ok $dbh->do(<<""), "create vtable";
  CREATE VIRTUAL TABLE vtb USING perl(a INT, b INT, c TEXT,
                                      arrayrefs="main::perl_rows")

# run same tests on both the regular and the virtual table
test_table($dbh, 'rtb');
test_table($dbh, 'vtb');

# the match operator only works on the virtual table
test_match_operator($dbh, 'vtb');

sub test_table {
  my ($dbh, $table) = @_;

  my $sql = "SELECT rowid, * FROM $table";
  my $res = $dbh->selectall_arrayref($sql, {Slice => {}});
  is scalar(@$res), scalar(@$perl_rows), "$sql: got 3 rows";
  is $res->[0]{a}, 1, 'got 1 in a';
  is $res->[0]{b}, 2, 'got undef in b';

  $sql  = "SELECT a FROM $table WHERE b < 8 ORDER BY a";
  $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [1], "got 1 in a";

  $sql = "SELECT rowid FROM $table WHERE c = 'six'";
  $res = $dbh->selectall_arrayref($sql, {Slice => {}});
  is_deeply $res, [{rowid => 2}], $sql;

  $sql = "SELECT a FROM $table WHERE b IS NULL ORDER BY a";
  $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [4, 10, 11, 12], $sql;

  $sql = "SELECT a FROM $table WHERE b IS NOT NULL ORDER BY a";
  $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [1, 7], $sql;

  $sql = "SELECT a FROM $table WHERE c IS NULL ORDER BY a";
  $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [7], $sql;

  $sql = "SELECT a FROM $table WHERE c IS NOT NULL ORDER BY a";
  $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [1, 4, 10, 11, 12], $sql;

  $sql = "SELECT a FROM $table WHERE c = ?";
  $res = $dbh->selectcol_arrayref($sql, {}, '}');
  is_deeply $res, [10], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, '\}');
  is_deeply $res, [11], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, '\\');
  is_deeply $res, [], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, '{');
  is_deeply $res, [], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, undef);
  is_deeply $res, [], $sql;

  if (has_sqlite('3.6.19')) {
    $sql = "SELECT a FROM $table WHERE c IS ?";
    $res = $dbh->selectcol_arrayref($sql, {}, undef);
    is_deeply $res, [7], $sql;

    $sql = "SELECT a FROM $table WHERE c IS NOT ? order by a";
    $res = $dbh->selectcol_arrayref($sql, {}, undef);
    is_deeply $res, [1, 4, 10, 11, 12], $sql;
  }
}

sub test_match_operator {
  my ($dbh, $table) = @_;

  my $sql = "SELECT c FROM $table WHERE c MATCH '^.i' ORDER BY c";
  my $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [qw/six/], $sql;

  $sql = "SELECT c FROM $table WHERE c MATCH ? ORDER BY c";
  is_deeply $dbh->selectcol_arrayref($sql, {}, $_) => [], $_
    foreach @interpolation_attempts;

  $sql = "SELECT a FROM $table WHERE c MATCH ?";
  $res = $dbh->selectcol_arrayref($sql, {}, '}');
  is_deeply $res, [10, 11], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, '\}');
  is_deeply $res, [10, 11], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, '\\\\}');
  is_deeply $res, [11], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, '\\\\');
  is_deeply $res, [11], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, "\n");
  is_deeply $res, [12], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, "\t");
  is_deeply $res, [12], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, '{');
  is_deeply $res, [], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, '$x[$y]');
  is_deeply $res, [], $sql;

}

done_testing;
