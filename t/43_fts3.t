use strict;
use warnings;
no if $] >= 5.022, "warnings", "locale";
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";
use DBD::SQLite;

my @texts = ("il �tait une berg�re",
             "qui gardait ses moutons",
             "elle fit un fromage",
             "du lait de ses moutons");

my @tests = (
#  query                  => expected results
  ["berg�re"              => 0       ],
  ["berg*"                => 0       ],
  ["foobar"                          ],
  ["moutons"              => 1, 3    ],
  ['"qui gardait"'        => 1       ],
  ["moutons NOT lait"     => 1       ],
  ["il �tait"             => 0       ],
  ["(il OR elle) AND un*" => 0, 2    ],
);



my $ix_une_native = index($texts[0], "une");
my $ix_une_utf8   = do {use bytes; utf8::upgrade(my $bergere_utf8 = $texts[0]); index($bergere_utf8, "une");};



BEGIN {
	requires_unicode_support();

	if (!has_fts()) {
		plan skip_all => 'FTS is disabled for this DBD::SQLite';
	}
	if ($DBD::SQLite::sqlite_version_number >= 3011000 and $DBD::SQLite::sqlite_version_number < 3012000 and !has_compile_option('ENABLE_FTS3_TOKENIZER')) {
		plan skip_all => 'FTS3 tokenizer is disabled for this DBD::SQLite';
	}
}

# Perl may spit a warning on locale
# use Test::NoWarnings;

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

sub locale_tokenizer { # see also: Search::Tokenizer
  return sub {
    my $string = shift;
    my $regex      = qr/\w+/;
    my $term_index = 0;

    return sub {
      $string =~ /$regex/g or return; # either match, or no more token
      my ($start, $end) = ($-[0], $+[0]);
      my $term = substr($string, $start, my $len = $end-$start);
      return ($term, $len, $start, $end, $term_index++);
    };
  };
}

use DBD::SQLite;

for my $use_unicode (0, 1) {

  # connect
  my $dbh = connect_ok( RaiseError => 1, sqlite_unicode => $use_unicode );

  for my $fts (qw/fts3 fts4/) {
    next if $fts eq 'fts4' && !has_sqlite('3.7.4');

    # create fts table
    $dbh->do(<<"") or die DBI::errstr;
      CREATE VIRTUAL TABLE try_$fts
            USING $fts(content, tokenize=perl 'main::locale_tokenizer')

    # populate it
    my $insert_sth = $dbh->prepare(<<"") or die DBI::errstr;
      INSERT INTO try_$fts(content) VALUES(?)

    my @doc_ids;
    for (my $i = 0; $i < @texts; $i++) {
      $insert_sth->execute($texts[$i]);
      $doc_ids[$i] = $dbh->last_insert_id("", "", "", "");
    }

    # queries
  SKIP: {
      skip "These tests require SQLite compiled with "
         . "ENABLE_FTS3_PARENTHESIS option", scalar @tests
        unless has_compile_option('ENABLE_FTS3_PARENTHESIS');

      my $sql = "SELECT docid FROM try_$fts WHERE content MATCH ?";

      for my $t (@tests) {
        my ($query, @expected) = @$t;
        @expected = map {$doc_ids[$_]} @expected;
        my $results = $dbh->selectcol_arrayref($sql, undef, $query);
        is_deeply($results, \@expected, "$query ($fts, unicode=$use_unicode)");
      }
    }


    # the 'snippet' function should highlight the words in the MATCH query
    my $sql_snip = "SELECT snippet(try_$fts) FROM try_$fts WHERE content MATCH ?";
    my $result = $dbh->selectcol_arrayref($sql_snip, undef, 'une');
    is_deeply($result, ['il �tait <b>une</b> berg�re'], "snippet ($fts, unicode=$use_unicode)");

    # the 'offsets' function should return integer offstes for the words in the MATCH query
    my $sql_offsets = "SELECT offsets(try_$fts) FROM try_$fts WHERE content MATCH ?";
    $result = $dbh->selectcol_arrayref($sql_offsets, undef, 'une');
    my $offset_une = $use_unicode ? $ix_une_utf8 : $ix_une_native;
    my $expected_offsets = "0 0 $offset_une 3";
    is_deeply($result, [$expected_offsets], "offsets ($fts, unicode=$use_unicode)");
  }
}

done_testing;
