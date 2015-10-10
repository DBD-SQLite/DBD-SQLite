#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;

BEGIN { requires_sqlite('3.6.8') }

plan tests => 2;
use Test::NoWarnings;

{ # simple case
	my $dbh = connect_ok(
		AutoCommit => 1,
		RaiseError => 1,
	);
	$dbh->begin_work;
	$dbh->do("SAVEPOINT svp_0");
	$dbh->do("RELEASE SAVEPOINT svp_0");
	$dbh->commit;
	# should not spit the "Issuing rollback()" warning
}
