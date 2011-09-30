#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More;
use DBI qw/:sql_types/;

for my $has_pk (0..1) {
	my $dbh = connect_ok(RaiseError => 1);
	if ($has_pk) {
		$dbh->do('create table foo (id integer, v integer primary key)');
	}
	else {
		$dbh->do('create table foo (id integer, v integer)');
	}

	{
		my $sth = $dbh->prepare('insert into foo values (?, ?)');
		$sth->bind_param(1, 1);
		$sth->bind_param(2, 1);
		eval { $sth->execute };
		ok !$@, "inserted without errors";

		my ($value) = $dbh->selectrow_array('select v from foo where id = ?', undef, 1);
		ok $value && $value == 1, "got correct value";
	}

	{
		my $sth = $dbh->prepare('insert into foo values (?, ?)');
		$sth->bind_param(1, 2);
		$sth->bind_param(2, 'foo'); # may seem weird, but that's sqlite
		eval { $sth->execute };

		if ($has_pk) {
			ok $sth->errstr && $sth->errstr =~ /datatype mismatch/, "insert failed: type mismatch";
		}
		else {
			ok !$@, "inserted without errors";
		}

		my ($value) = $dbh->selectrow_array('select v from foo where id = ?', undef, 2);

		if ($has_pk) {
			ok !$value , "not inserted/indexed";
		}
		else {
			ok $value && $value eq 'foo', "got correct value";
		}
	}

	{
		my $sth = $dbh->prepare('insert into foo values (?, ?)');
		$sth->bind_param(1, 3);
		$sth->bind_param(2, 3, SQL_INTEGER);
		eval { $sth->execute };
		ok !$@, "inserted without errors";

		my ($value) = $dbh->selectrow_array('select v from foo where id = ?', undef, 3);
		ok $value && $value == 3, "got correct value";
	}

	{
		my $sth = $dbh->prepare('insert into foo values (?, ?)');
		$sth->bind_param(1, 4);
		$sth->bind_param(2, 'qux', SQL_INTEGER);

		# only dies if type is explicitly specified
		eval { $sth->execute };
		ok $sth->errstr && $sth->errstr =~ /datatype mismatch/, "insert failed: type mismatch";

		my ($value) = $dbh->selectrow_array('select v from foo where id = ?', undef, 4);
		ok !$value, "not inserted/indexed";
	}

	$dbh->disconnect;
}

done_testing;
