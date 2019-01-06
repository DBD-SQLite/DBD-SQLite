use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok requires_sqlite/;
use Test::More;
use DBD::SQLite::Constants qw/SQLITE_OPEN_READONLY/;

BEGIN { requires_sqlite('3.7.11') }

use if -d ".git", "Test::FailWarnings";

{
	my $dbh = connect_ok(
		sqlite_open_flags => SQLITE_OPEN_READONLY,
		RaiseError => 0,
		PrintError => 0,
	);
	ok $dbh->{ReadOnly};
	ok !$dbh->do('CREATE TABLE foo (id)');
	like $dbh->errstr => qr/attempt to write a readonly database/;
}

{
	my $dbh = connect_ok(ReadOnly => 1, PrintError => 0, RaiseError => 0);
	ok $dbh->{ReadOnly};
	ok !$dbh->do('CREATE TABLE foo (id)');
	like $dbh->errstr => qr/attempt to write a readonly database/;
}

{
	my $dbh = connect_ok(PrintWarn => 0, PrintError => 0, RaiseError => 0);
	$dbh->{ReadOnly} = 1;
	ok !$dbh->err;
	like $dbh->errstr => qr/ReadOnly is set but/;
	ok $dbh->{ReadOnly};

	# this is ok because $dbh is not actually readonly (though we
	# told so)
	ok $dbh->do('CREATE TABLE foo (id)');
}

done_testing;
