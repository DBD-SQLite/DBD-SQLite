use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok @CALL_FUNCS requires_sqlite/;
use Test::More;

BEGIN { requires_sqlite('3.6.21') }

use if -d ".git", "Test::FailWarnings";

my $flag = 0;
for my $call_func (@CALL_FUNCS) {
	my $dbh = connect_ok();

	# sqlite_trace should always be called as sqlite_trace,
	# i.e. $dbh->func(..., "sqlite_trace") and $dbh->sqlite_trace(...)
	my $func_name = $flag++ ? "trace" : "sqlite_trace";

	# trace
	my @trace;
	$dbh->$call_func(sub { push @trace, [@_] }, $func_name);
	$dbh->do('create table foo (id integer)');
	is $trace[0][0] => "create table foo (id integer)";

	$dbh->do('insert into foo values (?)', undef, 1);
	is $trace[1][0] => "insert into foo values ('1')";

	$dbh->$call_func(undef, $func_name);

	$dbh->do('insert into foo values (?)', undef, 2);
	is @trace => 2;

	$dbh->$call_func(sub { push @trace, [@_] }, $func_name);
	$dbh->do('insert into foo values (?)', undef, 3);
	is $trace[2][0] => "insert into foo values ('3')";

	# profile
	my @profile;
	$dbh->$call_func(sub { push @profile, [@_] }, "profile");
	$dbh->do('create table bar (id integer)');
	is $profile[0][0] => "create table bar (id integer)";
	like $profile[0][1] => qr/^[0-9]+$/;

	$dbh->do('insert into bar values (?)', undef, 1);
	is $profile[1][0] => "insert into bar values (?)";
	like $profile[1][1] => qr/^[0-9]+$/;

	$dbh->$call_func(undef, "profile");

	$dbh->do('insert into bar values (?)', undef, 2);
	is @profile => 2;

	$dbh->$call_func(sub { push @profile, [@_] }, "profile");
	$dbh->do('insert into bar values (?)', undef, 3);
	is $profile[2][0] => "insert into bar values (?)";
	like $profile[2][1] => qr/^[0-9]+$/;
}

done_testing;
