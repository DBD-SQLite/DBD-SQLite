#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 2;
use t::lib::Test;

my $dbh = connect_ok( PrintError => 0, RaiseError => 1 );

my $sth = $dbh->prepare('CREATE TABLE foo (f)');
   $dbh->disconnect;

# attempt to execute on inactive database handle
my $ret = eval { $sth->execute; };

ok !defined $ret;
