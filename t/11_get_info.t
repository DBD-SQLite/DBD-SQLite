use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

use DBI::Const::GetInfoType;

# NOTE: These are tests for just a very basic set of get_info variables.

my %info = (
    SQL_CATALOG_LOCATION       => 1,
    SQL_CATALOG_NAME           => 'Y',
    SQL_CATALOG_NAME_SEPARATOR => '.',
    SQL_CATALOG_TERM           => 'database',

    # some of these are dynamic, but always the same for connect_ok
    SQL_DATA_SOURCE_NAME       => qr/^dbi:SQLite:dbname=/,
    SQL_DATA_SOURCE_READ_ONLY  => 'N',
    SQL_DATABASE_NAME          => 'main',
    SQL_DBMS_NAME              => 'SQLite',
    SQL_DBMS_VER               => qr/^[1-9]+\.\d+\.\d+$/,

    SQL_IDENTIFIER_QUOTE_CHAR  => '"',

    SQL_MAX_IDENTIFIER_LEN     => qr/^[1-9]\d+$/,
    SQL_MAX_TABLE_NAME_LEN     => qr/^[1-9]\d+$/,

    SQL_KEYWORDS               => qr/^(?:\w+,)+\w+$/,

    SQL_SEARCH_PATTERN_ESCAPE  => '\\',
    SQL_SERVER_NAME            => qr/^dbname=/,

    SQL_TABLE_TERM             => 'table',
);

my $dbh = connect_ok( RaiseError => 1 );

foreach my $option ( sort keys %info ) {
    my $value = $dbh->get_info( $GetInfoType{$option} );
    my $check = $info{$option};
    if (ref $check eq 'Regexp') { like($value, $check, $option); }
    else                        { is  ($value, $check, $option); }
}

$dbh->disconnect;

done_testing;
