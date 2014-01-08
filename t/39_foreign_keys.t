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

plan tests => 17;

# following tests are from http://www.sqlite.org/foreignkeys.html

my $dbh = connect_ok( RaiseError => 1, PrintError => 0, AutoCommit => 1 );

$dbh->do("PRAGMA foreign_keys = ON");

ok $dbh->do("CREATE TABLE artist (
    artistid    INTEGER PRIMARY KEY,
    artistname  TEXT
)");
ok $dbh->do("CREATE TABLE track (
    trackid     INTEGER PRIMARY KEY,
    trackname   TEXT,
    trackartist INTEGER,
    FOREIGN KEY(trackartist) REFERENCES artist(artistid)
)");

ok insert_artist(1, "Dean Martin");
ok insert_artist(2, "Frank Sinatra");

ok insert_track(11, "That's Amore", 1);
ok insert_track(12, "Christmas Blues", 1);
ok insert_track(13, "My Way", 2);

# This fails because the value inserted into the trackartist
# column (3) does not correspond to row in the artist table.

ok !insert_track(14, "Mr. Bojangles", 3);
ok $@ =~ qr/foreign key constraint failed/i;

# This succeeds because a NULL is inserted into trackartist. A
# corresponding row in the artist table is not required in this case.

ok insert_track(14, "Mr. Bojangles", undef);

# Trying to modify the trackartist field of the record after it has 
# been inserted does not work either, since the new value of 
# trackartist (3) still does not correspond to any row in the 
# artist table.

ok !update_track(3, "Mr. Bojangles");
ok $@ =~ /foreign key constraint failed/i;

# Insert the required row into the artist table. It is then possible
# to update the inserted row to set trackartist to 3 (since a
# corresponding row in the artist table now exists).

ok insert_artist(3, "Sammy Davis Jr.");
ok update_track(3, "Mr. Bojangles");

# Now that "Sammy Davis Jr." (artistid = 3) has been added to the
# database, it is possible to INSERT new tracks using this artist
# without violating the foreign key constraint:

ok insert_track(15, "Boogie Woogie", 3);

sub insert_artist { _do("INSERT INTO artist (artistid, artistname) VALUES (?, ?)", @_ ); }
sub insert_track {  _do("INSERT INTO track (trackid, trackname, trackartist) VALUES (?, ?, ?)", @_); }
sub update_track {  _do("UPDATE track SET trackartist = ? WHERE trackname = ?", @_); }

sub _do { eval { $dbh->do(shift, undef, @_) }; }
