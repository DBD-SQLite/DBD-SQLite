#!/usr/bin/perl

use strict;
my $INTMAX;
BEGIN {
	$|  = 1;
	$^W = 1;
	use Config;
	$INTMAX = (1 << ($Config{ivsize}*4-1)) - 1;
}
use t::lib::Test;
use Test::More tests => 7 + (2147483647 == $INTMAX ? 2 : 4);
use Test::NoWarnings;
use DBI qw(:sql_types);

my $dbh = connect_ok();

# testing results
sub intmax {
  my $intmax = shift;
  my ($statement, $sth, $result);
  $statement = "SELECT $intmax + 1";
  $sth = $dbh->prepare($statement);
  ok( $sth->execute, "execute: $statement" );
  $result = $sth->fetchrow_arrayref->[0];
  is( $result, $intmax + 1, "result: $result" );
}

intmax($INTMAX);
intmax(2147483647) if 2147483647 != $INTMAX;

# testing int column type, which should default to int(8) or int(4)
$dbh->do('drop table if exists artist');
$dbh->do(<<'END_SQL');
create table artist (
  id int not null,
  name text not null
)
END_SQL

$INTMAX = 2147483647;
my ($sth, $result);
ok( $dbh->do(qq/insert into artist (id,name) values($INTMAX+1, 'Leonardo')/), 'insert int INTMAX+1');
$sth = $dbh->prepare('select id from artist where name=?');
ok( $sth->execute('Leonardo'), 'bind to name' );
$result = $sth->fetchrow_arrayref->[0];
is( $result, $INTMAX+1, "result: $result" );

$sth = $dbh->prepare('select name from artist where id=?');
ok( $sth->execute($INTMAX+1), 'bind to INTMAX+1' );
$result = $sth->fetchrow_arrayref->[0];
is( $result, 'Leonardo', "result: $result" );
