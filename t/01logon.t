use strict;
use Test::More;
BEGIN { plan tests => 5 }
use DBI;
my $dbh = DBI->connect("dbi:SQLite:dbname=foo", "", "");
ok($dbh);
ok($dbh->{sqlite_version});
print "# sqlite_version=$dbh->{sqlite_version}\n";
ok($dbh->func('busy_timeout'));
print "# sqlite_busy_timeout=", $dbh->func('busy_timeout'), "\n";
ok($dbh->func(5000, 'busy_timeout'));
is($dbh->func('busy_timeout'), 5000);
print "# sqlite_busy_timeout=", $dbh->func('busy_timeout'), "\n";
$dbh->disconnect;

END { unlink 'foo' }
