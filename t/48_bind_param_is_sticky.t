#!/usr/bin/perl

# Check data type assignment in bind_param is sticky

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use DBI qw(:sql_types);
use Test::More;
use Test::NoWarnings;

plan tests => 10 + 1;

my $dbh = connect_ok(
    RaiseError => 1,
    PrintError => 0,
    AutoCommit => 0,
);
$dbh->do("CREATE TABLE Blah ( id INTEGER, val BLOB )");
$dbh->commit;
my $sth;
ok($sth = $dbh->prepare("INSERT INTO Blah VALUES (?, ?)"), "prepare");
$sth->bind_param(1, 1);
$sth->bind_param(2, 'foo', SQL_BLOB);
$sth->execute;
$sth->execute(2, 'bar');
sub verify_types() {
    my $rows = $dbh->selectall_arrayref("SELECT typeof(val) FROM Blah ORDER BY id");
    ok($rows, "selectall_arrayref returned data");
    ok(@{$rows} == 2, "... with expected number of rows");
    ok($rows->[0]->[0] eq 'blob', "$rows->[0]->[0] eq blob");
    ok($rows->[1]->[0] eq 'blob', "$rows->[1]->[0] eq blob");
}
verify_types();
$dbh->commit;
$dbh->do("DELETE FROM Blah");
$sth->bind_param_array(1, [1, 2]);
$sth->bind_param_array(2, [qw/FOO BAR/], SQL_BLOB);
$sth->execute_array({});
verify_types();
$dbh->commit;

$dbh->disconnect;
undef($dbh);
