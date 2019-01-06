use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok( RaiseError => 1, PrintError => 0 );

$dbh->do("CREATE TABLE nums (num INTEGER UNIQUE)");

ok $dbh->do("INSERT INTO nums (num) VALUES (?)", undef, 1);

eval { $dbh->do("INSERT INTO nums (num) VALUES (?)", undef, 1); };
ok $@ =~ /column num is not unique|UNIQUE constraint failed/, $@;  # should not be a bus error

done_testing;
