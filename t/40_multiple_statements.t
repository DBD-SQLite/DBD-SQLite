#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More;
use Test::NoWarnings;

plan tests => 21;

{
	# DBD::SQLite prepares/does the first statement only;
	# the following statements will be discarded silently.

	my $dbh = connect_ok( RaiseError => 1 );
	eval { $dbh->do(q/
		create table foo (id integer);
		insert into foo (id) values (1);
		insert into foo (id) values (2);
	/)};
	ok !$@, "do succeeds anyway";
	diag $@ if $@;
	my $got = $dbh->selectall_arrayref('select id from foo order by id');
	ok !@$got, "but got nothing as the inserts were discarded";
}

{
	# As of 1.29_01, you can do bulk inserts with the help of
	# "sqlite_allows_multiple_statements" and
	# "sqlite_unprepared_statements" attributes.
	my $dbh = connect_ok(
		RaiseError => 1,
		sqlite_allow_multiple_statements => 1,
	);
	ok $dbh->{sqlite_allow_multiple_statements}, "allows multiple statements";
	eval { $dbh->do(q/
		create table foo (id integer);
		insert into foo (id) values (1);
		insert into foo (id) values (2);
	/, { sqlite_allow_multiple_statements => 1 })};
	ok !$@, "do succeeds anyway";
	diag $@ if $@;

	my $got = $dbh->selectall_arrayref('select id from foo order by id');
	ok $got->[0][0] == 1
	&& $got->[1][0] == 2, "and got the inserted values";
}

{
	# Do it more explicitly
	my $dbh = connect_ok(
		RaiseError => 1,
		sqlite_allow_multiple_statements => 1,
	);
	ok $dbh->{sqlite_allow_multiple_statements}, "allows multiple statements";
	my $statement = q/
		create table foo (id integer);
		insert into foo (id) values (1);
		insert into foo (id) values (2);
	/;
	$dbh->begin_work;
	eval {
		while ($statement) {
			my $sth = $dbh->prepare($statement);
			$sth->execute;
			$statement = $sth->{sqlite_unprepared_statements};
		}
	};
	ok !$@, "executed multiple statements successfully";
	diag $@ if $@;
	$@ ? $dbh->rollback : $dbh->commit;

	my $got = $dbh->selectall_arrayref('select id from foo order by id');
	ok $got->[0][0] == 1
	&& $got->[1][0] == 2, "and got the inserted values";
}

{
	# Placeholders
	my $dbh = connect_ok(
		RaiseError => 1,
		sqlite_allow_multiple_statements => 1,
	);
	ok $dbh->{sqlite_allow_multiple_statements}, "allows multiple statements";
	eval { $dbh->do(q/
		create table foo (id integer);
		insert into foo (id) values (?);
		insert into foo (id) values (?);
	/, undef, 1, 2)};
	ok !$@, "do succeeds anyway";
	diag $@ if $@;

	my $got = $dbh->selectall_arrayref('select id from foo order by id');
	ok $got->[0][0] == 1
	&& $got->[1][0] == 2, "and got the inserted values";
}

{
	# Do it more explicitly
	my $dbh = connect_ok(
		RaiseError => 1,
		sqlite_allow_multiple_statements => 1,
	);
	ok $dbh->{sqlite_allow_multiple_statements}, "allows multiple statements";
	my $statement = q/
		create table foo (id integer);
		insert into foo (id) values (?);
		insert into foo (id) values (?);
	/;
	$dbh->begin_work;
	eval {
		my @params = (1, 2);
		while ($statement) {
			my $sth = $dbh->prepare($statement);
			$sth->execute(splice @params, 0, $sth->{NUM_OF_PARAMS});
			$statement = $sth->{sqlite_unprepared_statements};
		}
	};
	ok !$@, "executed multiple statements successfully";
	diag $@ if $@;
	$@ ? $dbh->rollback : $dbh->commit;

	ok !$@, "executed multiple statements successfully";
	diag $@ if $@;

	my $got = $dbh->selectall_arrayref('select id from foo order by id');
	ok $got->[0][0] == 1
	&& $got->[1][0] == 2, "and got the inserted values";
}
