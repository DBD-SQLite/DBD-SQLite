#!/usr/bin/perl
use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}


use t::lib::Test qw/connect_ok/;
use Test::More;
use Test::NoWarnings;

# sample data
our $perl_rows = [
  [1, 2, 'three'],
  [4, undef, 'six'  ],
  [7, 8, undef ],
];

# tests for security holes. All of these fail when compiling the regex
my @interpolation_attempts = (
  '@[{die -1}]',
  '$foobar',
  '$self->{row_ix}',
  '(?{die 999})',
  '(?[die 999])',
 );

# unfortunately the examples below don't fail, but I don't know how to
# prevent variable interpolation (that we don't want) while keeping
# character interpolation like \n, \t, etc. (that we do want)
  # '@main::ARGV',
  # '$0',
  # '$self',

plan tests => 25 + @interpolation_attempts;

my $dbh = connect_ok( RaiseError => 1, AutoCommit => 1 );

# create a regular table so that we can compare results with the virtual table
$dbh->do("CREATE TABLE rtb(a INT, b INT, c TEXT)");
my $sth = $dbh->prepare("INSERT INTO rtb(a, b, c) VALUES (?, ?, ?)");
$sth->execute(@$_) foreach @$perl_rows;

# create the virtual table
ok $dbh->sqlite_create_module(perl => "DBD::SQLite::VirtualTable::PerlData"),
   "create_module";
ok $dbh->do(<<""), "create vtable";
  CREATE VIRTUAL TABLE vtb USING perl(a INT, b INT, c TEXT,
                                      arrayrefs="main::perl_rows")

# run same tests on both the regular and the virtual table
test_table($dbh, 'rtb');
test_table($dbh, 'vtb', 1);



sub test_table {
  my ($dbh, $table, $should_test_match) = @_;

  my $sql = "SELECT rowid, * FROM $table";
  my $res = $dbh->selectall_arrayref($sql, {Slice => {}});
  is scalar(@$res), 3, "$sql: got 3 rows";
  is $res->[0]{a}, 1, 'got 1 in a';
  is $res->[0]{b}, 2, 'got undef in b';

  $sql  = "SELECT a FROM $table WHERE b < 8 ORDER BY a";
  $res = $dbh->selectcol_arrayref($sql);
  is scalar(@$res), 1, "$sql: got 1 row";
  is_deeply $res, [1], "got 1 in a";

  $sql = "SELECT rowid FROM $table WHERE c = 'six'";
  $res = $dbh->selectall_arrayref($sql, {Slice => {}});
  is_deeply $res, [{rowid => 2}], $sql;

  $sql = "SELECT a FROM $table WHERE b IS NULL ORDER BY a";
  $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [4], $sql;

  $sql = "SELECT a FROM $table WHERE b IS NOT NULL ORDER BY a";
  $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [1, 7], $sql;

  $sql = "SELECT a FROM $table WHERE c IS NULL ORDER BY a";
  $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [7], $sql;

  $sql = "SELECT a FROM $table WHERE c IS NOT NULL ORDER BY a";
  $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [1, 4], $sql;

  if ($should_test_match) {
    $sql = "SELECT c FROM $table WHERE c MATCH '^.i' ORDER BY c";
    $res = $dbh->selectcol_arrayref($sql);
    is_deeply $res, [qw/six/], $sql;

    $sql = "SELECT c FROM $table WHERE c MATCH ? ORDER BY c";
    ok !eval{$dbh->selectcol_arrayref($sql, {}, $_); 1}, $_ # "$_ : $@"
      foreach @interpolation_attempts;
  }
}
