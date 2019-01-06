use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok $sqlite_call has_sqlite/;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok(sqlite_trace => 2);
# register the module and declare the virtual table
$dbh->func(perl => "DBD::SQLite::VirtualTable::PerlData", 'create_module');

# create a table, reference_values,  with 2 columns
# ref_value - a text column which will have strings and numeric data (as text)
# our_id    - a numeric column with integers
$dbh->do('DROP TABLE IF EXISTS reference_values');
$dbh->do('CREATE TABLE reference_values(ref_value text, our_id int)');

my @data_to_insert = (
    [ 'aaaa', 1 ],
    [ 'bbbb', 2 ],
    [ 'cccc', 3 ],
    [ 'xxxx', 4 ],
    [ 'yyyy', 5 ],
    [ '0003', 6 ],
    [ '1000', 7 ],
    [ '2222', 8 ],
    [ '3000', 9 ],
    [ '4000', 10 ],
    [ '5abc', 11 ],
    [ 'a6cd', 12 ],
    [ 'ab7d', 13 ],
    [ 'abc8', 14 ],
    [ '9aaa', 15 ],
);

my $sth = $dbh->prepare('INSERT INTO reference_values VALUES (?, ?)');
foreach my $data_aref (@data_to_insert) {
    $sth->execute(@$data_aref) or die "Couldn't insert data row:" . $dbh->errstr;
}

# these are data sets that will be used by the virtual perldata function
# we'll add these as a virtual table then do an inner join on our reference_value
# table to find matching values
my $text_column_search_sets = {
    strings_only  => [ qw( aaaa abcd bbbb bcde cccc yyyy ) ],
    mixed         => [ qw( aaaa 0003 z8z8 6666 cccc 1000 zzzz 7777 ) ],
    initial_digit => [ qw( 1aaa 2bbb 5abc 6abc 9aaa 3aaa 1aaa 2aaa ) ],
    numbers_only  => [ qw( 0001 0003 9999 1000 5555 3000 6666 4000 ) ] ,
};

my $expected_answers = {
    strings_only =>
        [ [ 'aaaa', 1 ], [ 'bbbb', 2 ], [ 'cccc', 3 ], [ 'yyyy', 5 ] ],
    mixed => [ [ 'aaaa', 1 ], [ 'cccc', 3 ], [ '0003', 6 ], [ '1000', 7 ] ],
    initial_digit => [ [ '5abc', 11 ], [ '9aaa', 15 ] ],
    numbers_only =>
        [ [ '0003', 6 ], [ '1000', 7 ], [ '3000', 9 ], [ '4000', 10 ] ]
};

our $search_value_set;
my $temp_table_number = 0;

my @test_order = qw(strings_only mixed initial_digit numbers_only );

foreach my $test_desc (@test_order) {

    $temp_table_number++;
    my $temp_table_name = 'temp.lookup_values_' . $temp_table_number;
    $search_value_set    = $text_column_search_sets->{$test_desc};
note explain $search_value_set;

    my $virt_table_sql =<< "EOT";
    CREATE VIRTUAL TABLE $temp_table_name
    USING perl(lookup_value text, colref="main::search_value_set")
EOT

    $dbh->do($virt_table_sql);

    my $lookup_sql =<< "EOT";
    select ref_value, our_id from reference_values
    inner join $temp_table_name
    on $temp_table_name.lookup_value = reference_values.ref_value
    order by our_id
EOT

    my $got_aref = $dbh->selectall_arrayref($lookup_sql);
    my $expected_aref = $expected_answers->{$test_desc};

    is_deeply($got_aref, $expected_aref, $test_desc);
}

done_testing;
