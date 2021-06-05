use strict;
use warnings;
no if $] >= 5.022, "warnings", "locale";
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my @words = qw{
	berger Bergère bergère Bergere
	HOT hôte 
	hétéroclite hétaïre hêtre héraut
	HAT hâter 
	fétu fête fève ferme
     };
my @regexes = qw(  ^b\\w+ (?i:^b\\w+) );

BEGIN { requires_unicode_support() }
BEGIN {
	# Sadly perl for windows (and probably sqlite, too) may hang
	# if the system locale doesn't support european languages.
	# en-us should be a safe default. if it doesn't work, use 'C'.
	if ( $^O eq 'MSWin32') {
		use POSIX 'locale_h';
		setlocale(LC_COLLATE, 'en-us');
	}
}
use locale;

use DBD::SQLite;
use DBD::SQLite::Constants ':dbd_sqlite_string_mode';

foreach my $call_func (@CALL_FUNCS) {

  for my $string_mode (DBD_SQLITE_STRING_MODE_BYTES, DBD_SQLITE_STRING_MODE_UNICODE_STRICT) {

    # connect
    my $dbh = connect_ok( RaiseError => 1, sqlite_string_mode => $string_mode );

    # The following tests are about ordering, so don't reverse!
    if ($dbh->selectrow_array('PRAGMA reverse_unordered_selects')) {
      $dbh->do('PRAGMA reverse_unordered_selects = OFF');
    }

    # populate test data
    my @vals = @words;
    if ($string_mode == DBD_SQLITE_STRING_MODE_BYTES) {
      utf8::upgrade($_) foreach @vals;
    }

    $dbh->do( 'CREATE TEMP TABLE regexp_test ( txt )' );
    $dbh->do( "INSERT INTO regexp_test VALUES ( '$_' )" ) foreach @vals;

    foreach my $regex (@regexes) {
      my @perl_match     = grep {/$regex/} @vals;
      my $sql = "SELECT txt from regexp_test WHERE txt REGEXP '$regex' "
              .                             "COLLATE perllocale";
      my $db_match = $dbh->selectcol_arrayref($sql);

      is_deeply(\@perl_match, $db_match, "REGEXP '$regex'");

      my @perl_antimatch = grep {!/$regex/} @vals;
      $sql =~ s/REGEXP/NOT REGEXP/;
      my $db_antimatch = $dbh->selectcol_arrayref($sql);
      is_deeply(\@perl_antimatch, $db_antimatch, "NOT REGEXP '$regex'");
    }

    # null
    {
      my $sql = "SELECT txt from regexp_test WHERE txt REGEXP NULL "
              .                             "COLLATE perllocale";
      my $db_match = $dbh->selectcol_arrayref($sql);

      is_deeply([], $db_match, "REGEXP NULL");

      $sql =~ s/REGEXP/NOT REGEXP/;
      my $db_antimatch = $dbh->selectcol_arrayref($sql);
      is_deeply([], $db_antimatch, "NOT REGEXP NULL");
    }
  }
}

done_testing;
