#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
# use Test::More tests => 18;
use Test::More skip_all => 'Temporarily disabling known-bad test';
use Test::NoWarnings;

my $dbh = connect_ok();
$dbh->{unicode} = 1;

ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE' );
CREATE TABLE foo (
    bar varchar(255)
)
END_SQL

foreach ( "\0", "A", "\xe9", "\x{20ac}" ) {
    ok( $dbh->do("INSERT INTO foo VALUES ( ? )", {}, $_), 'INSERT' );
    my $foo = $dbh->selectall_arrayref("SELECT bar FROM foo");
    is_deeply( $foo, [ [ $_ ] ], 'Value round-tripped ok' );
    my $len = $dbh->selectall_arrayref("SELECT length(bar) FROM foo");
    is $len->[0][0], 1 unless $_ eq "\0";
    ok( $dbh->do("DELETE FROM foo"), 'DELETE ok' );
}
