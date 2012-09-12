#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;

BEGIN {
    use DBD::SQLite;
    unless ($DBD::SQLite::sqlite_version_number && $DBD::SQLite::sqlite_version_number >= 3006019) {
        plan skip_all => "this test requires SQLite 3.6.19 and newer";
        exit;
    }
}

use Test::NoWarnings;

# SQL below freely adapted from http://www.sqlite.org/foreignkeys.htm ...
# not the best datamodel in the world, but good enough for our tests.

my @sql_statements = split /\n\n/, <<__EOSQL__;
PRAGMA foreign_keys = ON;

CREATE TABLE artist (
  artistid    INTEGER,
  artistname  TEXT,
  UNIQUE(artistid)
);

CREATE TABLE editor (
  editorid    INTEGER PRIMARY KEY AUTOINCREMENT,
  editorname  TEXT
);

ATTACH DATABASE ':memory:' AS remote;

CREATE TABLE remote.album (
  albumartist INTEGER NOT NULL REFERENCES artist(artistid)
                                 ON DELETE RESTRICT
                                 ON UPDATE CASCADE,
  albumname TEXT,
  albumcover BINARY,
  albumeditor INTEGER NOT NULL REFERENCES editor(editorid),
  PRIMARY KEY(albumartist, albumname)
);

CREATE TABLE song(
  songid     INTEGER PRIMARY KEY AUTOINCREMENT,
  songartist INTEGER,
  songalbum  TEXT,
  songname   TEXT,
  FOREIGN KEY(songartist, songalbum) REFERENCES album(albumartist, albumname)
);
__EOSQL__


plan tests => @sql_statements + 20;

my $dbh = connect_ok( RaiseError => 1, PrintError => 0, AutoCommit => 1 );
my $sth;
my $fk_data;
my $R = \%DBD::SQLite::db::DBI_code_for_rule;

ok ($dbh->do($_), $_) foreach @sql_statements;

$sth = $dbh->foreign_key_info(undef, undef, undef,
                              undef, undef, 'album');
$fk_data = $sth->fetchall_hashref('FKCOLUMN_NAME');

for ($fk_data->{albumartist}) {
  is($_->{PKTABLE_NAME},  "artist"  ,   "FK albumartist, table name");
  is($_->{PKCOLUMN_NAME}, "artistid",   "FK albumartist, column name");
  is($_->{KEY_SEQ},        1,           "FK albumartist, key seq");
  is($_->{DELETE_RULE}, $R->{RESTRICT}, "FK albumartist, delete rule");
  is($_->{UPDATE_RULE}, $R->{CASCADE},  "FK albumartist, update rule");
  is($_->{UNIQUE_OR_PRIMARY}, 'UNIQUE', "FK albumartist, unique");
}
for ($fk_data->{albumeditor}) {
  is($_->{PKTABLE_NAME},  "editor",   "FK albumeditor, table name");
  is($_->{PKCOLUMN_NAME}, "editorid", "FK albumeditor, column name");
  is($_->{KEY_SEQ},        1,         "FK albumeditor, key seq");
  # rules are 'NO ACTION' by default
  is($_->{DELETE_RULE}, $R->{'NO ACTION'}, "FK albumeditor, delete rule");
  is($_->{UPDATE_RULE}, $R->{'NO ACTION'}, "FK albumeditor, update rule");
  is($_->{UNIQUE_OR_PRIMARY}, 'PRIMARY', "FK albumeditor, primary");
}


$sth = $dbh->foreign_key_info(undef, undef, 'artist',
                              undef, undef, 'album');
$fk_data = $sth->fetchall_hashref('FKCOLUMN_NAME');
is_deeply([keys %$fk_data], ['albumartist'], "FK album with PK, only 1 result");


$sth = $dbh->foreign_key_info(undef, undef, 'foobar',
                              undef, undef, 'album');
$fk_data = $sth->fetchall_hashref('FKCOLUMN_NAME');
is_deeply([keys %$fk_data], [], "FK album with PK foobar, 0 result");


$sth = $dbh->foreign_key_info(undef, undef, undef,
                              undef, 'remote', undef);
$fk_data = $sth->fetchall_hashref('FKCOLUMN_NAME');
is_deeply([sort keys %$fk_data], [qw/albumartist albumeditor/], "FK remote.*, 2 results");


$sth = $dbh->foreign_key_info(undef, 'remote', undef,
                              undef, undef, undef);
$fk_data = $sth->fetchall_hashref('FKCOLUMN_NAME');
is_deeply([sort keys %$fk_data], [qw/songalbum songartist/], "FK with PK remote.*, 2 results");


$sth = $dbh->foreign_key_info(undef, undef, undef,
                              undef, undef, 'song');
$fk_data = $sth->fetchall_hashref('FKCOLUMN_NAME');
for ($fk_data->{songartist}) {
  is($_->{KEY_SEQ}, 1, "FK song, key seq 1");
}
for ($fk_data->{songalbum}) {
  is($_->{KEY_SEQ}, 2, "FK song, key seq 2");
}
