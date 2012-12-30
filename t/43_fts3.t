#!/usr/bin/perl
use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test     qw/connect_ok/;
use Test::More;
use DBD::SQLite;

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

BEGIN {
	if ($] < 5.008005) {
		plan skip_all => 'Unicode is not supported before 5.8.5';
	}
	if (!grep /ENABLE_FTS3/, DBD::SQLite::compile_options()) {
		plan skip_all => 'FTS3 is disabled for this DBD::SQLite';
	}
}
use Test::NoWarnings;

plan tests => 4 * @tests  # each test with unicode y/n and with fts3/fts4
            + 2           # connect_ok with unicode y/n
            + 1;          # Test::NoWarnings

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
        unless DBD::SQLite->can('compile_options') &&
        grep /ENABLE_FTS3_PARENTHESIS/, DBD::SQLite::compile_options();
      my $sql = "SELECT docid FROM try_$fts WHERE content MATCH ?";
      for my $t (@tests) {
        my ($query, @expected) = @$t;
        @expected = map {$doc_ids[$_]} @expected;
        my $results = $dbh->selectcol_arrayref($sql, undef, $query);
        is_deeply($results, \@expected, "$query ($fts, unicode=$use_unicode)");
      }
    }
  }
}


