use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

use DBD::SQLite::Constants ':dbd_sqlite_string_mode';

my $unicode_opt = DBD_SQLITE_STRING_MODE_UNICODE_STRICT;

BEGIN { requires_unicode_support() }

foreach my $call_func (@CALL_FUNCS) {
	my $dbh = connect_ok( sqlite_string_mode => $unicode_opt );
	ok($dbh->$call_func( "perl_uc", 1, \&perl_uc, "create_function" ));

	ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE' );
CREATE TABLE foo (
	bar varchar(255)
)
END_SQL

	my @words = qw{Bergère hôte hétaïre hêtre};
	foreach my $word (@words) {
		# rt48048: don't need to "use utf8" nor "require utf8"
		utf8::upgrade($word);
		ok( $dbh->do("INSERT INTO foo VALUES ( ? )", {}, $word), 'INSERT' );
		my $foo = $dbh->selectall_arrayref("SELECT perl_uc(bar) FROM foo");
		is_deeply( $foo, [ [ perl_uc($word) ] ], 'unicode upcase ok' );
		ok( $dbh->do("DELETE FROM foo"), 'DELETE ok' );
	}
	$dbh->disconnect;
}

sub perl_uc {
	my $string = shift;
	return uc($string);
}

done_testing;
