#!/usr/bin/perl

use strict;
BEGIN {
    $|  = 1;
    $^W = 1;
}

use t::lib::Test;
use Test::More;
use Test::NoWarnings;

plan tests => 9;

# no type specification
my @values = qw/ 0 1 1.0 1.0e+001 /;
for my $value (@values) {
    my $dbh = connect_ok( RaiseError => 1, AutoCommit => 1 );
    $dbh->do('create table foo (string)');
    $dbh->do('insert into foo values(?)', undef, $value);
    my ($got) = $dbh->selectrow_array('select string from foo where string = ?', undef, $value);
    ok defined $got && $got eq $value, "got: $got value: $value";
}
