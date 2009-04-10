#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More tests => 7;
use Test::NoWarnings;

my $dbh = DBI->connect('dbi:SQLite:dbname=:memory:',undef,undef,{RaiseError => 1});

ok( $dbh->do(<<'END_SQL'), 'Created test table' );
    CREATE TABLE test (
        id INTEGER PRIMARY KEY NOT NULL,
        name VARCHAR(255)
    );
END_SQL

my $sth = $dbh->column_info(undef,undef,'test',undef);
is $@, '', 'No error creating the table';

ok $sth, 'We can get column information';

my %expected = (
    TYPE_NAME   => [qw[ INTEGER VARCHAR ]],
    COLUMN_NAME => [qw[ ID NAME ]],
);

SKIP: {
    if ($sth) {
        my $info = $sth->fetchall_arrayref({});

        is( scalar @$info, 2, 'We got information on two columns' );
    
        foreach my $item (qw( TYPE_NAME COLUMN_NAME )) {
            my @info = map { uc $_->{$item} } (@$info);
            is_deeply( \@info, $expected{$item}, "We got the right info in $item" );
        };
    } else {
        skip( "The table didn't get created correctly or we can't get column information.", 3 );
    }
};
