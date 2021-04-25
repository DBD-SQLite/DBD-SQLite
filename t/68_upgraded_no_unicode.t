# This is a test for correct handling of upgraded strings without
# the sqlite_unicode parameter.

use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

{
    my $dbh = connect_ok( dbfile => 'foo', RaiseError => 1 );

    my $tbl_name = "\xe9p\xe9e";
    utf8::encode $tbl_name;

    my $str = "CREATE TABLE $tbl_name ( col1 TEXT )";
    utf8::upgrade $str;

    $dbh->do($str);

    my $master_ar = $dbh->selectall_arrayref('SELECT * FROM sqlite_master', { Slice => {} });

    is(
        $master_ar->[0]{'name'},
        $tbl_name,
        'do() takes correct string value',
    );

    #----------------------------------------------------------------------

    my $dummy_str = "SELECT '$tbl_name'";
    utf8::upgrade $dummy_str;

    my $sth = $dbh->prepare($dummy_str);
    $sth->execute();
    my $row = $sth->fetchrow_arrayref();

    is(
        $row->[0],
        $tbl_name,
        'prepare() takes correct string value',
    );

    #----------------------------------------------------------------------

    my $tbl_name_ug = $tbl_name;
    utf8::upgrade $tbl_name_ug;

    my $sth2 = $dbh->prepare('SELECT ?');
    $sth2->execute( do { my $v = $tbl_name_ug } );
    $row = $sth2->fetchrow_arrayref();

    is(
        $row->[0],
        $tbl_name,
        'execute() takes correct string value',
    );
}

done_testing;
