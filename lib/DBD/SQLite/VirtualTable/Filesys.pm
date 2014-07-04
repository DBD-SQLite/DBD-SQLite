package DBD::SQLite::VirtualTable::Filesys;
use strict;
use warnings;
use base 'DBD::SQLite::VirtualTable';


=head1 NAME

DBD::SQLite::VirtualTable::Filesys -- virtual table for viewing file contents


=head1 SYNOPSIS

  -- $dbh->sqlite_create_module(filesys => "DBD::SQLite::VirtualTable::Filesys");

  CREATE VIRTUAL TABLE tbl USING filesys(file_content,
                                         index_table = idx,
                                         path_col    = path,
                                         expose      = "path, col1, col2, col3",
                                         root        = "/foo/bar")


=head1 DESCRIPTION

A "Filesys" virtual table is like a database view on some underlying
I<index table>, which has a column containing paths to
files; the virtual table then adds a supplementary column which exposes
the content from those files.

This is especially useful as an "external content" to some
fulltext table (see L<DBD::SQLite::Fulltext_search>) : the index
table stores some metadata about files, and then the fulltext engine
can index both the metadata and the file contents.

=head1 METHODS

=head2 new


=cut


sub initialize {
  my $self = shift;

  # verifications
  @{$self->{columns}} == 1
    or die "Filesys virtual table should declare exactly 1 content column";
  for my $opt (qw/index_table path_col/) {
    $self->{options}{$opt}
      or die "Filesys virtual table: option '$opt' is missing";
  }

  # get list of columns from the index table
  my $ix_table  = $self->{options}{index_table};
  my $sql       = "PRAGMA table_info($ix_table)";
  my $base_cols = $self->dbh->selectcol_arrayref($sql, {Columns => [2]});
  @$base_cols
    or die "wrong index table: $ix_table";

  # check / complete the exposed columns
  $self->{options}{expose} = "*" if not exists $self->{options}{expose};
  my @exposed_cols;
  if ($self->{options}{expose} eq '*') {
    @exposed_cols = @$base_cols;
  }
  else {
    @exposed_cols = split /\s*,\s*/, ($self->{options}{expose} || "");
    my %is_ok_col = map {$_ => 1} @$base_cols;
    my @bad_cols  = grep {!$is_ok_col{$_}} @exposed_cols;
    local $" = ", ";
    die "table $ix_table has no column named @bad_cols" if @bad_cols;
  }
  push @{$self->{columns}}, @exposed_cols;
}


sub _SQLITE_UPDATE {
  my ($self, $old_rowid, $new_rowid, @values) = @_;

  die "readonly database";
}


sub BEST_INDEX {
  my ($self, $constraints, $order_by) = @_;

  my @conditions;
  my $ix = 0;
  foreach my $constraint (grep {$_->{usable}} @$constraints) {
    my $col     = $constraint->{col};

    # if this is the content column, skip because we can't filter on it
    next if $col == 0;

    # for other columns, build a fragment for SQL WHERE on the underlying table
    my $colname = $col == -1 ? "rowid" : $self->{columns}[$col];
    push @conditions, "$colname $constraint->{op} ?";
    $constraint->{argvIndex} = $ix++;
    $constraint->{omit}      = 1;     # SQLite doesn't need to re-check the op
  }

  my $outputs = {
    idxNum           => 1,
    idxStr           => join(" AND ", @conditions),
    orderByConsumed  => 0,
    estimatedCost    => 1.0,
    estimatedRows    => undef,
   };

  return $outputs;
}

package DBD::SQLite::VirtualTable::Filesys::Cursor;
use 5.010;
use strict;
use warnings;
use base "DBD::SQLite::VirtualTable::Cursor";


sub FILTER {
  my ($self, $idxNum, $idxStr, @values) = @_;

  my $vtable = $self->{vtable};

  # build SQL
  local $" = ", ";
  my @cols = @{$vtable->{columns}};
  $cols[0] = 'rowid';                     # replace the content column by the rowid
  push @cols, $vtable->{options}{path_col}; # path col in last position
  my $sql  = "SELECT @cols FROM $vtable->{options}{index_table}";
  $sql .= " WHERE $idxStr" if $idxStr;

  # request on the index table
  my $dbh = $vtable->dbh;
  $self->{sth} = $dbh->prepare($sql)
    or die DBI->errstr;
  $self->{sth}->execute(@values);
  $self->{row} = $self->{sth}->fetchrow_arrayref;

  return;
}


sub EOF {
  my ($self) = @_;

  return !$self->{row};
}

sub NEXT {
  my ($self) = @_;

  $self->{row} = $self->{sth}->fetchrow_arrayref;
}


sub COLUMN {
  my ($self, $idxCol) = @_;

  return $idxCol == 0 ? $self->file_content : $self->{row}[$idxCol];
}

sub ROWID {
  my ($self) = @_;

  return $self->{row}[0];
}


sub file_content {
  my ($self) = @_;

  my $root = $self->{vtable}{options}{root};
  my $path = $self->{row}[-1];
  $path = "$root/$path" if $root;

  my $content = "";
  if (open my $fh, "<", $path) {
    local $/;          # slurp the whole file into a scalar
    $content = <$fh>;
    close $fh;
  }
  else {
    warn "can't open $path";
  }

  return $content;
}

1;

__END__




=head1 COPYRIGHT AND LICENSE

Copyright Laurent Dami, 2014.

Parts of the code are borrowed from L<SQLite::VirtualTable>,
copyright (C) 2006, 2009 by Qindel Formacion y Servicios, S. L.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
