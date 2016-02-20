#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test     qw/connect_ok @CALL_FUNCS/;
use Test::More;
BEGIN {
	if ($] < 5.008005) {
		plan skip_all => 'Unicode is not supported before 5.8.5';
	}
}
use Test::NoWarnings;

# special case for multibyte (non-ASCII) character class,
# which only works correctly under the unicode mode
my @words = qw{ テスト テント };
my $regex = 'テ[スン]ト';


plan tests => 2 * 2 * @CALL_FUNCS + 1;

foreach my $call_func (@CALL_FUNCS) {

  for my $use_unicode (0, 1) {

    # connect
    my $dbh = connect_ok( RaiseError => 1, sqlite_unicode => $use_unicode );

    # populate test data
    my @vals = @words;
    my $re = $regex;
    if ($use_unicode) {
      utf8::decode($_) foreach @vals;
      utf8::decode($re);
    }

    $dbh->do( 'CREATE TEMP TABLE regexp_test ( txt )' );
    $dbh->do( "INSERT INTO regexp_test VALUES ( '$_' )" ) foreach @vals;

    my $sql = "SELECT txt from regexp_test WHERE txt REGEXP '$re' ";
    my $db_match = $dbh->selectcol_arrayref($sql);

    if ($use_unicode) {
      is @$db_match => 2;
      note explain $db_match;
    } else {
      is @$db_match => 0;
      note explain $db_match;
    }
  }
}

