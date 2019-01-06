use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok @CALL_FUNCS requires_sqlite/;
use Test::More;

BEGIN { requires_sqlite('3.7.10') }

use if -d ".git", "Test::FailWarnings";

for my $func (@CALL_FUNCS) {
	{
		my $db = filename($func);
		ok !$db, "in-memory database";
	}

	{
		my $db = filename($func, dbfile => '');
		ok !$db, "temporary database";
	}

	{
		my $db = filename($func, dbfile => 'test.db');
		like $db => qr/test\.db[\d]*$/i, "test.db";
		unlink $db;
	}
}

sub filename {
	my $func = shift;
	my $dbh = connect_ok(@_);
	$dbh->$func('db_filename');
}

done_testing;
