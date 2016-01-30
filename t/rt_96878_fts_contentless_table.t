#!/usr/bin/perl

# In a contentless FTS table, the columns are hidden from the schema,
# and therefore SQLite has no information to infer column types, so
# these are typed as SQLITE_NULL ... and this type conflicts with the
# constraint on the 'docid' column. So we have to explicitly type that
# column, using a CAST expression or a call to bind_param().

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;

BEGIN { requires_sqlite('3.7.9') }
BEGIN { plan skip_all => 'FTS3 is disabled for this DBD::SQLite' if !grep /ENABLE_FTS3/, DBD::SQLite::compile_options() }

use DBI qw/SQL_INTEGER/;
plan tests => 8;
use Test::NoWarnings;

my $dbh = connect_ok(RaiseError => 1, AutoCommit => 1);

# $dbh->trace(15);

my $sql = q{CREATE VIRTUAL TABLE foo USING fts4 (content="", a, b)};
ok( $dbh->do($sql), 'CREATE TABLE' );


ok($dbh->do("INSERT INTO foo(docid, a, b) VALUES(1, 'a', 'b')"),
   "insert without bind");

# The following yields a constraint error because docid is improperly typed
# $dbh->do("INSERT INTO foo(docid, a, b) VALUES(?, ?, ?)", {}, qw/2 aa bb/);

# This works, thanks to the cast expression
ok($dbh->do("INSERT INTO foo(docid, a, b) VALUES(CAST(? AS INTEGER), ?, ?)",
            {}, qw/2 aa bb/),
   "insert with bind and cast");

# This also works, thanks to the bind_param() call
my $sth = $dbh->prepare("INSERT INTO foo(docid, a, b) VALUES(?, ?, ?)");
$sth->bind_param(1, 3, SQL_INTEGER);
$sth->bind_param(2, "aaa");
$sth->bind_param(3, "bbb");
ok($sth->execute(),
   "insert with bind_param and explicit type ");

# Check that all terms were properly inserted
ok( $dbh->do("CREATE VIRTUAL TABLE foo_aux USING fts4aux(foo)"), 'FTS4AUX');
my $data = $dbh->selectcol_arrayref("select term from foo_aux where col='*'");
is_deeply ([sort @$data], [qw/a aa aaa b bb bbb/], "terms properly indexed");

