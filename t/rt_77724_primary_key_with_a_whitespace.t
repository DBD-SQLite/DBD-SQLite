use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok(RaiseError => 1, PrintError => 0);

$dbh->do($_) for
	q[CREATE TABLE "Country Info" ("Country Code" CHAR(2) PRIMARY KEY, "Name" VARCHAR(200))],
	q[INSERT INTO "Country Info" VALUES ('DE', 'Germany')],
	q[INSERT INTO "Country Info" VALUES ('FR', 'France')];

my $sth = $dbh->primary_key_info(undef, undef, "Country Info");
my $row = $sth->fetchrow_hashref;
ok $row, 'Found the primary key column.';

is $row->{COLUMN_NAME} => "Country Code",
	'Key column name reported correctly.'
	or note explain $row;

done_testing;
