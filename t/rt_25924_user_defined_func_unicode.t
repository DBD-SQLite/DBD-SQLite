#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 14;
use t::lib::Test;

my $dbh = connect_ok();
$dbh->{unicode} = 1;

$dbh->func( "perl_uc", 1, \&perl_uc, "create_function" );


my @words = qw{Bergère hôte hétaïre hêtre};


ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE' );
CREATE TABLE foo (
    bar varchar(255)
)
END_SQL

foreach my $word (@words) {
  utf8::upgrade($word);
  ok( $dbh->do("INSERT INTO foo VALUES ( ? )", {}, $word), 'INSERT' );
  my $foo = $dbh->selectall_arrayref("SELECT perl_uc(bar) FROM foo");
  is_deeply( $foo, [ [ perl_uc($word) ] ], 'unicode upcase ok' );
  ok( $dbh->do("DELETE FROM foo"), 'DELETE ok' );
}



sub perl_uc {
  my $string = shift;
  return uc($string);
}
