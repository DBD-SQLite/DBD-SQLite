use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my @catalog_info = (
    [undef, undef, undef, undef, undef],
);

my @schema_info = (
    [undef, 'main', undef, undef, undef],
    [undef, 'temp', undef, undef, undef]
);
my @systable_info = (
    [undef, 'main', 'sqlite_master', 'SYSTEM TABLE', undef, undef],
    [undef, 'temp', 'sqlite_temp_master', 'SYSTEM TABLE', undef, undef]
);

my @type_info = (
    [undef, undef, undef, 'LOCAL TEMPORARY', undef],
    [undef, undef, undef, 'SYSTEM TABLE', undef],
    [undef, undef, undef, 'TABLE', undef],
    [undef, undef, undef, 'VIEW', undef],
);

# Create a database
my $dbh = connect_ok();

# Check available catalogs
my $sth = $dbh->table_info('%', '', '');
ok $sth, 'We can get catalog information';
my $info = $sth->fetchall_arrayref;
is_deeply $info, \@catalog_info, 'Correct catalog information';

# Check available schemas
$sth = $dbh->table_info('', '%', '');
ok $sth, 'We can get table/schema information';
$info = $sth->fetchall_arrayref;
is_deeply $info, \@schema_info, 'Correct table/schema information';

# Check supported types
$sth = $dbh->table_info('', '', '', '%');
ok $sth, 'We can get type information';
$info = $sth->fetchall_arrayref;
is_deeply $info, \@type_info, 'Correct table_info for type listing';

# Create a table
ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE one' );
CREATE TABLE one (
    id INTEGER PRIMARY KEY NOT NULL,
    name CHAR (64) NOT NULL
)
END_SQL
my $table1_info = [undef, 'main', 'one', 'TABLE', undef, 'CREATE TABLE one (
    id INTEGER PRIMARY KEY NOT NULL,
    name CHAR (64) NOT NULL
)'];

# Create a temporary table
ok( $dbh->do(<<'END_SQL'), 'CREATE TEMP TABLE two' );
CREATE TEMP TABLE two (
    id INTEGER NOT NULL,
    name CHAR (64) NOT NULL
)
END_SQL
my $table2_info = [undef, 'temp', 'two', 'LOCAL TEMPORARY', undef, 'CREATE TABLE two (
    id INTEGER NOT NULL,
    name CHAR (64) NOT NULL
)'];

# Attach a memory database
ok( $dbh->do('ATTACH DATABASE ":memory:" AS db3'), 'ATTACH DATABASE ":memory:" AS db3' );

# Create a table on the attached database
ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE db3.three' );
CREATE TABLE db3.three (
    id INTEGER NOT NULL,
    name CHAR (64) NOT NULL
)
END_SQL
my $table3_info = [undef, 'db3', 'three', 'TABLE', undef, 'CREATE TABLE three (
    id INTEGER NOT NULL,
    name CHAR (64) NOT NULL
)'];

# Get table_info for "one"
$info = $dbh->table_info(undef, undef, 'one')->fetchall_arrayref;
is_deeply $info, [$table1_info], 'Correct table_info for "one"';

# Get table_info for "main"."one"
$info = $dbh->table_info(undef, 'main', 'one')->fetchall_arrayref;
is_deeply $info, [$table1_info], 'Correct table_info for "main"."one"';

# Get table_info for "two"
$info = $dbh->table_info(undef, undef, 'two')->fetchall_arrayref;
is_deeply $info, [$table2_info], 'Correct table_info for "two"';

# Get table_info for "temp"."two"
$info = $dbh->table_info(undef, 'temp', 'two')->fetchall_arrayref;
is_deeply $info, [$table2_info], 'Correct table_info for "temp"."two"';

# Get table_info for "three"
$info = $dbh->table_info(undef, undef, 'three')->fetchall_arrayref;
is_deeply $info, [$table3_info], 'Correct table_info for "three"';

# Get table_info for "db3"."three"
$info = $dbh->table_info(undef, 'db3', 'three')->fetchall_arrayref;
is_deeply $info, [$table3_info], 'Correct table_info for "db3"."three"';

# Create another table "one" on the attached database
ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE db3.one' );
CREATE TABLE db3.one (
    id INTEGER PRIMARY KEY NOT NULL,
    name CHAR (64) NOT NULL
)
END_SQL
my $table4_info = [undef, 'db3', 'one', 'TABLE', undef, 'CREATE TABLE one (
    id INTEGER PRIMARY KEY NOT NULL,
    name CHAR (64) NOT NULL
)'];

# Create a table with generated columns
ok( $dbh->do(<<'END_SQL'), 'CREATE TABLE generated_columns' );
CREATE TABLE generated_columns (
    id INTEGER PRIMARY KEY NOT NULL,
    nextid GENERATED ALWAYS AS (id+1)
)
END_SQL
my $table_generated_info = [undef, 'main', 'generated_columns', 'TABLE', undef, 'CREATE TABLE generated_columns (
    id INTEGER PRIMARY KEY NOT NULL,
    nextid GENERATED ALWAYS AS (id+1)
)'];

# Get table_info for both tables named "one"
$info = $dbh->table_info(undef, undef, 'one')->fetchall_arrayref;
is_deeply $info, [$table4_info, $table1_info], 'Correct table_info for both tables named "one"';

# Get table_info for the system tables
$info = $dbh->table_info(undef, undef, undef, 'SYSTEM TABLE')->fetchall_arrayref;
is_deeply $info, \@systable_info, 'Correct table_info for the system tables';

# Get table_info for all tables
$info = $dbh->table_info()->fetchall_arrayref;
is_deeply $info, [$table2_info, @systable_info, $table4_info, $table3_info, $table_generated_info, $table1_info ],
    'Correct table_info for all tables';

#use Data::Dumper;
#warn 'Catalog Names', substr Dumper($dbh->table_info('%', '', '')->fetchall_arrayref), 5;
#warn 'Schema Names', substr Dumper($dbh->table_info('', '%', '')->fetchall_arrayref), 5;
#warn 'Table Types', substr Dumper($dbh->table_info('', '', '', '%')->fetchall_arrayref), 5;
#warn 'table_info', substr Dumper($info), 5;

done_testing;
