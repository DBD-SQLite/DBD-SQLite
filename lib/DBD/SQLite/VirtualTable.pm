package DBD::SQLite::VirtualTable;
use strict;
use warnings;
use Scalar::Util    qw/weaken/;
use List::MoreUtils qw/part/;
use YAML::XS;
use Data::Dumper;

our $VERSION = '0.01';
our @ISA;


sub DESTROY_MODULE {
  my $class = shift;
}

sub CREATE {
  my $class = shift;
  return $class->NEW(@_);
}

sub CONNECT {
  my $class = shift;
  return $class->NEW(@_);
}


sub NEW { # called when instanciating a virtual table
  my ($class, $dbh_ref, $module_name, $db_name, $vtab_name, @args) = @_;

  my @columns;
  my %options;

  # args containing '=' are options; others are column declarations
  foreach my $arg (@args) {
    if ($arg =~ /^([^=\s]+)\s*=\s*(.*)/) {
      my ($key, $val) = ($1, $2);
      $val =~ s/^"(.*)"$/$1/;
      $options{$key} = $val;
    }
    else {
      push @columns, $arg;
    }
  }

  # build $self and initialize
  my $self =  {
    dbh_ref     => $dbh_ref,
    module_name => $module_name,
    db_name     => $db_name,
    vtab_name   => $vtab_name,
    columns     => \@columns,
    options     => \%options,
   };
  weaken $self->{dbh_ref};
  bless $self, $class;
  $self->initialize();

  return $self;
}

sub dbh {
  my $self = shift;
  return ${$self->{dbh_ref}};
}


sub initialize {
  my $self = shift;
}


sub connect {
  my $class = shift;

  warn "TODO -- VTAB called connect() instead of new()";
  return $class->new(@_);
}


sub DROP {
  my $self = shift;
}

sub DISCONNECT {
  my $self = shift;
}


sub VTAB_TO_DECLARE {
  my $self = shift;

  local $" = ", ";
  my $sql = "CREATE TABLE $self->{vtab_name}(@{$self->{columns}})";

  return $sql;
}


sub BEST_INDEX {
  my ($self, $constraints, $order_by) = @_;

  # print STDERR Dump [BEST_INDEX => {
  #   where => $constraints,
  #   order => $order_by,
  # }];

  my $ix = 0;

  foreach my $constraint (@$constraints) {
    # TMP HACK -- should put real values instead
    $constraint->{argvIndex} = $ix++;
    $constraint->{omit}      = 0;
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


sub OPEN {
  my $self  = shift;
  my $class = ref $self;

  my $cursor_class = $class . "::Cursor";

  return $cursor_class->new($self, @_);
}



sub _SQLITE_UPDATE {
  my ($self, $old_rowid, $new_rowid, @values) = @_;

  warn "CURSOR->_SQLITE_UPDATE";

  if (! defined $old_rowid) {
    return $self->INSERT($new_rowid, @values);
  }
  elsif (!@values) {
    return $self->DELETE($old_rowid);
  }
  else {
    return $self->UPDATE($old_rowid, $new_rowid, @values);
  }
}

sub INSERT {
  my ($self, $new_rowid, @values) = @_;

  warn "vtab->insert()";
  my $new_computed_rowid;
  return $new_computed_rowid;
}

sub DELETE {
  my ($self, $old_rowid) = @_;
}

sub UPDATE {
  my ($self, $old_rowid, $new_rowid, @values) = @_;
}



sub BEGIN_TRANSACTION    {return 0}
sub SYNC_TRANSACTION     {return 0}
sub COMMIT_TRANSACTION   {return 0}
sub ROLLBACK_TRANSACTION {return 0}

sub SAVEPOINT            {return 0}
sub RELEASE              {return 0}
sub ROLLBACK_TO          {return 0}

sub DESTROY {
  my $self = shift;
}


package DBD::SQLite::VirtualTable::Cursor;
use strict;
use warnings;

sub new {
  my ($class, $vtable, @args) = @_;
  my $self = {vtable => $vtable,
              args   => \@args};
  bless $self, $class;
}

sub FILTER {
  my ($self, $idxNum, $idxStr, @values) = @_;

  return;
}


sub EOF {
  my ($self) = @_;

  # stupid implementation, to be redefined in subclasses
  return 1;
}


sub NEXT {
  my ($self) = @_;
}


sub COLUMN {
  my ($self, $idxCol) = @_;
}

sub ROWID {
  my ($self) = @_;

  # stupid implementation, to be redefined in subclasses
  return 1;
}


sub CLOSE {
  my ($self) = @_;
}



1;

__END__

=head1 NAME

DBD::SQLite::VirtualTable -- Abstract parent class for implementing virtual tables

=head1 SYNOPSIS

  package My::Virtual::Table;
  use parent 'DBD::SQLite::VirtualTable';
  
  sub ...

=head1 DESCRIPTION

TODO

=head1 METHODS

TODO



=head1 COPYRIGHT AND LICENSE

Copyright Laurent Dami, 2014.

Parts of the code are borrowed from L<SQLite::VirtualTable>,
copyright (C) 2006, 2009 by Qindel Formacion y Servicios, S. L.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
