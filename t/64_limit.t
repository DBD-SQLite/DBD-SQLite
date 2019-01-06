use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok @CALL_FUNCS/;
use Test::More;
use DBD::SQLite::Constants qw/SQLITE_LIMIT_VARIABLE_NUMBER/;
use if -d ".git", "Test::FailWarnings";

for my $func (@CALL_FUNCS) {
	my $dbh = connect_ok(PrintError => 0, RaiseError => 1);
    my $current_limit = $dbh->$func(SQLITE_LIMIT_VARIABLE_NUMBER, 'limit');
    ok $current_limit, "current limit: $current_limit";

    $current_limit = $dbh->$func(SQLITE_LIMIT_VARIABLE_NUMBER, -1, 'limit');
    ok $current_limit, "current limit: $current_limit";

    ok $dbh->do('create table foo (id, text)');
    ok $dbh->do('insert into foo values(?, ?)', undef, 1, 'OK');

    ok $dbh->$func(SQLITE_LIMIT_VARIABLE_NUMBER, 1, 'limit');
    eval { $dbh->do('insert into foo values(?, ?)', undef, 2, 'NOT OK') };
    like $@ => qr/too many SQL variables/, "should raise error because of the variable limit";
}

done_testing;
