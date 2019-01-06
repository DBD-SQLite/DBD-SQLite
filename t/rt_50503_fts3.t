use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;

BEGIN {
	requires_sqlite('3.6.6');
	plan skip_all => "FTS is disabled for this DBD::SQLite" unless has_fts();
}

use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok( RaiseError => 1, AutoCommit => 0 );

$dbh->do(<<EOF);
CREATE VIRTUAL TABLE incident_fts
USING fts3 (incident_id VARCHAR, all_text VARCHAR, TOKENIZE simple)
EOF
$dbh->commit;

insert_data($dbh, '595', time(), "sample text foo bar baz");
insert_data($dbh, '595', time(), "sample text foo bar baz");
insert_data($dbh, '595', time(), "sample text foo bar baz");
insert_data($dbh, '595', time(), "sample text foo bar baz");
$dbh->commit;

{
	my $sth = $dbh->prepare("SELECT * FROM incident_fts WHERE all_text MATCH 'bar'");
	$sth->execute();

	while (my $row = $sth->fetchrow_hashref("NAME_lc")) {
		# The result may vary with or without an output,
		# but anyway, either case seems failing at the destruction.
		ok %$row;
		#ok %$row, join ',', %$row;
	}
}

$dbh->commit;

sub insert_data {
	my($dbh, $inc_num, $date, $text) = @_;
	# "OR REPLACE" isn't standard SQL, but it sure is useful
	my $sth = $dbh->prepare('INSERT OR REPLACE INTO incident_fts (incident_id, all_text) VALUES (?, ?)');
	$sth->execute($inc_num, $text) || die "execute failed\n";
	$dbh->commit;
}

done_testing;
