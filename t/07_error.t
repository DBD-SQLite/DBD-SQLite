#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 3;
use t::lib::Test;

my $dbh = connect_ok( RaiseError => 1, PrintError => 0 );
eval {
  $dbh->do('ssdfsdf sdf sd sdfsdfdsf sdfsdf');
};
ok($@);

$dbh->do('create table testerror (a, b)');
$dbh->do('insert into testerror values (1, 2)');
$dbh->do('insert into testerror values (3, 4)');

$dbh->do('create unique index testerror_idx on testerror (a)');
eval {
  $dbh->do('insert into testerror values (1, 5)');
};
ok($@);
