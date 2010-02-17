#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test     qw/connect_ok @CALL_FUNCS/;
use Test::More;
use Test::NoWarnings;

plan tests => 6;

use_ok('DBD::SQLite::sqlite3_h');
use_ok('DBD::SQLite::sqlite3_c');

my $header = DBD::SQLite::sqlite3_h->get;
like $header => qr/define _SQLITE3_H_/, 'got whole file';

my $hwtime_h = DBD::SQLite::sqlite3_c->get('hwtime.h');
like   $hwtime_h => qr/Begin file hwtime.h/, 'has Begin file';
unlike $hwtime_h => qr/Begin file [^h][^w]/, 'has no other Begin file';
