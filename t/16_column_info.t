#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More tests => 10;
use Test::NoWarnings;

my $dbh = DBI->connect('dbi:SQLite:dbname=:memory:',undef,undef,{RaiseError => 1});

ok( $dbh->do(<<'END_SQL'), 'Created test table' );
    CREATE TABLE test (
        id INTEGER PRIMARY KEY NOT NULL,
        name VARCHAR(255)
    );
END_SQL

ok( $dbh->do(<<'END_SQL'), 'Created temp test table' );
    CREATE TEMP TABLE test2 (
        id INTEGER PRIMARY KEY NOT NULL,
        flag INTEGER
    );
END_SQL

my $sth = $dbh->column_info(undef, undef, 'test', undef);
is $@, '', 'No error creating the table';

ok $sth, 'We can get column information';

my %expected = (
    TYPE_NAME   => [qw( INTEGER VARCHAR )],
    COLUMN_NAME => [qw( ID NAME )],
);

SKIP: {
    skip( "The table didn't get created correctly or we can't get column information.", 5 ) unless $sth;

    my $info = $sth->fetchall_arrayref({});

    is( scalar @$info, 2, 'We got information on two columns' );

    foreach my $item (qw( TYPE_NAME COLUMN_NAME )) {
        my @info = map { uc $_->{$item} } (@$info);
        is_deeply( \@info, $expected{$item}, "We got the right info in $item" );
    }

    $info = $dbh->column_info(undef, undef, 'test%', '%a%')->fetchall_arrayref({});

    is( scalar @$info, 2, 'We matched information from multiple databases' );

    my @fields = qw( TYPE_NAME COLUMN_NAME COLUMN_SIZE );
    my @info = map [ @$_{@fields} ], @$info;
    my $expected = [
        [ 'VARCHAR', 'name', 255 ],
        [ 'INTEGER', 'flag', undef ]
    ];

    is_deeply( \@info, $expected, 'We got the right info from multiple databases' );
}
