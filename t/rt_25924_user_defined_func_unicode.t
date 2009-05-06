#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;
BEGIN {
	plan skip_all => 'requires DBI v1.608' if $DBI::VERSION < 1.608;

	if ( $] >= 5.008005 ) {
		plan( tests => 16 );
	} else {
		plan( skip_all => 'Unicode is not supported before 5.8.5' );
	}
}
use Test::NoWarnings;

eval "require utf8";
die $@ if $@;

my $dbh = connect_ok( unicode => 1 );
ok($dbh->sqlite_create_function( "perl_uc", 1, \&perl_uc ));

ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE' );
CREATE TABLE foo (
	bar varchar(255)
)
END_SQL

my @words = qw{Bergère hôte hétaïre hêtre};
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
