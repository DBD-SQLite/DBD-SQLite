use warnings;
use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

use DBI;

my @tests = qw(
  -2 -1 0 1 2

  -9223372036854775808
  -9223372036854775807
  -8694837494948124658
  -6848440844435891639
  -5664812265578554454
  -5380388020020483213
  -2564279463598428141
  2442753333597784273
  4790993557925631491
  6773854980030157393
  7627910776496326154
  8297530189347439311
  9223372036854775806
  9223372036854775807

  4294967295
  4294967296

  -4294967296
  -4294967295
  -4294967294

  -2147483649
  -2147483648
  -2147483647
  -2147483646

  2147483646
  2147483647
  2147483648
  2147483649
);

my $dbh = connect_ok();
$dbh->do('
  CREATE TABLE t (
    pk INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    int INTEGER,
    bigint BIGINT
  )
');

for my $val (@tests) {
  for my $col (qw(int bigint)) {
    for my $bindtype (undef, 'DBI::SQL_INTEGER', 'DBI::SQL_BIGINT') {

      my $tdesc = sprintf "value '%s' with %s bindtype on '%s' column",
        $val,
        $bindtype || 'no',
        $col
      ;

      my $sth = $dbh->prepare_cached(
        "INSERT INTO t ( $col ) VALUES ( ? )",
        {},
        3
      );

      my @w;
      local $SIG{__WARN__} = sub { push @w, @_ };

      ok (
        $sth->bind_param(1, $val, ( $bindtype and do { no strict 'refs'; &{$bindtype} } )),
        "Succesfully bound $tdesc",
      );
      is_deeply(
        \@w,
        [],
        "No warnings during bind of $tdesc",
      );

      ok (
        eval { $sth->execute ; 1 },
        "Succesfully inserted $tdesc" . ($@ ? ": $@" : ''),
      );
      is_deeply(
        \@w,
        [],
        "No warnings during insertion of $tdesc",
      );

      my $id;
      ok (
        $id = $dbh->last_insert_id(undef, undef, 't', 'pk'),
        "Got id $id of inserted $tdesc",
      );

      is_deeply(
        $dbh->selectall_arrayref("SELECT $col FROM t WHERE pk = $id"),
        [[ $val ]],
        "Proper roundtrip (insert/select) of $tdesc",
      );

    }
  }
}

done_testing;
