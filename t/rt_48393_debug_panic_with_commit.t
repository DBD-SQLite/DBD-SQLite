use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;

BEGIN {
	plan skip_all =>
		'set $ENV{TEST_DBD_SQLITE_WITH_DEBUGGER} '.
		'to enable this test'
		unless $ENV{TEST_DBD_SQLITE_WITH_DEBUGGER};
}

use if -d ".git", "Test::FailWarnings";

my $file = 't/panic.pl';
open my $fh, '>', $file;
print $fh <DATA>;
close $fh;

if ($^O eq 'MSWin32') {
	ok !system(qq{set PERLDB_OPTS="NonStop"; $^X -Mblib -d $file});
}
else {
	ok !system(qq{PERLDB_OPTS="NonStop" $^X -Mblib -d $file});
}

END {
	unlink $file if $file && -f $file;
	unlink 'test.db' if -f 'test.db';
}

done_testing;

__DATA__
use strict;
use warnings;
use DBI;

my $db_file = 'test.db';

unlink($db_file);
die "Could not delete $db_file - $!" if(-e $db_file);

my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", undef, undef, {
RaiseError => 1, AutoCommit => 1 });

$dbh->do('CREATE TABLE t1 (id int)');

$dbh->begin_work or die $dbh->errstr;

my $sth = $dbh->prepare('INSERT INTO t1 (id) VALUES (1)');
$sth->execute;

# XXX: Panic occurs here when running under the debugger
$dbh->commit or die $dbh->errstr;
