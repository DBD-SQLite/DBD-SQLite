use 5.00503;
use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok @CALL_FUNCS/;
use Test::More;
use if -d ".git", "Test::FailWarnings";
use DBD::SQLite;
use DBD::SQLite::Constants;
use Digest::MD5 qw/md5/;
use DBI qw/:sql_types/;

my @function_flags = (undef, 0);
if ($DBD::SQLite::sqlite_version_number >= 3008003) {
  push @function_flags, DBD::SQLite::Constants::SQLITE_DETERMINISTIC;
}

sub now {
    return time();
}

sub add2 {
    my ( $a, $b ) = @_;
    return $a + $b;
}

sub my_sum {
    my $sum = 0;
    foreach my $x (@_) {
        $sum += $x;
    }
    return $sum;
}

sub error {
    die "function is dying: ", @_, "\n";
}

sub void_return {
}

sub return2 {
    return ( 1, 2 );
}

sub return_null {
    return undef;
}

sub my_defined {
    defined($_[0]) ? 1 : 0;
}

sub noop {
    return $_[0];
}

sub md5_text {
    return md5($_[0]);
}

sub md5_blob {
    return [md5($_[0]), SQL_BLOB];
}

foreach my $call_func (@CALL_FUNCS) { for my $flags (@function_flags) {
	my $dbh = connect_ok( PrintError => 0 );

	ok($dbh->$call_func( "now", 0, \&now, defined $flags ? $flags : (), "create_function" ));
	my $result = $dbh->selectrow_arrayref( "SELECT now()" );

	ok( $result->[0], 'Got a result' );

	$dbh->do( 'CREATE TEMP TABLE func_test ( a, b )' );
	$dbh->do( 'INSERT INTO func_test VALUES ( 1, 3 )' );
	$dbh->do( 'INSERT INTO func_test VALUES ( 0, 4 )' );

	ok($dbh->$call_func( "add2", 2, \&add2, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT add2(1,3)" );
	is($result->[0], 4, "SELECT add2(1,3)" );

	$result = $dbh->selectall_arrayref( "SELECT add2(a,b) FROM func_test" );
	is_deeply( $result, [ [4], [4] ], "SELECT add2(a,b) FROM func_test" );

	ok($dbh->$call_func( "my_sum", -1, \&my_sum, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT my_sum( '2', 3, 4, '5')" );
	is( $result->[0], 14, "SELECT my_sum( '2', 3, 4, '5')" );

	ok($dbh->$call_func( "error", -1, \&error, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT error( 'I died' )" );
	ok( !$result );
	like( $DBI::errstr, qr/function is dying: I died/ );

	ok($dbh->$call_func( "void_return", -1, \&void_return, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT void_return( 'I died' )" );
	is_deeply( $result, [ undef ], "SELECT void_return( 'I died' )" );

	ok($dbh->$call_func( "return_null", -1, \&return_null, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT return_null()" );
	is_deeply( $result, [ undef ], "SELECT return_null()" );

	ok($dbh->$call_func( "return2", -1, \&return2, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT return2()" );
	is_deeply( $result, [ 2 ], "SELECT return2()" );

	ok($dbh->$call_func( "my_defined", 1, \&my_defined, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT my_defined(1)" );
	is_deeply( $result, [ 1 ], "SELECT my_defined(1)" );

	$result = $dbh->selectrow_arrayref( "SELECT my_defined('')" );
	is_deeply( $result, [ 1 ], "SELECT my_defined('')" );

	$result = $dbh->selectrow_arrayref( "SELECT my_defined('abc')" );
	is_deeply( $result, [ 1 ], "SELECT my_defined('abc')" );

	$result = $dbh->selectrow_arrayref( "SELECT my_defined(NULL)" );
	is_deeply( $result, [ '0' ], "SELECT my_defined(NULL)" );

	ok($dbh->$call_func( "noop", 1, \&noop, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT noop(NULL)" );
	is_deeply( $result, [ undef ], "SELECT noop(NULL)" );

	$result = $dbh->selectrow_arrayref( "SELECT noop(1)" );
	is_deeply( $result, [ 1 ], "SELECT noop(1)" );

	$result = $dbh->selectrow_arrayref( "SELECT noop('')" );
	is_deeply( $result, [ '' ], "SELECT noop('')" );

	$result = $dbh->selectrow_arrayref( "SELECT noop(1.0625)" );
	is_deeply( $result, [ 1.0625 ], "SELECT noop(1.0625)" );

	# 2147483648 == 1<<31
	$result = $dbh->selectrow_arrayref( "SELECT noop(2147483648)" );
	is_deeply( $result, [ 2147483648 ], "SELECT noop(2147483648)" );

	$result = $dbh->selectrow_arrayref( "SELECT typeof(noop(2147483648))" );
	is_deeply( $result, [ 'integer' ], "SELECT typeof(noop(2147483648))" );

	ok($dbh->$call_func( "md5_text", 1, \&md5_text, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT md5_text('my_blob')" );
	is_deeply( $result, [ md5('my_blob') ], "SELECT md5_text('my_blob')" );

	$result = $dbh->selectrow_arrayref( "SELECT typeof(md5_text('my_blob'))" );
	is_deeply( $result, [ 'text' ], "SELECT typeof(md5_text('my_blob'))" );

	ok($dbh->$call_func( "md5_blob", 1, \&md5_blob, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT md5_blob('my_blob')" );
	is_deeply( $result, [ md5('my_blob') ], "SELECT md5_blob('my_blob')" );

	$result = $dbh->selectrow_arrayref( "SELECT typeof(md5_blob('my_blob'))" );
	is_deeply( $result, [ 'blob' ], "SELECT typeof(md5_blob('my_blob'))" );

	ok($dbh->$call_func( "md5_blob", 1, undef, defined $flags ? $flags : (), "create_function" ));
	$result = $dbh->selectrow_arrayref( "SELECT md5_blob('my_blob')" );
	is_deeply( $result, undef, "SELECT md5_blob('my_blob')" );

	$dbh->disconnect;
}}

done_testing;
