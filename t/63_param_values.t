#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use lib "t/lib";
use SQLiteTest qw/connect_ok/;
use Test::More;
use Test::NoWarnings;

plan tests => 7;

my $dbh = connect_ok( RaiseError => 1 );
ok $dbh->do('create table foo (id integer, value integer)');
{
    my $sth = $dbh->prepare('select * from foo where id = ?');
    $sth->execute(100);
    is_deeply $sth->{ParamValues} => {1 => 100}, "ParamValues after execution";
}
{
    my $sth = $dbh->prepare('select * from foo where id = :AAA');
    $sth->execute(100);
    is_deeply $sth->{ParamValues} => {':AAA' => 100}, "ParamValues after execution (named parameter)";
}
{
    my $sth = $dbh->prepare('select * from foo where id = ?');
    $sth->bind_param(1, 100);
    is_deeply $sth->{ParamValues} => {1 => 100}, "ParamValues before execution";
}
{
    my $sth = $dbh->prepare('select * from foo where id = ?');
    is_deeply $sth->{ParamValues} => {1 => undef}, "ParamValues without binding";
}
