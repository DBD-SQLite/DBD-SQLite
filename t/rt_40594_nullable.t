#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More;
use t::lib::Test;
use DBD::SQLite;

BEGIN {
	if (!grep /^ENABLE_COLUMN_METADATA/, DBD::SQLite::compile_options()) {
		plan skip_all => "Column metadata is disabled for this DBD::SQLite";
	}
}

plan tests => 7;

my $dbh = connect_ok();

ok $dbh->do("CREATE TABLE foo (id INTEGER PRIMARY KEY NOT NULL, col1 varchar(2) NOT NULL, col2 varchar(2), col3 char(2) NOT NULL)");
my $sth = $dbh->prepare ('SELECT * FROM foo');
ok $sth->execute;

my $expected = {
    NUM_OF_FIELDS => 4,
    NAME_lc => [qw/id col1 col2 col3/],
    TYPE => [qw/INTEGER varchar(2) varchar(2) char(2)/],
    NULLABLE => [qw/0 0 1 0/],
};

for my $m (keys %$expected) {
    is_deeply($sth->{$m}, $expected->{$m});
}
