use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok $sqlite_call/;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok( RaiseError => 1, PrintError => 0, AutoCommit => 1 );

$dbh->$sqlite_call(create_module => vtab => "DBD::SQLite::VirtualTable::T");

ok $dbh->do("CREATE VIRTUAL TABLE foobar USING vtab(foo INTEGER, bar INTEGER)"),
   "created foobar";

# overload functions "abs" and "substr"
$DBD::SQLite::VirtualTable::T::funcs{abs}{overloaded} 
  = sub {my $val = shift; return "fake_abs($val)" };
$DBD::SQLite::VirtualTable::T::funcs{substr}{overloaded} 
  = sub {my ($val, $offset, $len) = @_; return "fake_substr($val, $offset, $len)" };

# make a first query
my $row = $dbh->selectrow_hashref(<<"");
  SELECT abs(foo) afoo,
         abs(bar) abar,
         substr(foo, 3, 5) sfoo,
         trim(foo) tfoo
  FROM foobar

is $DBD::SQLite::VirtualTable::T::funcs{abs}{calls},    1, "abs called";
is $DBD::SQLite::VirtualTable::T::funcs{substr}{calls}, 1, "substr called";
is $DBD::SQLite::VirtualTable::T::funcs{trim}{calls},   1, "trim called";

is_deeply $row, { 'abar' => 'fake_abs(1)',
                  'afoo' => 'fake_abs(0)',
                  'sfoo' => 'fake_substr(0, 3, 5)',
                  'tfoo' => '0' }, "func results";

# new query : FIND_FUNCTION should not be called again
$row = $dbh->selectrow_hashref(<<"");
  SELECT abs(foo) afoo,
         abs(bar) abar,
         substr(foo, 3, 5) sfoo,
         trim(foo) tfoo
  FROM foobar

is $DBD::SQLite::VirtualTable::T::funcs{abs}{calls},    1, "abs still 1";
is $DBD::SQLite::VirtualTable::T::funcs{substr}{calls}, 1, "substr still 1";
is $DBD::SQLite::VirtualTable::T::funcs{trim}{calls},   1, "trim still 1";

# new table : should issue new calls to FIND_FUNCTION
ok $dbh->do("CREATE VIRTUAL TABLE barfoo USING vtab(foo INTEGER, bar INTEGER)"),
   "created barfoo"; 

$row = $dbh->selectrow_hashref(<<"");
  SELECT abs(foo) afoo,
         abs(bar) abar,
         substr(foo, 3, 5) sfoo,
         trim(foo) tfoo
  FROM barfoo

is $DBD::SQLite::VirtualTable::T::funcs{abs}{calls},    2, "abs now 2";
is $DBD::SQLite::VirtualTable::T::funcs{substr}{calls}, 2, "substr now 2";
is $DBD::SQLite::VirtualTable::T::funcs{trim}{calls},   2, "trim now 2";

# drop table : should free references to functions
ok $dbh->do("DROP TABLE foobar");

# drop connection
undef $dbh;

note "done";

done_testing;

package DBD::SQLite::VirtualTable::T;
use strict;
use warnings;
use base 'DBD::SQLite::VirtualTable';

sub BEST_INDEX {
  my ($self, $constraints, $order_by) = @_;

  my $ix = 0;

  foreach my $constraint (@$constraints) {
    $constraint->{argvIndex} = $ix++;
    $constraint->{omit}      = 1; # to prevent sqlite core to check values
  }

  my $outputs = {
    idxNum           => 1,
    idxStr           => "foobar",
    orderByConsumed  => 0,
    estimatedCost    => 1.0,
    estimatedRows    => undef,
   };

  return $outputs;
}

our %funcs;

sub FIND_FUNCTION {
  my ($self, $n_arg, $function_name) = @_;

  $funcs{$function_name}{calls} += 1;
  my $func = $funcs{$function_name}{overloaded};
  return $func;
}

package DBD::SQLite::VirtualTable::T::Cursor;
use strict;
use warnings;
use base 'DBD::SQLite::VirtualTable::Cursor';

sub NEW {
  my $class = shift;

  my $self = $class->DBD::SQLite::VirtualTable::Cursor::NEW(@_);
  $self->{row_count} = 5;

  return $self;
}

sub FILTER {
  my ($self, $idxNum, $idxStr, @values) = @_;

  return;
}

sub EOF {
  my $self = shift;

  return !$self->{row_count};
}

sub NEXT {
  my $self = shift;

  $self->{row_count}--;
}

sub COLUMN {
  my ($self, $idxCol) = @_;

  return $idxCol;
}

sub ROWID {
  my ($self) = @_;

  return $self->{row_count};
}

1;
