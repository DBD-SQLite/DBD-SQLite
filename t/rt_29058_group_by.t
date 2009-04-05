use strict;

BEGIN {
    $|  = 1;
    $^W = 1;
}

use t::lib::Test;

use Test::More tests => 6;
use DBI;

my $dbh = connect_ok();
$dbh->do( 'CREATE TABLE foo (bar TEXT, num INT)' );

for (1..5) {
    $dbh->do('INSERT INTO foo (bar, num) VALUES (?,?)', undef, ($_%2 ? "odd" : "even"), $_);
}
# DBI->trace(9);

# see if placeholder works
my ($v, $num) = $dbh->selectrow_array('SELECT bar, num FROM foo WHERE num = ?', undef, 3);
ok $v eq 'odd' && $num == 3;

# see if the sql itself works as expected
my $ar = $dbh->selectall_arrayref('SELECT bar FROM foo GROUP BY bar HAVING count(*) > 1');
ok
ok @$ar == 2;

# known workaround
# ref: http://code.google.com/p/gears/issues/detail?id=163
$ar = $dbh->selectall_arrayref('SELECT bar FROM foo GROUP BY bar HAVING count(*) > 0+?', undef, 1);
ok @$ar == 2;

# and this is what should be tested
$ar = $dbh->selectall_arrayref('SELECT bar FROM foo GROUP BY bar HAVING count(*) > ?', undef, 1);
print "4: @$_\n" for @$ar;
ok @$ar == 2, "we got ".(@$ar)." items";
