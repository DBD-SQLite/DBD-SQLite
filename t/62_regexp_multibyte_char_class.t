use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
#use if -d ".git", "Test::FailWarnings"; # see RT#112220

BEGIN { requires_unicode_support() }

use DBD::SQLite::Constants ':dbd_sqlite_string_mode';

# special case for multibyte (non-ASCII) character class,
# which only works correctly under the unicode mode
my @words = ("\x{e3}\x{83}\x{86}\x{e3}\x{82}\x{b9}\x{e3}\x{83}\x{88}", "\x{e3}\x{83}\x{86}\x{e3}\x{83}\x{b3}\x{e3}\x{83}\x{88}"); # テスト テント

my $regex = "\x{e3}\x{83}\x{86}[\x{e3}\x{82}\x{b9}\x{e3}\x{83}\x{b3}]\x{e3}\x{83}\x{88}"; # テ[スン]ト

foreach my $call_func (@CALL_FUNCS) {

  for my $string_mode (DBD_SQLITE_STRING_MODE_PV, DBD_SQLITE_STRING_MODE_UNICODE_STRICT) {

    # connect
    my $dbh = connect_ok( RaiseError => 1, sqlite_string_mode => $string_mode );

    # populate test data
    my @vals = @words;
    my $re = $regex;
    if ($string_mode == DBD_SQLITE_STRING_MODE_UNICODE_STRICT) {
      utf8::decode($_) foreach @vals;
      utf8::decode($re);
    }
    my @perl_match = grep {$_ =~ /$re/} @vals;

    $dbh->do( 'CREATE TEMP TABLE regexp_test ( txt )' );
    $dbh->do( "INSERT INTO regexp_test VALUES ( '$_' )" ) foreach @vals;

    my $sql = "SELECT txt from regexp_test WHERE txt REGEXP '$re' ";
    my $db_match = $dbh->selectcol_arrayref($sql);

    is_deeply \@perl_match => $db_match;
    note explain \@perl_match;
    note explain $db_match;
  }
}

done_testing;
