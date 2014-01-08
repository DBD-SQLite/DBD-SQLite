#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More;
use Test::NoWarnings;
use DBI qw(:sql_types);

plan tests => 9;

# The following is by mje++
# http://pastebin.com/RkUwwVti

my $test_value = "1234567.20";

sub my_is {
    my ($dbh, $test) = @_;

    my ($x) = $dbh->selectrow_array(q/select b from test where a = ?/, undef, 1);

    is($x, "$test_value", $test);
    $dbh->do(q/delete from test/);
}

my $dbh = connect_ok(sqlite_see_if_its_a_number => 1);

$dbh->do(q/create table test (a integer, b varchar(20))/);

$dbh->do(q/insert into test values(?,?)/, undef, 1, $test_value);
SKIP: {
    local $TODO = 'failing now';
    my_is($dbh, "do insert");
};

my $sth = $dbh->prepare(q/insert into test values(?,?)/);
$sth->bind_param(1, 1, SQL_INTEGER);
$sth->bind_param(2, $test_value, SQL_CHAR);
$sth->execute;
my_is($dbh, "prepared insert with provided bound data and type SQL_CHAR");

$sth = $dbh->prepare(q/insert into test values(?,?)/);
$sth->bind_param(1, 1, SQL_INTEGER);
$sth->bind_param(2, $test_value, SQL_VARCHAR);
$sth->execute;
my_is($dbh, "prepared insert with provided bound data and type SQL_VARCHAR");

$sth = $dbh->prepare(q/insert into test values(?,?)/);
$sth->bind_param(1, undef, SQL_INTEGER);
$sth->bind_param(2, undef, SQL_CHAR);
$sth->execute(1, $test_value);
my_is($dbh, "prepared insert with sticky bound data and type SQL_CHAR");

$dbh->do(q/insert into test values(?,?)/, undef, 1, $test_value);
$sth = $dbh->prepare(q/update test set b = ? where a = ?/);
$sth->bind_param(1, undef, SQL_CHAR);
$sth->bind_param(2, undef, SQL_INTEGER);
$sth->execute($test_value, 1);
my_is($dbh, "update with sticky bound type char");

$dbh->{sqlite_see_if_its_a_number} = 0;
$dbh->do(q/insert into test values(?,?)/, undef, 1, $test_value);
my_is($dbh, "do insert see_if_its_a_number = 0");

$sth = $dbh->prepare(q/insert into test values(?,?)/);
$sth->bind_param(1, 1, SQL_INTEGER);
$sth->bind_param(2, $test_value, SQL_VARCHAR);
$sth->execute;
my_is($dbh, "prepared insert with provided bound data and type SQL_VARCHAR see_if_its_a_number=0");
