#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 2;
use t::lib::Test;

my $db = DBI->connect('dbi:SQLite:foo', '', '', { RaiseError => 1, PrintError => 0 });
eval {
  $db->do('ssdfsdf sdf sd sdfsdfdsf sdfsdf');
};
ok($@);

$db->do('create table testerror (a, b)');
$db->do('insert into testerror values (1, 2)');
$db->do('insert into testerror values (3, 4)');

$db->do('create unique index testerror_idx on testerror (a)');
eval {
  $db->do('insert into testerror values (1, 5)');
};
ok($@);
