# This is a test for correct handling of BLOBS; namely $dbh->quote
# is expected to work correctly.

use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";
use DBI ':sql_types';

sub ShowBlob($) {
    my ($blob) = @_;
    print("showblob length: ", length($blob), "\n");
    if ($ENV{SHOW_BLOBS}) { open(OUT, ">>$ENV{SHOW_BLOBS}") }
    my $i = 0;
    while (1) {
	if (defined($blob)  &&  length($blob) > ($i*32)) {
	    $b = substr($blob, $i*32);
	} else {
	    $b = "";
            last;
	}
        if ($ENV{SHOW_BLOBS}) { printf OUT "%08lx %s\n", $i*32, unpack("H64", $b) }
        else { printf("%08lx %s\n", $i*32, unpack("H64", $b)) }
        $i++;
        last if $i == 8;
    }
    if ($ENV{SHOW_BLOBS}) { close(OUT) }
}

# Create a database
my $dbh = connect_ok();
$dbh->{sqlite_handle_binary_nulls} = 1;

# Create the table
ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE' );
CREATE TABLE one (
    id INTEGER NOT NULL,
    name BLOB (128)
)
END_SQL

# Create a blob
my $blob = '';
my $b    = '';
for ( my $j = 0;  $j < 256; $j++ ) {
	$b .= chr($j);
}
for ( my $i = 0;  $i < 128; $i++ ) {
	$blob .= $b;
}

# Insert a row into the test table
SCOPE: {
	my $sth = $dbh->prepare("INSERT INTO one VALUES ( ?, ? )");
	isa_ok( $sth, 'DBI::st' );
	ok( $sth->bind_param(1, 1), '->bind_param' );
	ok( $sth->bind_param(2, $blob, SQL_BLOB), '->bind_param' );
	ok( $sth->execute, '->execute' );

	ok( $sth->bind_param(1, 2), '->bind_param' );
	ok( $sth->bind_param(2, '', SQL_BLOB), '->bind_param' );
	ok( $sth->execute, '->execute' );

	ok( $sth->bind_param(1, 3), '->bind_param' );
	ok( $sth->bind_param(2, undef, SQL_BLOB), '->bind_param' );
	ok( $sth->execute, '->execute' );

    ok my $quoted_blob = $dbh->quote($blob, SQL_BLOB);
	ok( $dbh->do("INSERT INTO one VALUES( 4, $quoted_blob )"), 'insert quoted blob' );
    ok my $quoted_empty = $dbh->quote('', SQL_BLOB);
	ok( $dbh->do("INSERT INTO one VALUES( 5, $quoted_empty )"), 'insert quoted empty string' );
    ok my $quoted_undef = $dbh->quote(undef, SQL_BLOB);
	ok( $dbh->do("INSERT INTO one VALUES( 6, $quoted_undef )"), 'insert quoted undef' );


	ok my $quoted_bit = $dbh->quote($blob, SQL_BIT);
	ok( $dbh->do("INSERT INTO one VALUES( 7, $quoted_bit )"), 'insert quoted bit' );

	ok my $quoted_binary = $dbh->quote($blob, SQL_BINARY);
	ok( $dbh->do("INSERT INTO one VALUES( 8, $quoted_binary )"), 'insert quoted binary' );

	ok my $quoted_varbinary = $dbh->quote($blob, SQL_VARBINARY);
	ok( $dbh->do("INSERT INTO one VALUES( 9, $quoted_varbinary )"), 'insert quoted varbinary' );

	ok my $quoted_longvarbinary = $dbh->quote($blob, SQL_LONGVARBINARY);
	ok( $dbh->do("INSERT INTO one VALUES( 10, $quoted_longvarbinary )"), 'insert quoted longvarbinary' );
}

# Now, try SELECT'ing the row out.
SCOPE: {
	my $sth = $dbh->prepare("SELECT * FROM one ORDER BY id");
	isa_ok( $sth, 'DBI::st' );
	ok( $sth->execute, '->execute' );
	my $rows = $sth->fetchall_arrayref;
	is_deeply( $rows, [
		[ 1, $blob ],
		[ 2, '' ],
		[ 3, undef ],
		[ 4, $blob ],
		[ 5, '' ],
		[ 6, undef ],
		[ 7, $blob ],
		[ 8, $blob ],
		[ 9, $blob ],
		[ 10, $blob ],
	], 'Got the blob back ok' );
	ok( $sth->finish, '->finish' );
}

done_testing;
