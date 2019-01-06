use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok( RaiseError => 1, PrintError => 0 );
eval {
  $dbh->do('ssdfsdf sdf sd sdfsdfdsf sdfsdf');
};
ok($@, 'Statement 1 generated an error');
is( $DBI::err, 1, '$DBI::err ok' );
is( $DBI::errstr, 'near "ssdfsdf": syntax error', '$DBI::errstr ok' );

$dbh->do('create table testerror (a, b)');
$dbh->do('insert into testerror values (1, 2)');
$dbh->do('insert into testerror values (3, 4)');

$dbh->do('create unique index testerror_idx on testerror (a)');
eval {
  $dbh->do('insert into testerror values (1, 5)');
};
ok($@, 'Statement 2 generated an error');
is( $DBI::err, 19, '$DBI::err ok' );
like( $DBI::errstr, qr/column a is not unique|UNIQUE constraint failed/, '$DBI::errstr ok' );

done_testing;
