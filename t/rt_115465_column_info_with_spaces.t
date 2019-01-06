use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

{
	my $dbh = connect_ok();
	$dbh->do('create table test ( foo varchar(10), bar varchar( 15 ), baz decimal(3,3), bat decimal(4, 4))');
	my %info = map {
		$_->{COLUMN_NAME} => [@$_{qw/TYPE_NAME COLUMN_SIZE DECIMAL_DIGITS/}]
	} @{$dbh->column_info(undef, undef, 'test', '%')->fetchall_arrayref({})};

	is $info{foo}[0] => 'varchar';
	is $info{foo}[1] => '10';
	is $info{foo}[2] => undef;

	is $info{bar}[0] => 'varchar';
	is $info{bar}[1] => '15';
	is $info{bar}[2] => undef;

	is $info{baz}[0] => 'decimal';
	is $info{baz}[1] => 3;
	is $info{baz}[2] => 3;

	is $info{bat}[0] => 'decimal';
	is $info{bat}[1] => 4;
	is $info{bat}[2] => 4;
}

done_testing;
