use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

our $scan_results = [
    { nodepath => 1 },
    { nodepath => 2 },
    { nodepath => 3 },
];

my $dbh = connect_ok(RaiseError => 1, AutoCommit => 1);

# register the module
$dbh->$sqlite_call(create_module => perl => "DBD::SQLite::VirtualTable::PerlData");
$dbh->do(<<'SQL');
        CREATE VIRTUAL TABLE temp.scan_results
        USING perl(file varchar,
                             value varchar,
                             selector varchar,
                             nodepath varchar,
                             expected integer,
                             preference integer,
                             complexity integer,
                             location varchar,
                             type     varchar,
                             hashrefs="main::scan_results")
SQL

my $ok = eval {
    my $sth = $dbh->prepare(<<'SQL');
                select distinct r.selector
                  from temp.scan_results r
                       left join temp.scan_results m
                             on r.nodepath = m.nodepath+1
                 where m.nodepath = 1
SQL
$sth->execute;
    #use DBIx::RunSQL; print DBIx::RunSQL->format_results( sth => $sth );
    1;
};
is $ok, 1, "We survive a numeric comparison";
undef $ok;

$ok = eval {
    my $sth = $dbh->prepare(<<'SQL');
                select distinct r.selector
                  from temp.scan_results r
                       left join temp.scan_results m
                             on r.nodepath = m.nodepath+1
                 where m.nodepath is not null
SQL
    $sth->execute;
    1;
    #use DBIx::RunSQL; print DBIx::RunSQL->format_results( sth => $sth );
};
is $ok, 1, "We survive an isnull comparison";
undef $ok;

$ok = eval {
    my $sth = $dbh->prepare(<<'SQL');
                select r.nodepath
                  from temp.scan_results r
                       left join temp.scan_results m
                             on r.nodepath = m.nodepath+1
                 where r.nodepath is null
SQL
    $sth->execute;
    1;
    #use DBIx::RunSQL; print DBIx::RunSQL->format_results( sth => $sth );
};
is $ok, 1, "We survive an isnull comparison on the left side";
undef $ok;

my $sth;
$ok = eval {
    $sth = $dbh->prepare(<<'SQL');
                select r.nodepath
                  from temp.scan_results r
                       left join temp.scan_results m
                             on r.nodepath = m.nodepath+1
                 where m.nodepath is null
SQL
    $sth->execute;
    1;
    #use DBIx::RunSQL; print DBIx::RunSQL->format_results( sth => $sth );
};
is $ok, 1, "We survive an isnull comparison on the right side";
undef $ok;
#my $rows = $sth->fetchall_arrayref;
#use Data::Dumper;
#warn Dumper $rows;

done_testing;
