#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;
use DBD::SQLite;
use Data::Dumper;

# NOTE: It seems to be better to compare rounded values
# because stored coordinate values may have slight errors
# since SQLite 3.7.13 (DBD::SQLite 1.38_01).

sub is_deeply_approx {
    my ($got, $expected, $name) = @_;
    my $got_approx      = [map { sprintf "%0.2f", $_ } @$got];
    my $expected_approx = [map { sprintf "%0.2f", $_ } @$expected];
    is_deeply($got_approx, $expected_approx, $name);
}

my @coords = (
   # id, minX, maxX, minY, maxY
    [1,  1,    200,  1,    200],  # outside bounding box
    [2,  25,   100,  25,   50],   
    [3,  50,   125,  40,   150],   
    [4,  25,   200,  125,  125],  # hor.  line
    [5,  100,  100,  75,   175],  # vert. line
    [6,  100,  100,  75,   75],   # point
    [7,  150,  175,  150,  175]
);

my @test_regions = (
   # minX, maxX, minY, maxY
    [75,   75,   45,   45],       # query point
    [10,   140,  10,   175],      # ... box
    [30,   100,  75,   75]        # ... hor. line
);

my @test_results = (
    # results for contains tests (what does this region contain?)
    [],
    [2, 3, 5, 6],
    [6],
    
    # results for overlaps tests (what does this region overlap with?)
    [1..3],
    [1..6],
    [1, 3, 5, 6]
);

BEGIN {
	if (!grep /ENABLE_RTREE/, DBD::SQLite::compile_options()) {
		plan skip_all => 'RTREE is disabled for this DBD::SQLite';
	}
}
use Test::NoWarnings;

plan tests => @coords + (2 * @test_regions)  + 4;

# connect
my $dbh = connect_ok( RaiseError => 1 );

# TODO: test rtree and rtree_i32 tables

# create R* Tree table
$dbh->do(<<"") or die DBI::errstr;
  CREATE VIRTUAL TABLE try_rtree
        USING rtree_i32(id, minX, maxX, minY, maxY);

# populate it
my $insert_sth = $dbh->prepare(<<"") or die DBI::errstr;
INSERT INTO try_rtree VALUES (?,?,?,?,?)

for my $coord (@coords) {
    ok $insert_sth->execute(@$coord);
}

# find by primary key
my $sql = "SELECT * FROM try_rtree WHERE id = ?";

my $idx = 0;
for my $id (1..2) {
    my $results = $dbh->selectrow_arrayref($sql, undef, $id);
    is_deeply_approx($results, $coords[$idx], "Coords for $id match");
    $idx++;
}

# find contained regions
my $contained_sql = <<"";
SELECT id FROM try_rtree
    WHERE  minX >= ? AND maxX <= ?
    AND    minY >= ? AND maxY <= ?

# Since SQLite 3.7.13, coordinate values may have slight errors.
for my $region (@test_regions) {
    my $results = $dbh->selectcol_arrayref($contained_sql, undef, @$region);
    is_deeply_approx($results, shift @test_results);
}

# find overlapping regions
my $overlap_sql = <<"";
SELECT id FROM try_rtree
   WHERE    maxX >= ? AND minX <= ?
   AND      maxY >= ? AND minY <= ?

for my $region (@test_regions) {
    my $results = $dbh->selectcol_arrayref($overlap_sql, undef, @$region);
    is_deeply_approx($results, shift @test_results);
}
