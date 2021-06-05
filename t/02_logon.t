# Tests basic login and pragma setting

use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok @CALL_FUNCS/;
use Test::More;
use if -d ".git", "Test::FailWarnings";

use DBD::SQLite::Constants ':dbd_sqlite_string_mode';

my $unicode_opt = DBD_SQLITE_STRING_MODE_UNICODE_STRICT;

my $show_diag = 0;
foreach my $call_func (@CALL_FUNCS) {

	# Ordinary connect
	SCOPE: {
		my $dbh = connect_ok();
		ok( $dbh->{sqlite_version}, '->{sqlite_version} ok' );
		is( $dbh->{AutoCommit}, 1, 'AutoCommit is on by default' );
		diag("sqlite_version=$dbh->{sqlite_version}") unless $show_diag++;
		ok( $dbh->$call_func('busy_timeout'), 'Found initial busy_timeout' );
		ok( $dbh->$call_func(5000, 'busy_timeout') );
		is( $dbh->$call_func('busy_timeout'), 5000, 'Set busy_timeout to new value' );

		ok( defined $dbh->$call_func(0, 'busy_timeout') );
		is( $dbh->$call_func('busy_timeout'), 0, 'Set busy_timeout to 0' );
	}

	# Attributes in the connect string
	SKIP: {
		unless ( $] >= 5.008005 ) {
			skip( 'Unicode is not supported before 5.8.5', 2 );
		}
		my $file = 'foo'.$$;
		my $dbh = DBI->connect( "dbi:SQLite:dbname=$file;sqlite_string_mode=$unicode_opt", '', '' );
		isa_ok( $dbh, 'DBI::db' );
		is( $dbh->{sqlite_string_mode}, $unicode_opt, 'Unicode is on' );
		$dbh->disconnect;
		unlink $file;
	}

	# dbname, db, database
	SCOPE: {
		for my $key (qw/database db dbname/) {
			my $file = 'foo'.$$;
			unlink $file if -f $file;
			ok !-f $file, 'database file does not exist';
			my $dbh = DBI->connect("dbi:SQLite:$key=$file");
			isa_ok( $dbh, 'DBI::db' );
			ok -f $file, "database file (specified by $key=$file) now exists";
			$dbh->disconnect;
			unlink $file;
		}
	}

	# Connect to a memory database
	SCOPE: {
		my $dbh = DBI->connect( 'dbi:SQLite:dbname=:memory:', '', '' );
		isa_ok( $dbh, 'DBI::db' );	
	}
}

done_testing;
