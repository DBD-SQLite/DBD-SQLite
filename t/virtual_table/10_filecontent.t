use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok $sqlite_call/;
use Test::More;
use if -d ".git", "Test::FailWarnings";
use FindBin;

plan skip_all => "\$FindBin::Bin points to a nonexistent path for some reason: $FindBin::Bin" if !-d $FindBin::Bin;

my $dbh = connect_ok( RaiseError => 1, PrintError => 0, AutoCommit => 1 );

# create index table
$dbh->do(<<"");
  CREATE TABLE base (id INTEGER PRIMARY KEY, foo TEXT, path TEXT, bar TEXT)

$dbh->do(<<"");
  INSERT INTO base VALUES(1, 'foo1', '00_base.t', 'bar1')

$dbh->do(<<"");
  INSERT INTO base VALUES(2, 'foo2', '10_filecontent.t', 'bar2')

# start tests

ok $dbh->$sqlite_call(create_module => fs => "DBD::SQLite::VirtualTable::FileContent"),
   "create_module";

ok $dbh->do(<<""), "create vtable";
  CREATE VIRTUAL TABLE vfs USING fs(source = base,
                                    expose = "path, foo, bar",
                                    root   = "$FindBin::Bin")

my $sql  = "SELECT content, bar, rowid FROM vfs WHERE foo='foo2'";
my $rows = $dbh->selectall_arrayref($sql, {Slice => {}});

is scalar(@$rows), 1, "got 1 row";

is $rows->[0]{bar},   'bar2', 'got bar2';
is $rows->[0]{rowid}, 2,      'got rowid';

like $rows->[0]{content}, qr/VIRTUAL TABLE vfs/, 'file content';

$sql  = "SELECT * FROM vfs ORDER BY rowid";
$rows = $dbh->selectall_arrayref($sql, {Slice => {}});
is scalar(@$rows), 2, "got 2 rows";
is_deeply([sort keys %{$rows->[0]}], [qw/bar content foo path/], "col list OK");
is $rows->[0]{bar},   'bar1', 'got bar1';
is $rows->[1]{bar},   'bar2', 'got bar2';

# expensive  request (reads content from  all files in table) !
$sql  = "SELECT * FROM vfs WHERE content LIKE '%filesys%'";
$rows = $dbh->selectall_arrayref($sql, {Slice => {}});
is scalar(@$rows), 1, "got 1 row";

done_testing;
