#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More tests => 8;
use Test::NoWarnings;

my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
eval { $dbh->do('foobar') };
ok $@, "raised error";
ok $dbh->err, "has err";
ok $dbh->errstr, "has errstr";
ok $dbh->ping, "ping succeeded";
ok $dbh->err, "err is not wiped out";
ok $dbh->errstr, "errstr is not wiped out";
