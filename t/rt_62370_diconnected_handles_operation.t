#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok @CALL_FUNCS/;
use Test::More;
use DBD::SQLite;
#use Test::NoWarnings;

my @methods = qw(
	commit rollback
);

plan tests => 2 * (6 + @methods) + 2 * @CALL_FUNCS * (14 + ($DBD::SQLite::sqlite_version_number >= 3006011) * 2);

local $SIG{__WARN__} = sub {};  # to hide warnings/error messages

# DBI methods

for my $autocommit (0, 1) {
	my $dbh = connect_ok( RaiseError => 1, PrintError => 0, AutoCommit => $autocommit );
	$dbh->do('create table foo (id, text)');
	$dbh->do('insert into foo values(?,?)', undef, 1, 'text');
	{
		local $@;
		eval { $dbh->disconnect };
		ok !$@, "disconnected";
	}

	for my $method (@methods) {
		local $@;
		eval { $dbh->$method };
		ok $@, "$method dies with error: $@";
	}

	{
		local $@;
		eval { $dbh->last_insert_id(undef, undef, undef, undef) };
		ok $@, "last_insert_id dies with error: $@";
	}

	{
		local $@;
		eval { $dbh->do('insert into foo (?,?)', undef, 2, 'text2') };
		ok $@, "do dies with error: $@";
	}

	{
		local $@;
		eval { $dbh->selectrow_arrayref('select * from foo') };
		ok $@, "selectrow_arrayref dies with error: $@";
	}

	{ # this should be the last test in this block
		local $@;
		eval { local $dbh->{AutoCommit} };
		ok !$@, "store doesn't cause segfault";
	}
}

# SQLite private methods

for my $call_func (@CALL_FUNCS) {
	for my $autocommit (0, 1) {
		my $dbh = connect_ok( RaiseError => 1, PrintError => 0, AutoCommit => $autocommit );
		$dbh->do('create table foo (id, text)');
		$dbh->do('insert into foo values(?,?)', undef, 1, 'text');
		{
			local $@;
			eval { $dbh->disconnect };
			ok !$@, "disconnected";
		}

		{
			local $@;
			eval { $dbh->$call_func(500, 'busy_timeout') };
			ok $@, "busy timeout dies with error: $@";
		}

		{
			local $@;
			eval { $dbh->$call_func('now', 0, sub { time }, 'create_function') };
			ok $@, "create_function dies with error: $@";
		}

		{
			local $@;
			eval { $dbh->$call_func(1, 'enable_load_extension') };
			ok $@, "enable_load_extension dies with error: $@";
		}

		{
			package count_aggr;

			sub new {
				bless { count => 0 }, shift;
			}

			sub step {
				$_[0]{count}++;
				return;
			}

			sub finalize {
				my $c = $_[0]{count};
				$_[0]{count} = undef;

				return $c;
			}

			package main;

			local $@;
			eval { $dbh->$call_func('newcount', 0, 'count_aggr', 'create_aggregate') };
			ok $@, "create_aggregate dies with error: $@";
		}

		{
			local $@;
			eval { $dbh->$call_func('by_num', sub ($$) {0}, 'create_collation') };
			ok $@, "create_collation dies with error: $@";
		}

		{
			local $@;
			eval { $dbh->$call_func('by_num', sub ($$) {0}, 'create_collation') };
			ok $@, "create_collation dies with error: $@";
		}

		{
			local $@;
			eval { $dbh->$call_func(sub {1}, 'collation_needed') };
			ok $@, "collation_needed dies with error: $@";
		}

		{
			local $@;
			eval { $dbh->$call_func(50, sub {}, 'progress_handler') };
			ok $@, "progress_handler dies with error: $@";
		}

		{
			local $@;
			eval { $dbh->$call_func(sub {}, 'commit_hook') };
			ok $@, "commit hook dies with error: $@";
		}

		{
			local $@;
			eval { $dbh->$call_func(sub {}, 'rollback_hook') };
			ok $@, "rollback hook dies with error: $@";
		}

		{
			local $@;
			eval { $dbh->$call_func(sub {}, 'update_hook') };
			ok $@, "update hook dies with error: $@";
		}

		{
			local $@;
			eval { $dbh->$call_func(undef, 'set_authorizer') };
			ok $@, "set authorizer dies with error: $@";
		}

		if ($DBD::SQLite::sqlite_version_number >= 3006011) {
			local $@;
			eval { $dbh->$call_func('./backup_file', 'backup_from_file') };
			ok $@, "backup from file dies with error: $@";
		}

		if ($DBD::SQLite::sqlite_version_number >= 3006011) {
			local $@;
			eval { $dbh->$call_func('./backup_file', 'backup_to_file') };
			ok $@, "backup to file dies with error: $@";
		}
	}
}
