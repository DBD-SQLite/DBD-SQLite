use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok requires_sqlite/;
use Test::More;
use if -d ".git", "Test::FailWarnings";

BEGIN { requires_sqlite('3.6.23') }

open my $trace_fh, '>', \my $trace_string;

DBI->trace(3, $trace_fh);

my $dbh = connect_ok(PrintError => 0, RaiseError => 1);

eval {
    $dbh->selectrow_array(q{ SELECT FROM FROM });
};

like $trace_string, qr/sqlite3_log/,
    'sqlite3_log messages forwarded to DBI tracing mechanism';

done_testing;
