#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test qw/requires_sqlite/;
use Test::More;
use DBD::SQLite;

BEGIN { requires_sqlite('3.10.0'); }

use Test::NoWarnings;

plan tests => 13;

ok !DBD::SQLite::strlike("foo_bar", "FOO1BAR");
ok !DBD::SQLite::strlike("foo_bar", "FOO_BAR");
ok DBD::SQLite::strlike("foo\\_bar", "FOO1BAR", "\\");
ok !DBD::SQLite::strlike("foo\\_bar", "FOO_BAR", "\\");
ok DBD::SQLite::strlike("foo!_bar", "FOO1BAR", "!");
ok !DBD::SQLite::strlike("foo!_bar", "FOO_BAR", "!");
ok !DBD::SQLite::strlike("%foobar", "1FOOBAR");
ok !DBD::SQLite::strlike("%foobar", "%FOOBAR");
ok DBD::SQLite::strlike("\\%foobar", "1FOOBAR", "\\");
ok !DBD::SQLite::strlike("\\%foobar", "%FOOBAR", "\\");
ok DBD::SQLite::strlike("!%foobar", "1FOOBAR", "!");
ok !DBD::SQLite::strlike("!%foobar", "%FOOBAR", "!");
