use strict;
use warnings;
use lib "t/lib";
use SQLiteTest qw/connect_ok $sqlite_call/;
use Test::More;
use if -d ".git", "Test::FailWarnings";

my $dbh = connect_ok( RaiseError => 1, PrintError => 0, AutoCommit => 1 );

$dbh->$sqlite_call(create_module => vtab => "DBD::SQLite::VirtualTable::T");

ok $dbh->do("CREATE VIRTUAL TABLE foobar USING vtab(foo INTEGER, bar INTEGER)");

my $sql = "SELECT rowid, foo, bar FROM foobar ";
my $rows = $dbh->selectall_arrayref($sql, {Slice => {}});
is scalar(@$rows), 5, "got 5 rows";
is $rows->[0]{rowid}, 5, "rowid column";
is $rows->[0]{foo}, "auto_vivify:0", "foo column";
is $rows->[0]{bar}, "auto_vivify:1", "bar column";

$sql = "SELECT * FROM foobar ";
$rows = $dbh->selectall_arrayref($sql, {Slice => {}});
is scalar(@$rows), 5, "got 5 rows again";

is_deeply([sort keys %{$rows->[0]}], [qw/bar foo/], "col list OK");

$sql = "SELECT * FROM foobar WHERE foo > -1 and bar < 33";
$rows = $dbh->selectall_arrayref($sql, {Slice => {}});
is scalar(@$rows), 5, "got 5 rows (because of omitted constraints)";

done_testing;

package DBD::SQLite::VirtualTable::T;
use strict;
use warnings;
use base 'DBD::SQLite::VirtualTable';

sub NEW {
  my $class = shift;

  my $self  = $class->_PREPARE_SELF(@_);
  bless $self, $class;

  # stupid pragma call, just to check that the dbh is OK
  $self->dbh->do("PRAGMA application_id=999");

  return $self;
}

sub BEST_INDEX {
  my ($self, $constraints, $order_by) = @_;

  # print STDERR Dump [BEST_INDEX => {
  #   where => $constraints,
  #   order => $order_by,
  # }];

  my $ix = 0;

  foreach my $constraint (@$constraints) {
    $constraint->{argvIndex} = $ix++;
    $constraint->{omit}      = 1; # to prevent sqlite core to check values
  }

  # TMP HACK -- should put real values instead
  my $outputs = {
    idxNum           => 1,
    idxStr           => "foobar",
    orderByConsumed  => 0,
    estimatedCost    => 1.0,
    estimatedRows    => undef,
   };

  return $outputs;
}

package DBD::SQLite::VirtualTable::T::Cursor;
use strict;
use warnings;
use base 'DBD::SQLite::VirtualTable::Cursor';

sub NEW {
  my $class = shift;

  my $self = $class->SUPER::NEW(@_);
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

  return "auto_vivify:$idxCol";
}

sub ROWID {
  my ($self) = @_;

  return $self->{row_count};
}

1;
