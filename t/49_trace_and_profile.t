#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/connect_ok/;
use Test::More tests => 13;
use Test::NoWarnings;

my $dbh = connect_ok();

{ # trace
	my @trace;
	$dbh->sqlite_trace(sub { push @trace, [@_] });
	$dbh->do('create table foo (id integer)');
	is $trace[0][0] => "create table foo (id integer)";

	$dbh->do('insert into foo values (?)', undef, 1);
	is $trace[1][0] => "insert into foo values ('1')";

	$dbh->sqlite_trace(undef);

	$dbh->do('insert into foo values (?)', undef, 2);
	is @trace => 2;

	$dbh->sqlite_trace(sub { push @trace, [@_] });
	$dbh->do('insert into foo values (?)', undef, 3);
	is $trace[2][0] => "insert into foo values ('3')";
}

{ # profile
	my @profile;
	$dbh->sqlite_profile(sub { push @profile, [@_] });
	$dbh->do('create table bar (id integer)');
	is $profile[0][0] => "create table bar (id integer)";
	like $profile[0][1] => qr/^[0-9]+$/;

	$dbh->do('insert into bar values (?)', undef, 1);
	is $profile[1][0] => "insert into bar values (?)";
	like $profile[1][1] => qr/^[0-9]+$/;

	$dbh->sqlite_profile(undef);

	$dbh->do('insert into bar values (?)', undef, 2);
	is @profile => 2;

	$dbh->sqlite_profile(sub { push @profile, [@_] });
	$dbh->do('insert into bar values (?)', undef, 3);
	is $profile[2][0] => "insert into bar values (?)";
	like $profile[2][1] => qr/^[0-9]+$/;
}
