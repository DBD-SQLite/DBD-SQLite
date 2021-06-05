use strict;
use warnings;
use lib "t/lib";
use Time::HiRes qw/time/;
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";
use DBD::SQLite;
use DBD::SQLite::Constants ':dbd_sqlite_string_mode';

my @texts = ("il était une bergère",
             "qui gardait ses moutons",
             "elle fit un fromage",
             "du lait de ses moutons");

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


sub Unicode_Word_tokenizer { # see also: Search::Tokenizer
  return sub {
    my $string     = shift;
    my $regex      = qr/\p{Word}+/;
    my $term_index = 0;

    return sub {
      $string =~ /$regex/g or return; # either match, or no more token
      my $term  = $&;
      my $end   = pos $string; # $+[0] is much slower
      my $len   = length($term);
      my $start = $end - $len;
      return ($term, $len, $start, $end, $term_index++);
    };
  };
}

use DBD::SQLite;

for my $string_mode (DBD_SQLITE_STRING_MODE_BYTES, DBD_SQLITE_STRING_MODE_UNICODE_STRICT) {

  # connect
  my $dbh = connect_ok( RaiseError => 1, sqlite_string_mode => $string_mode );

  for my $fts (qw/fts3 fts4/) {
    next if $fts eq 'fts4' && !has_sqlite('3.7.4');

    # create fts table
    $dbh->do(<<"") or die DBI::errstr;
      CREATE VIRTUAL TABLE try_$fts
            USING $fts(content, tokenize=perl 'main::Unicode_Word_tokenizer')

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
        is_deeply($results, \@expected, "$query ($fts, string_mode=$string_mode)");
      }
    }

    # the 'snippet' function should highlight the words in the MATCH query
    my $sql_snip = "SELECT snippet(try_$fts) FROM try_$fts WHERE content MATCH ?";
    my $result = $dbh->selectcol_arrayref($sql_snip, undef, 'une');
    is_deeply($result, ['il était <b>une</b> bergère'], "snippet ($fts, string_mode=$string_mode)");

    # the 'offsets' function should return integer offsets for the words in the MATCH query
    my $sql_offsets = "SELECT offsets(try_$fts) FROM try_$fts WHERE content MATCH ?";
    $result = $dbh->selectcol_arrayref($sql_offsets, undef, 'une');
    my $offset_une = $string_mode == DBD_SQLITE_STRING_MODE_UNICODE_STRICT ? $ix_une_utf8 : $ix_une_native;
    my $expected_offsets = "0 0 $offset_une 3";
    is_deeply($result, [$expected_offsets], "offsets ($fts, string_mode=$string_mode)");

    # test snippet() on a longer sentence
    $insert_sth->execute(join " ", @texts);
    $result = $dbh->selectcol_arrayref($sql_snip, undef, '"bergère qui gardait"');
    like($result->[0],
         qr[une <b>bergère</b> <b>qui</b> <b>gardait</b> ses],
         "longer snippet ($fts, string_mode=$string_mode)");

    # simulated large document
    open my $fh, "<", $INC{'DBD/SQLite.pm'} or die $!;
    my $source_code = do {local $/; <$fh>};
    my $long_doc    = $source_code x 5;

    my $t0 = time;
    $insert_sth->execute($long_doc);
    my $t1 = time;
    $result = $dbh->selectcol_arrayref($sql_snip, undef, '"package DBD::SQLite"');
    my $t2 = time;

    note sprintf("long doc (%d chars): insert in %.4f secs, select in %.4f secs",
                 length($long_doc), $t1-$t0, $t2-$t1);
    like($result->[0], qr[^<b>package</b> <b>DBD</b>::<b>SQLite</b>;], 'snippet "package SQLite"');
  }
}

done_testing;
