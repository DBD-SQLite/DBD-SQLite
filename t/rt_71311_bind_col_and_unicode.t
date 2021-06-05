use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";
use DBI qw/:sql_types/;

use DBD::SQLite::Constants ':dbd_sqlite_string_mode';

BEGIN{ requires_unicode_support(); }

my $dbh = connect_ok(sqlite_string_mode => DBD_SQLITE_STRING_MODE_UNICODE_STRICT);
$dbh->do('create table test1 (id integer, b blob)');

my $blob = "\x{82}\x{A0}";
my $str  = "\x{20ac}";

{
	my $sth = $dbh->prepare('insert into test1 values (?, ?)');

	$sth->execute(1, $blob);

	$sth->bind_param(1, 2);;
	$sth->bind_param(2, $blob, SQL_BLOB);
	$sth->execute;

	$sth->bind_param(1, 3);;
	$sth->bind_param(2, $blob, {TYPE => SQL_BLOB});
	$sth->execute;

	$sth->bind_param(2, undef, SQL_VARCHAR);
	$sth->execute(4, $str);

	$sth->bind_param(1, 5);;
	$sth->bind_param(2, utf8::encode($str), SQL_BLOB);
	$sth->execute;

	$sth->bind_param(1, 6);;
	$sth->bind_param(2, utf8::encode($str), {TYPE => SQL_BLOB});
	$sth->execute;

	$sth->finish;
}

{
	my $sth = $dbh->prepare('select * from test1 order by id');

	$sth->execute;

	my $expected = [undef, 1, 0, 0, 1, 1, 1];
	for (1..6) {
		my $row = $sth->fetch;

		ok $row && $row->[0] == $_;
		ok $row && utf8::is_utf8($row->[1]) == $expected->[$_],
			"row $_ is ".($expected->[$_] ? "unicode" : "not unicode");
	}

	$sth->finish;
}

{
	my $sth = $dbh->prepare('select * from test1 order by id');
	$sth->bind_col(1, \my $col1);
	$sth->bind_col(2, \my $col2);
	$sth->execute;

	my $expected = [undef, 1, 0, 0, 1, 1, 1];
	for (1..6) {
		$sth->fetch;

		ok $col1 && $col1 == $_;
		ok $col1 && utf8::is_utf8($col2) == $expected->[$_],
			"row $_ is ".($expected->[$_] ? "unicode" : "not unicode");
	}
	$sth->finish;
}

{
	my $sth = $dbh->prepare('select * from test1 order by id');
	$sth->bind_col(1, \my $col1);
	$sth->bind_col(2, \my $col2, SQL_BLOB);
	$sth->execute;

	my $expected = [undef, 0, 0, 0, 0, 0, 0];
	for (1..6) {
		$sth->fetch;

		ok $col1 && $col1 == $_;
		ok $col2 && utf8::is_utf8($col2) == $expected->[$_],
			"row $_ is ".($expected->[$_] ? "unicode" : "not unicode");
	}
	$sth->finish;
}

{
	my $sth = $dbh->prepare('select * from test1 order by id');
	$sth->bind_col(1, \my $col1);
	$sth->bind_col(2, \my $col2, {TYPE => SQL_BLOB});
	$sth->execute;

	my $expected = [undef, 0, 0, 0, 0, 0, 0];
	for (1..6) {
		$sth->fetch;
		ok $col1 && $col1 == $_;
		ok $col2 && utf8::is_utf8($col2) == $expected->[$_],
			"row $_ is ".($expected->[$_] ? "unicode" : "not unicode");
	}
	$sth->finish;
}

done_testing;
