use strict;

BEGIN {
    $|  = 1;
    $^W = 1;
}

use Test::More tests => 5;
use t::lib::Test;

my $dbh = connect_ok( RaiseError => 1, AutoCommit => 1 );

$dbh->do("CREATE TABLE f (f1, f2, f3)");

my $sth = $dbh->prepare_cached("SELECT f.f1, f.* FROM f");
ok($sth);

$dbh->do("ANALYZE"); # invalidate prepared statement handles

my $sth2 = $dbh->prepare_cached("SELECT f.f1, f.* FROM f");
ok($sth2);

my $ret = eval { $sth2->execute(); "ok" };
ok !$@;
is($ret, 'ok');
