use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok @CALL_FUNCS/;
use Test::More;
use if -d ".git", "Test::FailWarnings";
use DBD::SQLite::Constants ':allowed_return_values_from_sqlite3_txn_state';

note "test main schema";
test('main');
note "test undef schema";
test(undef);
note "omit schema";
test();
done_testing;

sub test {
    my @schema = @_;
    die if @schema > 1;

    for my $func (@CALL_FUNCS) {
        my $dbh = connect_ok(PrintError => 0, RaiseError => 1);
        $dbh->do('create table foo (id)');

        my $txn_state = $dbh->$func(@schema, 'txn_state');
        is $txn_state => SQLITE_TXN_NONE, "internal transaction is none";

        $dbh->do('BEGIN');

        my $row = $dbh->selectrow_arrayref('SELECT * FROM foo');

        $txn_state = $dbh->$func(@schema, 'txn_state');
        is $txn_state => SQLITE_TXN_READ, "internal transaction is read";

        $dbh->do('insert into foo values (1)');
        $txn_state = $dbh->$func(@schema, 'txn_state');
        is $txn_state => SQLITE_TXN_WRITE, "internal transaction is write";

        $dbh->commit;
    }
}
