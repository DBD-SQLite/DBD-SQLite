#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;

BEGIN {
    use DBD::SQLite;
    unless ($DBD::SQLite::sqlite_version_number && $DBD::SQLite::sqlite_version_number >= 3006019) {
        plan skip_all => "this test requires SQLite 3.6.19 and newer";
        exit;
    }
}

use Test::NoWarnings;

my @sql_statements = split /\n\n/, <<__EOSQL__;
CREATE TABLE a (
  id    INTEGER,
  fname  TEXT,
  lname  TEXT,
  UNIQUE(id)
);

CREATE INDEX "a_fn" ON "a" ( "fname" );

CREATE INDEX "a_ln" ON "a" ( "lname" );

CREATE UNIQUE INDEX "a_an" ON "a" ( "fname", "lname" );

ATTACH DATABASE ':memory:' AS remote;

CREATE TABLE remote.b (
  id INTEGER,
  fname TEXT,
  lname TEXT,
  PRIMARY KEY(id),
  UNIQUE(fname, lname)
);

__EOSQL__


plan tests => @sql_statements + 33;

my $dbh = connect_ok( RaiseError => 1, PrintError => 0, AutoCommit => 1 );
my $sth;
my $stats_data;
my $R = \%DBD::SQLite::db::DBI_code_for_rule;

ok ($dbh->do($_), $_) foreach @sql_statements;

$sth = $dbh->statistics_info(undef, undef, 'a', 0, 0);
$stats_data = $sth->fetchall_hashref([ 'INDEX_NAME', 'ORDINAL_POSITION' ]);

for ($stats_data->{a_fn}->{1}) {
  is($_->{TABLE_NAME},  "a"  ,   "table name");
  is($_->{COLUMN_NAME}, "fname",   "column name");
  is($_->{TYPE},        "btree",           "type");
  is($_->{ORDINAL_POSITION}, 1,           "ordinal position");
  is($_->{NON_UNIQUE}, 1,           "non unique");
  is($_->{INDEX_NAME}, "a_fn",           "index name");
  is($_->{TABLE_SCHEM}, "main",           "table schema");
}
ok(not(exists $stats_data->{a_fn}->{2}), "only one index in a_fn index");
for ($stats_data->{a_ln}->{1}) {
  is($_->{TABLE_NAME},  "a"  ,   "table name");
  is($_->{COLUMN_NAME}, "lname",   "column name");
  is($_->{TYPE},        "btree",           "type");
  is($_->{ORDINAL_POSITION}, 1,           "ordinal position");
  is($_->{NON_UNIQUE}, 1,           "non unique");
  is($_->{INDEX_NAME}, "a_ln",           "index name");
  is($_->{TABLE_SCHEM}, "main",           "table schema");
}
ok(not(exists $stats_data->{a_ln}->{2}), "only one index in a_ln index");
for ($stats_data->{a_an}->{1}) {
  is($_->{TABLE_NAME},  "a"  ,   "table name");
  is($_->{COLUMN_NAME}, "fname",   "column name");
  is($_->{TYPE},        "btree",           "type");
  is($_->{ORDINAL_POSITION}, 1,           "ordinal position");
  is($_->{NON_UNIQUE}, 0,           "non unique");
  is($_->{INDEX_NAME}, "a_an",           "index name");
  is($_->{TABLE_SCHEM}, "main",           "table schema");
}
for ($stats_data->{a_an}->{2}) {
  is($_->{TABLE_NAME},  "a"  ,   "table name");
  is($_->{COLUMN_NAME}, "lname",   "column name");
  is($_->{TYPE},        "btree",           "type");
  is($_->{ORDINAL_POSITION}, 2,           "ordinal position");
  is($_->{NON_UNIQUE}, 0,           "non unique");
  is($_->{INDEX_NAME}, "a_an",           "index name");
  is($_->{TABLE_SCHEM}, "main",           "table schema");
}
ok(not(exists $stats_data->{a_ln}->{3}), "only two indexes in a_an index");
