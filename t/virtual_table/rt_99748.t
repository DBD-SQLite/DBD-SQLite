#!/usr/bin/perl
use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok $sqlite_call/;
use Test::More;
use Test::NoWarnings;

# sample data
our $perl_rows = [
  [1, 2, 'three'],
  [4, undef, 'six'  ],
  [7, 8, undef ],
  [10, undef, '}'],
  [11, undef,  '\}'],
  [12, undef,  "data\nhas\tspaces"],
];

# tests for security holes. All of these fail when compiling the regex
my @interpolation_attempts = (
  '@[{die -1}]',
  '(?{die 999})',
 );

#if ($] > 5.008008) {
  # don't really know why, but the tests below (interpolating variables
  # within regexes) cause segfaults under Perl <= 5.8.8, during the END
  # phase -- probably something to do with closure destruction.
  push @interpolation_attempts, '$foobar',
                                '$self->{row_ix}',
                                '$main::ARGV[ die 999 ]',
                                ;
#}

# unfortunately the examples below don't fail, but I don't know how to
# prevent variable interpolation (that we don't want) while keeping
# character interpolation like \n, \t, etc. (that we do want)
  # '@main::ARGV',
  # '$0',
  # '$self',

plan tests => 4 + 2 * 15 + @interpolation_attempts + 8;

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

  $sql = "SELECT a FROM $table WHERE c IS ?";
  $res = $dbh->selectcol_arrayref($sql, {}, undef);
  is_deeply $res, [7], $sql;
}

sub test_match_operator {
  my ($dbh, $table) = @_;

#  my $sql = "SELECT c FROM $table WHERE c MATCH '^.i' ORDER BY c";
  my $sql = "SELECT c FROM $table WHERE c MATCH 'i' ORDER BY c";
  my $res = $dbh->selectcol_arrayref($sql);
  is_deeply $res, [qw/six/], $sql;

  $sql = "SELECT c FROM $table WHERE c MATCH ? ORDER BY c";
  is_deeply $dbh->selectcol_arrayref($sql, {}, $_) => [], $_
    foreach @interpolation_attempts;

  $sql = "SELECT a FROM $table WHERE c MATCH ?";
  $res = $dbh->selectcol_arrayref($sql, {}, '}');
  is_deeply $res, [10, 11], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, '\}');
  is_deeply $res, [11], $sql;

  $res = $dbh->selectcol_arrayref($sql, {}, '\\');
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
