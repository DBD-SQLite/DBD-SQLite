#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 11;
use t::lib::Test;

my $dbh = sqlite_connect( AutoCommit => 1 );

$dbh->do("CREATE TABLE f (f1, f2, f3)");
ok($dbh->do("delete from f"));
my $sth = $dbh->prepare("INSERT INTO f VALUES (?, ?, ?)", { go_last_insert_id_args => [undef, undef, undef, undef] });
ok($sth);
ok(my $rows = $sth->execute("Fred", "Bloggs", "fred\@bloggs.com"));
ok($rows == 1);

is($sth->execute("test", "test", "1"), 1);
is($sth->execute("test", "test", "2"), 1);
is($sth->execute("test", "test", "3"), 1);

SKIP: {
    skip( 'last_insert_id requires DBI v1.43', 2 ) if $DBI::VERSION < 1.43;
    is( $dbh->last_insert_id(undef, undef, undef, undef), 4 );
    is( $dbh->func('last_insert_rowid'), 4, 'last_insert_rowid should be 4' );
}

is( $dbh->do("delete from f where f1='test'"), 3 );
$sth->finish;
$dbh->disconnect;
