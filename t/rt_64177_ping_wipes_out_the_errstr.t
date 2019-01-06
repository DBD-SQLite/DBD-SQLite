use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
eval { $dbh->do('foobar') };
ok $@, "raised error";
ok $dbh->err, "has err";
ok $dbh->errstr, "has errstr";
ok $dbh->ping, "ping succeeded";
ok $dbh->err, "err is not wiped out";
ok $dbh->errstr, "errstr is not wiped out";

done_testing;
