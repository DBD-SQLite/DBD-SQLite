use strict;
use warnings;
my @to_be_tested;
BEGIN { @to_be_tested = (1.23E4); }

use Test::More;
use lib "t/lib";
use SQLiteTest;
use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok();

ok( $dbh->do("CREATE TABLE f (id, num)"), 'CREATE TABLE f' );

SCOPE: {
    my $sth = $dbh->prepare("INSERT INTO f VALUES (?, ?)");
    for(my $id = 0; $id < @to_be_tested; $id++) {
        $sth->execute($id, $to_be_tested[$id]);
        my $av = $dbh->selectrow_arrayref("SELECT num FROM f WHERE id = ?", {}, $id);
        ok( (@$av && $av->[0] == $to_be_tested[$id]), "accepts $to_be_tested[$id]: ".$av->[0]);
    }
}

done_testing;
