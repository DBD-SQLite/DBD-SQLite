use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $sql_in_question = <<'EOS';
SELECT cdid
  FROM cd me
WHERE 2 > (
  SELECT COUNT( * )
    FROM cd rownum__emulation
  WHERE
    (
      me.genreid IS NOT NULL
        AND
      rownum__emulation.genreid IS NULL
    )
      OR
    (
      me.genreid IS NOT NULL
        AND
      rownum__emulation.genreid IS NOT NULL
        AND
      rownum__emulation.genreid < me.genreid
    )
      OR
    (
      ( me.genreid = rownum__emulation.genreid OR ( me.genreid IS NULL AND rownum__emulation.genreid IS NULL ) )
        AND
      rownum__emulation.cdid > me.cdid
    )
)
ORDER BY cdid
EOS

{ # With an index
  my $dbh = connect_ok();
  $dbh->do($_) for (
    'CREATE TABLE cd ( cdid INTEGER PRIMARY KEY NOT NULL, genreid integer )',
    'CREATE INDEX cd_idx_genreid ON cd (genreid)',
    'INSERT INTO cd  ( cdid, genreid ) VALUES
                   ( 1,    1 ),
                   ( 2, NULL ),
                   ( 3, NULL ),
                   ( 4, NULL ),
                   ( 5, NULL )
    ',
  );

  my $res = $dbh->selectall_arrayref($sql_in_question);

  is_deeply $res => [[4], [5]], "got the expected result with the index" or note explain $res;
}

{ # Without the index
  my $dbh = connect_ok();
  $dbh->do($_) for (
    'CREATE TABLE cd ( cdid INTEGER PRIMARY KEY NOT NULL, genreid integer )',
    'INSERT INTO cd  ( cdid, genreid ) VALUES
                   ( 1,    1 ),
                   ( 2, NULL ),
                   ( 3, NULL ),
                   ( 4, NULL ),
                   ( 5, NULL )
    ',
  );

  my $res = $dbh->selectall_arrayref($sql_in_question);

  is_deeply $res => [[4], [5]], "got the expected result without the index" or note explain $res;
}

done_testing;
