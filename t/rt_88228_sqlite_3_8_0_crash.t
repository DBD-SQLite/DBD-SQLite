#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More tests => 3;
use Test::NoWarnings;

my $dbh = connect_ok();

$dbh->do($_) for (

  'CREATE TABLE "twokeys" (
    "artist" integer NOT NULL,
    "cd" integer NOT NULL,
    PRIMARY KEY ("artist", "cd")
  )',

  'CREATE TABLE "fourkeys" (
    "foo" integer NOT NULL,
    "bar" integer NOT NULL,
    "hello" integer NOT NULL,
    "goodbye" integer NOT NULL,
    "sensors" character(10) NOT NULL,
    "read_count" int,
    PRIMARY KEY ("foo", "bar", "hello", "goodbye")
  )',

  'CREATE TABLE "fourkeys_to_twokeys" (
    "f_foo" integer NOT NULL,
    "f_bar" integer NOT NULL,
    "f_hello" integer NOT NULL,
    "f_goodbye" integer NOT NULL,
    "t_artist" integer NOT NULL,
    "t_cd" integer NOT NULL,
    "autopilot" character NOT NULL,
    "pilot_sequence" integer,
    PRIMARY KEY ("f_foo", "f_bar", "f_hello", "f_goodbye", "t_artist", "t_cd")
  )',

  'INSERT INTO fourkeys ( bar, foo, goodbye, hello, read_count, sensors) VALUES ( 1, 1, 1, 1, 1, 1 )',
  'INSERT INTO twokeys ( artist, cd) VALUES ( 1, 1 )',
  'INSERT INTO fourkeys_to_twokeys ( autopilot, f_bar, f_foo, f_goodbye, f_hello, pilot_sequence, t_artist, t_cd) VALUES ( 1, 1, 1, 1, 1, 1, 1, 1 )',
  'DELETE FROM fourkeys_to_twokeys WHERE f_bar = 1 AND f_foo = 1 AND f_goodbye = 1 AND f_hello = 1 AND t_artist = 1 AND t_cd = 1'
);

pass "all done without segfault";
