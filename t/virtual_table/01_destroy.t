use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok $sqlite_call/;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $dbfile = "tmp.sqlite";

my $dbh = connect_ok( dbfile => $dbfile, RaiseError => 1, AutoCommit => 1 );

ok !$DBD::SQLite::VirtualTable::T::CREATE_COUNT &&
   !$DBD::SQLite::VirtualTable::T::CONNECT_COUNT,  "no vtab created";

# create 2 separate SQLite modules from the same Perl class
$dbh->$sqlite_call(create_module => vtab1 => "DBD::SQLite::VirtualTable::T");
$dbh->$sqlite_call(create_module => vtab2 => "DBD::SQLite::VirtualTable::T");

ok !$DBD::SQLite::VirtualTable::T::CREATE_COUNT &&
   !$DBD::SQLite::VirtualTable::T::CONNECT_COUNT,  "still no vtab";

# create 2 virtual tables from module vtab1
ok $dbh->do("CREATE VIRTUAL TABLE foobar USING vtab1(foo, bar)"), "create foobar"; 
ok $dbh->do("CREATE VIRTUAL TABLE barfoo USING vtab1(foo, bar)"), "create barfoo"; 
is $DBD::SQLite::VirtualTable::T::CREATE_COUNT,     2, "2 vtab created";
ok !$DBD::SQLite::VirtualTable::T::CONNECT_COUNT,     "no vtab connected";

# destructor is called when a vtable is dropped
ok !$DBD::SQLite::VirtualTable::T::DESTROY_COUNT, "no vtab destroyed";
ok $dbh->do("DROP TABLE foobar"), "dropped foobar";
is $DBD::SQLite::VirtualTable::T::DESTROY_COUNT, 1, "one vtab destroyed";

# all vtable and module destructors are called when the dbh is disconnected
undef $dbh;
is $DBD::SQLite::VirtualTable::T::DESTROY_COUNT,        2, "both vtab destroyed";
is $DBD::SQLite::VirtualTable::T::DISCONNECT_COUNT,     1, "1 vtab disconnected";
is $DBD::SQLite::VirtualTable::T::DROP_COUNT,           1, "1 vtab dropped";
is $DBD::SQLite::VirtualTable::T::DESTROY_MODULE_COUNT, 2, "2 modules destroyed";

# reconnect, check that we go through the CONNECT method
undef $DBD::SQLite::VirtualTable::T::CREATE_COUNT;
undef $DBD::SQLite::VirtualTable::T::CONNECT_COUNT;

$dbh = connect_ok( dbfile => $dbfile, RaiseError => 1, AutoCommit => 1 );
$dbh->$sqlite_call(create_module => vtab1 => "DBD::SQLite::VirtualTable::T");
ok !$DBD::SQLite::VirtualTable::T::CREATE_COUNT,     "no vtab created";
ok !$DBD::SQLite::VirtualTable::T::CONNECT_COUNT,    "no vtab connected";

my $sth = $dbh->prepare("SELECT * FROM barfoo");
ok !$DBD::SQLite::VirtualTable::T::CREATE_COUNT,    "no vtab created";
is $DBD::SQLite::VirtualTable::T::CONNECT_COUNT, 1, "1 vtab connected";

done_testing;

package DBD::SQLite::VirtualTable::T;
use base 'DBD::SQLite::VirtualTable';

our $CREATE_COUNT;
our $CONNECT_COUNT;
our $DESTROY_COUNT;
our $DESTROY_MODULE_COUNT;
our $DROP_COUNT;
our $DISCONNECT_COUNT;

sub CREATE          {$CREATE_COUNT++;  return shift->SUPER::CREATE(@_)}
sub CONNECT         {$CONNECT_COUNT++; return shift->SUPER::CONNECT(@_)}
sub DROP            {$DROP_COUNT++}
sub DISCONNECT      {$DISCONNECT_COUNT++}
sub DESTROY         {$DESTROY_COUNT++}
sub DESTROY_MODULE  {$DESTROY_MODULE_COUNT++}

1;
