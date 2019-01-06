use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok $sqlite_call requires_sqlite has_sqlite/;
use Test::More;

BEGIN { requires_sqlite('3.7.4') }

use if -d ".git", "Test::FailWarnings";
use FindBin;

our $perl_rows = [
  [1, 2, 'three'],
  [4, 5, 'six'  ],
  [7, 8, 'nine' ],
];

my $dbh = connect_ok( RaiseError => 1, AutoCommit => 1 );

ok $dbh->$sqlite_call(create_module =>
                        perl => "DBD::SQLite::VirtualTable::PerlData"),
   "create_module";

#======================================================================
# test the arrayrefs implementation
#======================================================================

ok $dbh->do(<<""), "create vtable";
  CREATE VIRTUAL TABLE vtb USING perl(a INT, b INT, c TEXT,
                                      arrayrefs="main::perl_rows")

my $sql = "SELECT * FROM vtb";
my $res = $dbh->selectall_arrayref($sql, {Slice => {}});
is scalar(@$res), 3, "got 3 rows";
is $res->[0]{a}, 1, 'got 1 in a';
is $res->[0]{b}, 2, 'got 2 in b';

$sql  = "SELECT * FROM vtb WHERE b < 8 ORDER BY a DESC";
$res = $dbh->selectall_arrayref($sql, {Slice => {}});
is scalar(@$res), 2, "got 2 rows";
is $res->[0]{a}, 4, 'got 4 in first a';
is $res->[1]{a}, 1, 'got 1 in second a';

$sql = "SELECT rowid FROM vtb WHERE c = 'six'";
$res = $dbh->selectall_arrayref($sql, {Slice => {}});
is_deeply $res, [{rowid => 2}], $sql;

#$sql = "SELECT c FROM vtb WHERE c MATCH '^.i' ORDER BY c";
$sql = "SELECT c FROM vtb WHERE c MATCH 'i' ORDER BY c";
$res = $dbh->selectcol_arrayref($sql);
is_deeply $res, [qw/nine six/], $sql;

$dbh->do("INSERT INTO vtb(a, b, c) VALUES (11, 22, 33)");
my $row_id = $dbh->last_insert_id('', '', '', '');
is $row_id, 3,                            'new rowid is 3';
is scalar(@$perl_rows), 4,                'perl_rows expanded';
is_deeply $perl_rows->[-1], [11, 22, 33], 'new row is correct';

#======================================================================
# test the hashref implementation
#======================================================================
our $perl_hrows = [ map {my %row; @row{qw/a b c/} = @$_; \%row} @$perl_rows];

ok $dbh->do(<<""), "create vtable";
  CREATE VIRTUAL TABLE temp.vtb2 USING perl(a INT, b INT, c TEXT,
                                            hashrefs="main::perl_hrows")

$sql = "SELECT * FROM vtb2 WHERE b < 8 ORDER BY a DESC";
$res = $dbh->selectall_arrayref($sql, {Slice => {}});
is scalar(@$res), 2, "got 2 rows";
is $res->[0]{a}, 4, 'got 4 in first a';
is $res->[1]{a}, 1, 'got 1 in second a';

#======================================================================
# test the colref implementation
#======================================================================

our $integers = [1 .. 10];
ok $dbh->do(<<""), "create vtable intarray";
  CREATE VIRTUAL TABLE intarray USING perl(i INT, colref="main::integers")

$sql = "SELECT i FROM intarray WHERE i BETWEEN 0 AND 5";
$res = $dbh->selectcol_arrayref($sql);
is_deeply $res, [1 .. 5], $sql;

if (has_sqlite('3.7.10')) {
  $sql = "INSERT INTO intarray VALUES (98), (99)";
  ok $dbh->do($sql), $sql;
  is_deeply $integers, [1 .. 10, 98, 99], "added 2 ints";
}

# test below inspired by sqlite "test_intarray.{h,c})
$integers = [ 1, 7 ];
$sql = "SELECT a FROM vtb WHERE a IN intarray";
$res = $dbh->selectcol_arrayref($sql);
is_deeply $res, [ 1, 7 ], "IN intarray";

# same thing with strings
our $strings = [qw/one two three/];
ok $dbh->do(<<""), "create vtable strarray";
  CREATE VIRTUAL TABLE strarray USING perl(str TEXT, colref="main::strings")

if (has_sqlite('3.7.10')) {
  $sql = "INSERT INTO strarray VALUES ('aa'), ('bb')";
  ok $dbh->do($sql), $sql;
  is_deeply $strings, [qw/one two three aa bb/], "added 2 strings";
}

$sql = "SELECT a FROM vtb WHERE c IN strarray";
$res = $dbh->selectcol_arrayref($sql);
is_deeply $res, [ 1 ], "IN strarray";

$sql = "SELECT a FROM vtb WHERE c IN (SELECT str FROM strarray WHERE str > 'a')";
$res = $dbh->selectcol_arrayref($sql);
is_deeply $res, [ 1 ], "IN SELECT FROM strarray";

done_testing;
