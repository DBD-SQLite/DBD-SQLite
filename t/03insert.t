use strict;
use Test::More;
use DBI;
BEGIN { plan tests => 11 }
my $dbh = DBI->connect("dbi:SQLite:dbname=foo", "", "", {AutoCommit => 1});
ok($dbh);
$dbh->do("CREATE TABLE f (f1, f2, f3)");
ok($dbh->do("delete from f"));
my $sth = $dbh->prepare("INSERT INTO f VALUES (?, ?, ?)", { go_last_insert_id_args => [undef, undef, undef, undef] });
ok($sth);
ok(my $rows = $sth->execute("Fred", "Bloggs", "fred\@bloggs.com"));
ok($rows == 1);

is($sth->execute("test", "test", "1"), 1);
is($sth->execute("test", "test", "2"), 1);
is($sth->execute("test", "test", "3"), 1);

SKIP: {
    skip('last_insert_id requires DBI v1.43', 2) if $DBI::VERSION < 1.43;
    is($dbh->last_insert_id(undef, undef, undef, undef), 4 );

    is($dbh->func('last_insert_rowid'), 4, 'last_insert_rowid should be 4');
}

is($dbh->do("delete from f where f1='test'"), 3);
$sth->finish;
undef $sth;
$dbh->disconnect;

END { unlink 'foo' }
