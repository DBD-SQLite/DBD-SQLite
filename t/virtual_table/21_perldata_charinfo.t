#!/usr/bin/perl
use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

# test the example described in 
# L<DBD::SQLite::VirtualTable::PerlData/"Hashref example : unicode characters">

use t::lib::Test qw/connect_ok/;
use Test::More;
use Test::NoWarnings;

use Unicode::UCD 'charinfo';

our $chars = [map {charinfo($_)} 0x300..0x400];

plan tests => 10;

my $dbh = connect_ok( RaiseError => 1, AutoCommit => 1 );

ok $dbh->sqlite_create_module(perl => "DBD::SQLite::VirtualTable::PerlData"),
   "create_module";

ok $dbh->do(<<""), "create table";
  CREATE VIRTUAL TABLE charinfo USING perl(
    code, name, block, script, category,
    hashrefs="main::chars")

my $sql = "SELECT * FROM charinfo WHERE script='Greek' AND name LIKE '%SIGMA%'";
my $res = $dbh->selectall_arrayref($sql, {Slice => {}});
ok scalar(@$res),                        "found sigma letters";
is $res->[0]{block}, "Greek and Coptic", "letter in proper block";

# The former example used SQLite's LIKE operator; now do the same with MATCH
# which gets translated to a Perl regex
$sql = "SELECT * FROM charinfo WHERE script='Greek' AND name MATCH 'SIGMA'";
$res = $dbh->selectall_arrayref($sql, {Slice => {}});
ok scalar(@$res),                        "found sigma letters";
is $res->[0]{block}, "Greek and Coptic", "letter in proper block";

# the following does not work because \b gets escaped as a literal
#$sql = "SELECT * FROM charinfo WHERE script='Greek' AND name MATCH '\\bSIGMA\\b'";


# but the following does work because the REGEXP operator is handled
# outside of the BEST_INDEX / FILTER methods
$sql = "SELECT * FROM charinfo WHERE script='Greek' AND name REGEXP '\\bSIGMA\\b'";
$res = $dbh->selectall_arrayref($sql, {Slice => {}});
ok scalar(@$res),                        "found sigma letters";
is $res->[0]{block}, "Greek and Coptic", "letter in proper block";
