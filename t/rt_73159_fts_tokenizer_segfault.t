use strict;
use warnings;
no if $] >= 5.022, "warnings", "locale";
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";
use DBI;

my $dbh = connect_ok(RaiseError => 1, PrintError => 0);

sub locale_tokenizer {
  return sub {
    my $string = shift;

    use locale;
    my $regex      = qr/\w+/;
    my $term_index = 0;

    return sub { # closure
      $string =~ /$regex/g or return; # either match, or no more token
      my ($start, $end) = ($-[0], $+[0]);
      my $len           = $end-$start;
      my $term          = substr($string, $start, $len);
      return ($term, $len, $start, $end, $term_index++);
    }
  };
}

# "main::locale_tokenizer" is considered as another column name
# because of the comma after "tokenize=perl"
eval {
  $dbh->do('CREATE VIRTUAL TABLE FIXMESSAGE USING FTS3(MESSAGE, tokenize=perl, "main::locale_tokenizer");');
};
ok $@, "cause an error but not segfault";

done_testing;
