# This is a test for correct handling of upgraded strings without
# the sqlite_unicode parameter.

use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

{
    my $dbh = connect_ok(
        dbfile => 'foo',
        RaiseError => 1,
    );

    my $tbl_name = "\xe9p\xe9e";
    my $str = "CREATE TABLE $tbl_name ( col1 TEXT )";
    $dbh->do($str);

    $dbh->{'sqlite_unicode'} = 1;

    my @warnings;
    my $master_ar = do {
        local $SIG{'__WARN__'} = sub { push @warnings, @_ };
        $dbh->selectall_arrayref('SELECT * FROM sqlite_master', { Slice => {} });
    };

    for my $key ( sort keys %{ $master_ar->[0] } ) {
        ok(
            utf8::valid($master_ar->[0]{$key}),
            "$key is utf8::valid",
        );
    }

    is(
        $master_ar->[0]{'name'},
        $tbl_name,
        '`name`',
    );

    like(
        $warnings[0],
        qr<UTF-8>,
        'warning about invalid UTF-8',
    );
}

done_testing;
