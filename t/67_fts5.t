use strict;
use warnings;
no if $] >= 5.022, "warnings", "locale";
use lib "t/lib";
use SQLiteTest;
use Test::More;
#use if -d ".git", "Test::FailWarnings";
use DBD::SQLite;
use utf8; # our source code is UTF-8 encoded

my @texts = ("il était une bergère",
             "qui gardait ses moutons",
             "elle fit un fromage",
             "du lait de ses moutons",
	     "anrechenbare quellensteuer hier");

my @tests = (
#  query                  => expected results
  ["bergère"              => 0       ],
  ["berg*"                => 0       ],
  ["foobar"                          ],
  ["moutons"              => 1, 3    ],
  ['"qui gardait"'        => 1       ],
  ["moutons NOT lait"     => 1       ],
  ["il était"             => 0       ],
  ["(il OR elle) AND un*" => 0, 2    ],
  ["anrechenbare"         => 4       ],
);

BEGIN {
	requires_unicode_support();

	if (!has_fts()) {
		plan skip_all => 'FTS is disabled for this DBD::SQLite';
	}
	if ($DBD::SQLite::sqlite_version_number >= 3011000 and $DBD::SQLite::sqlite_version_number < 3012000 and !has_compile_option('ENABLE_FTS5_TOKENIZER')) {
		plan skip_all => 'FTS5 tokenizer is disabled for this DBD::SQLite';
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

use DBD::SQLite::Constants ':fts5_tokenizer';

use locale;

sub locale_tokenizer { # see also: Search::Tokenizer
  return sub {
    my( $ctx, $string, $tokenizer_context_flags ) = @_;
    my $regex      = qr/\w+/;
    #my $term_index = 0;
    #
    while( $string =~ /$regex/g) {
      my ($start, $end) = ($-[0], $+[0]);
      my $term = substr($string, $start, my $len = $end-$start);
      my $flags = 0;
      #my $flags = FTS5_TOKEN_COLOCATED;
      DBD::SQLite::db::fts5_xToken($ctx,$flags,$term,$start,$end);
    };
  };
}

for my $use_unicode (0, 1) {

  # connect
  my $dbh = connect_ok( RaiseError => 1, sqlite_unicode => $use_unicode );

  for my $fts (qw/fts5/) {

    # create fts table
    $dbh->do(<<"") or die DBI::errstr;
      CREATE VIRTUAL TABLE try_$fts
            USING $fts(content, tokenize="perl 'main::locale_tokenizer'")

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
      my $sql = "SELECT rowid FROM try_$fts WHERE content MATCH ?";

      for my $t (@tests) {
        my ($query, @expected) = @$t;
        @expected = map {$doc_ids[$_]} @expected;
        my $results = $dbh->selectcol_arrayref($sql, undef, $query);
        is_deeply($results, \@expected, "$query ($fts, unicode=$use_unicode)");
      }
    }
  }
}

done_testing;
