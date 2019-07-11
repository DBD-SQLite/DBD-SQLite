use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok @CALL_FUNCS/;
use Test::More;
use if -d ".git", "Test::FailWarnings";

for my $func (@CALL_FUNCS) {
	my $dbh = connect_ok(PrintError => 0, RaiseError => 1);
    $dbh->do('create table foo (id)');

    note 'begin_work does not make autocommit false';
    my $autocommit = $dbh->$func('get_autocommit');
    ok $autocommit, "internal autocommit is true";
    ok $dbh->{AutoCommit}, "AutoCommit is also true";

    $dbh->begin_work;
    $autocommit = $dbh->$func('get_autocommit');
    ok $autocommit, "internal autocommit is still true";
    ok !$dbh->{AutoCommit}, "AutoCommit gets false";

    $dbh->do('insert into foo values (1)');
    $dbh->commit;

    $autocommit = $dbh->$func('get_autocommit');
    ok $autocommit, "internal autocommit is still true";
    ok $dbh->{AutoCommit}, "AutoCommit is true now";

    note 'nor turning AutoCommit off does not make autocommit false';
    $dbh->{AutoCommit} = 0;
    $autocommit = $dbh->$func('get_autocommit');
    ok $autocommit, "internal autocommit is still true";
    ok !$dbh->{AutoCommit}, "AutoCommit is false";

    $dbh->do('insert into foo values (1)');
    $dbh->commit;
    $dbh->{AutoCommit} = 1;

    $autocommit = $dbh->$func('get_autocommit');
    ok $autocommit, "internal autocommit is still true";
    ok $dbh->{AutoCommit}, "AutoCommit is true now";

    note 'explicit BEGIN make autocommit false';
    $dbh->do('BEGIN');
    $autocommit = $dbh->$func('get_autocommit');
    ok !$autocommit, "internal autocommit gets false";
    ok !$dbh->{AutoCommit}, "AutoCommit is also false";

    $dbh->do('insert into foo values (1)');
    $dbh->commit;

    $autocommit = $dbh->$func('get_autocommit');
    ok $autocommit, "internal autocommit is true now";
    ok $dbh->{AutoCommit}, "AutoCommit is true now";
}

done_testing;
