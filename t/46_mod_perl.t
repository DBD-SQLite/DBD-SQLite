#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;
BEGIN {
	eval {require APR::Table; 1};
	if ($@) {
		plan skip_all => 'requires APR::Table';
	}
	else {
		plan tests => 2;
	}
}

my $dbh = connect_ok(
	AutoCommit => 1,
	RaiseError => 1,
);

eval { $dbh->do('SELECT 1') };
ok !$@, "no errors";
diag $@ if $@;
