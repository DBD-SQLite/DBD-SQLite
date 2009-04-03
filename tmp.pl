#!/use/bin/perl

use strict;
use warnings;

use DBI;

$ENV{PATH} = "/bin:/usr/sbin";

my $dbh = DBI->connect("DBI:SQLite:blah", "", "");
SCOPE: {
  my $sth = $dbh->do(q{DROP TABLE IF EXISTS t1});
  my $sth2 = $dbh->do(q{CREATE TABLE t1 (c1 text)});
  my $sth3 = $dbh->prepare(q{INSERT INTO t1 VALUES (?)});
  for my $i (1 .. 5) {
    $sth3->execute($i);
  }
  $sth3->finish();
}
$dbh->disconnect();

my @dbh;
for my $i (1 .. 2) {
  print "$i: before connect\n";
  print `lsof -p $$|grep test`;
  $dbh[$i] = DBI->connect("DBI:SQLite:blah", "", "");
  print "$i: after connect\n";
  print `lsof -p $$|grep test`;
#  {

    my $sth = $dbh[$i]->prepare(q{SELECT count(1) from t1});
    $sth->execute();
    my ($count) = $sth->fetchrow_array;
    print "count: $count\n";
    $sth->finish();

#  }
  $dbh[$i]->disconnect();
  print "$i: after disconnect\n";
  print `lsof -p $$|grep test`, "\n";
}
