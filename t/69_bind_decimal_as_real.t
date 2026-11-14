use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok/;
use Test::More;
use if -d ".git", "Test::FailWarnings";
use DBI qw(:sql_types);

# A decimal string is bound as a REAL when formatting it back with its
# own precision gives the same string: guessed with
# sqlite_see_if_its_a_number, or with an explicit float type. On a perl
# whose NV is __float128 the value passed to form() has to be an NV as
# well, or the check never matches (Linux) or crashes (Cygwin).

my @values = qw/1.5 -0.25 +3.5 1234567.20/;

my $dbh = connect_ok(sqlite_see_if_its_a_number => 1);

for my $value (@values) {
    my ($type) = $dbh->selectrow_array('select typeof(?)', undef, $value);
    is $type, 'real', "$value is guessed as a real";
}

for my $sql_type (SQL_FLOAT, SQL_DOUBLE) {
    for my $value (@values) {
        my $sth = $dbh->prepare('select typeof(?)');
        $sth->bind_param(1, $value, $sql_type);
        $sth->execute;
        my ($type) = $sth->fetchrow_array;
        is $type, 'real', "$value bound as SQL type $sql_type is a real";
    }
}

done_testing;
