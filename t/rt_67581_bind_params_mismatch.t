#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More tests => 34;
use DBI qw/:sql_types/;

my $id = 0;
for my $has_pk (0..1) {
	my $dbh = connect_ok(RaiseError => 1, PrintWarn => 0, PrintError => 0);
	if ($has_pk) {
		$dbh->do('create table foo (id integer, v integer primary key)');
	}
	else {
		$dbh->do('create table foo (id integer, v integer)');
	}

	{
		my $sth = $dbh->prepare('insert into foo values (?, ?)');
		$sth->bind_param(1, ++$id);
		$sth->bind_param(2, 1);
		my $ret = eval { $sth->execute };
		ok defined $ret, "inserted without errors";

		my ($value) = $dbh->selectrow_array('select v from foo where id = ?', undef, $id);
		ok $value && $value == 1, "got correct value";
	}

	{
		my $sth = $dbh->prepare('insert into foo values (?, ?)');
		$sth->bind_param(1, ++$id);
		$sth->bind_param(2, 1.5);
		my $ret = eval { $sth->execute };

		if ($has_pk) {
			ok $@, "died correctly";
			ok !defined $ret, "returns undef";
			ok $sth->errstr && $sth->errstr =~ /datatype mismatch/, "insert failed: type mismatch";
		}
		else {
			ok defined $ret, "inserted without errors";
		}

		my ($value) = $dbh->selectrow_array('select v from foo where id = ?', undef, $id);

		if ($has_pk) {
			ok !$value , "not inserted/indexed";
		}
		else {
			ok $value && $value == 1.5, "got correct value";
		}
	}

	{
		my $sth = $dbh->prepare('insert into foo values (?, ?)');
		$sth->bind_param(1, ++$id);
		$sth->bind_param(2, 'foo'); # may seem weird, but that's sqlite
		my $ret = eval { $sth->execute };

		if ($has_pk) {
			ok $@, "died correctly";
			ok !defined $ret, "returns undef";
			ok $sth->errstr && $sth->errstr =~ /datatype mismatch/, "insert failed: type mismatch";
		}
		else {
			ok defined $ret, "inserted without errors";
		}

		my ($value) = $dbh->selectrow_array('select v from foo where id = ?', undef, $id);

		if ($has_pk) {
			ok !$value , "not inserted/indexed";
		}
		else {
			ok $value && $value eq 'foo', "got correct value";
		}
	}

	{
		my $sth = $dbh->prepare('insert into foo values (?, ?)');
		$sth->bind_param(1, ++$id);
		$sth->bind_param(2, 3, SQL_INTEGER);
		my $ret = eval { $sth->execute };
		ok defined $ret, "inserted without errors";

		my ($value) = $dbh->selectrow_array('select v from foo where id = ?', undef, $id);
		ok $value && $value == 3, "got correct value";
	}

	{
		my $sth = $dbh->prepare('insert into foo values (?, ?)');
		$sth->bind_param(1, ++$id);
		$sth->bind_param(2, 3.5, SQL_INTEGER);
		my $ret = eval { $sth->execute };

		if ($has_pk) {
			ok $@, "died correctly";
			ok !defined $ret, "returns undef";
			ok $sth->errstr && $sth->errstr =~ /datatype mismatch/, "insert failed: type mismatch";
		}
		else {
			ok defined $ret, "inserted without errors";
		}

		my ($value) = $dbh->selectrow_array('select v from foo where id = ?', undef, $id);
		if ($has_pk) {
			ok !$value, "not inserted/indexed";
		}
		else {
			ok $value && $value eq '3.5', "got correct value";
		}
	}

	{
		my $sth = $dbh->prepare('insert into foo values (?, ?)');
		$sth->bind_param(1, ++$id);
		$sth->bind_param(2, 'qux', SQL_INTEGER);

		# only dies if type is explicitly specified
		my $ret = eval { $sth->execute };

		if ($has_pk) {
			ok $@, "died correctly";
			ok !defined $ret, "returns undef";
			ok $sth->errstr && $sth->errstr =~ /datatype mismatch/, "insert failed: type mismatch";
		}
		else {
			ok defined $ret, "inserted without errors";
		}

		my ($value) = $dbh->selectrow_array('select v from foo where id = ?', undef, $id);
		if ($has_pk) {
			ok !$value, "not inserted/indexed";
		}
		else {
			ok $value && $value eq 'qux', "got correct value";
		}
	}

	$dbh->disconnect;
}
