#!/usr/bin/perl -w
BEGIN { 
    local $@;
    unless (eval { require Test::More; 1 }) {
        print "1..0 # Skip need Test::More\n";
        exit;
    }
}
use strict;
use Test::More tests => 7;

BEGIN {
    use_ok 'DBD::SQLite'
        or BAIL_OUT 'DBD::SQLite(::Amalgamation) failed to load. No sense in continuing.';
    no warnings 'once';
    #diag "Testing DBD::SQLite version '$DBD::SQLite::VERSION' on DBI '$DBI::VERSION'";
    
    #*DBD::SQLite::db::column_info = \&DBD::SQLite::db::_sqlite_column_info;
};
use DBI;

my $dbh = DBI->connect('dbi:SQLite:dbname=:memory:',undef,undef,{RaiseError => 1});

ok $dbh->do(<<''), 'Created test table';
    CREATE TABLE test (
        id INTEGER PRIMARY KEY NOT NULL,
        name VARCHAR(255)
    );

my $sth = $dbh->column_info(undef,undef,'test',undef);
is $@, '', 'No error creating the table';

ok $sth, 'We can get column information';

my %expected = (
    TYPE_NAME => [qw[ INTEGER VARCHAR ]],
    COLUMN_NAME => [qw[ ID NAME ]],
);

SKIP: {
    if ($sth) {
        my $info = $sth->fetchall_arrayref({});

        is scalar @$info, 2, 'We got information on two columns';
    
        for my $item (qw( TYPE_NAME COLUMN_NAME )) {
            my @info = map {uc $_->{$item}} (@$info);
            is_deeply \@info, $expected{$item}, "We got the right info in $item";
        };
    } else {
        skip "The table didn't get created correctly or we can't get column information.", 3;
    }
};
