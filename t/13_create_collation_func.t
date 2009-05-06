#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;
BEGIN {
	if ( $] >= 5.008005 ) {
		plan( tests => 11 );
	} else {
		plan( skip_all => 'Unicode is not supported before 5.8.5' );
	}
}
use Test::NoWarnings;
use Encode qw/decode/;

BEGIN {
	# Sadly perl for windows (and probably sqlite, too) may hang
	# if the system locale doesn't support european languages.
	# en-us should be a safe default. if it doesn't work, use 'C'.
	if ( $^O eq 'MSWin32') {
		use POSIX 'locale_h';
		setlocale(LC_COLLATE, 'en-us');
	}
}

my @words = qw{
	berger Bergère bergère Bergere
	HOT hôte 
	hétéroclite hétaïre hêtre héraut
	HAT hâter 
	fétu fête fève ferme
};

my @words_utf8 = @words;
utf8::upgrade($_) foreach @words_utf8;

$" = ", "; # to embed arrays into message strings

my $dbh;
my @sorted;
my $db_sorted;
my $sql = "SELECT txt from collate_test ORDER BY txt";

sub no_accents ($$) {
	my ( $a, $b ) = map lc, @_;
	tr[àâáäåãçðèêéëìîíïñòôóöõøùûúüý]
	  [aaaaaacdeeeeiiiinoooooouuuuy] for $a, $b;
	$a cmp $b;
}

$dbh = connect_ok( RaiseError => 1 );

ok($dbh->func( "no_accents", \&no_accents, "create_collation" ));

$dbh->do( 'CREATE TEMP TABLE collate_test ( txt )' );
$dbh->do( "INSERT INTO collate_test VALUES ( '$_' )" ) foreach @words;

@sorted    = sort @words;
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE perl");
is_deeply(\@sorted, $db_sorted, "collate perl (@sorted // @$db_sorted)");

SCOPE: {
	use locale;
	@sorted = sort @words;
}
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE perllocale");
is_deeply(\@sorted, $db_sorted, "collate perllocale (@sorted // @$db_sorted)");

@sorted    = sort no_accents @words;
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE no_accents");
is_deeply(\@sorted, $db_sorted, "collate no_accents (@sorted // @$db_sorted)");
$dbh->disconnect;

$dbh = connect_ok( RaiseError => 1, unicode => 1 );
ok($dbh->func( "no_accents", \&no_accents, "create_collation" ));
$dbh->do( 'CREATE TEMP TABLE collate_test ( txt )' );
$dbh->do( "INSERT INTO collate_test VALUES ( '$_' )" ) foreach @words_utf8;

@sorted    = sort @words_utf8;
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE perl");
is_deeply(\@sorted, $db_sorted, "collate perl (@sorted // @$db_sorted)");

SCOPE: {
	use locale;
	@sorted = sort @words_utf8;
}
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE perllocale");
is_deeply(\@sorted, $db_sorted, "collate perllocale (@sorted // @$db_sorted)");

@sorted    = sort no_accents @words_utf8;
$db_sorted = $dbh->selectcol_arrayref("$sql COLLATE no_accents");
is_deeply(\@sorted, $db_sorted, "collate no_accents (@sorted // @$db_sorted)");
