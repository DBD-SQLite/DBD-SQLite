#!/usr/bin/perl

use strict;
BEGIN {
    $|  = 1;
    $^W = 1;
}

use t::lib::Test;
use Test::More;
use Test::NoWarnings;

my @values = qw/
    0 1 1.0 1.0e+001 0000 01010101 10010101
    0000002100000517
    0000002200000517
    0000001e00000517
    00002.000
    test 01234test -test +test
    0.123e 0.123e+
    0. .123
    -1 -1.0 -1.0e-001 -0000 -0101 -002.00
    +1 +1.0 +1.0e-001 +0000 +0101 +002.00
    1234567890123456789012345678901234567890
    -1234567890123456789012345678901234567890
    +1234567890123456789012345678901234567890
    *1234567890123456789012345678901234567890
    -9223372036854775807 +9223372036854775806
    -9223372036854775808 +9223372036854775807
    -9223372036854775809 +9223372036854775808
    -2147483646 + 2147483647
    -2147483647 + 2147483648
    -2147483648 + 2147483649
/;

plan tests => @values * 3 + 1;

# no type specification
for my $value (@values) {
    my $dbh = connect_ok( RaiseError => 1, AutoCommit => 1 );
    $dbh->do('create table foo (string)');
    ok $dbh->do('insert into foo values(?)', undef, $value), "inserting $value";
    my ($got) = $dbh->selectrow_array('select string from foo where string = ?', undef, $value);
    ok defined $got && $got eq $value, "got: $got expected: $value";
}
