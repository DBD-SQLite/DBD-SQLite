use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok/;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok(sqlite_see_if_its_a_number => 1);
$dbh->do('create table foo (id integer primary key, exp)');
my $ct = 0;
for my $value (qw/2e1000 10.04e1000/) {
    eval {
        $dbh->do('insert into foo values (?, ?)', undef, $ct++, $value);
        my $got = $dbh->selectrow_arrayref('select * from foo where exp = ?', undef, $value);
        is $value => $got->[1], "got ".$got->[0];
    };
    ok !$@, "and without errors";
}

done_testing;
