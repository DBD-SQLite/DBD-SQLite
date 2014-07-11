#======================================================================
package DBD::SQLite::VirtualTable::PerlData;
#======================================================================
use strict;
use warnings;
use base 'DBD::SQLite::VirtualTable';
use List::MoreUtils qw/mesh/;


# private data for translating comparison operators from Sqlite to Perl
my $TXT = 0;
my $NUM = 1;
my %SQLOP2PERLOP = (
#              TXT     NUM
  '='     => [ 'eq',   '==' ],
  '<'     => [ 'lt',   '<'  ],
  '<='    => [ 'le',   '<=' ],
  '>'     => [ 'gt',   '>'  ],
  '>='    => [ 'ge',   '>=' ],
  'MATCH' => [ '=~',   '=~' ],
);

#----------------------------------------------------------------------
# instanciation methods
#----------------------------------------------------------------------

sub NEW {
  my $class = shift;
  my $self  = $class->_PREPARE_SELF(@_);

  # verifications
  my $n_cols = @{$self->{columns}};
  $n_cols > 0
    or die "$class: no declared columns";
  !$self->{options}{colref} || $n_cols == 1
    or die "$class: must have exactly 1 column when using 'colref'";
  my $symbolic_ref = $self->{options}{arrayrefs}
                  || $self->{options}{hashrefs}
                  || $self->{options}{colref}
    or die "$class: missing option 'arrayrefs' or 'hashrefs' or 'colref'";

  # bind to the Perl variable
  no strict "refs";
  defined ${$symbolic_ref}
    or die "$class: can't find global variable \$$symbolic_ref";
  $self->{rows} = \ ${$symbolic_ref};

  bless $self, $class;
}

sub _build_headers_optypes {
  my $self = shift;

  my $cols = $self->sqlite_table_info;

  # headers : names of columns, without type information
  $self->{headers} = [ map {$_->{name}} @$cols ];

  # optypes : either $NUM or $TEXT for each column
  # (applying  algorithm from datatype3.html" for type affinity)
  $self->{optypes}
    = [ map {$_->{type} =~ /INT|REAL|FLOA|DOUB/i ? $NUM : $TXT} @$cols ];
}

#----------------------------------------------------------------------
# method for initiating a search
#----------------------------------------------------------------------

sub BEST_INDEX {
  my ($self, $constraints, $order_by) = @_;

  $self->_build_headers_optypes if !$self->{headers};

  # for each constraint, build a Perl code fragment. Those will be gathered
  # in FILTER() for deciding which rows match the constraints.
  my @conditions;
  my $ix = 0;
  foreach my $constraint (grep {$_->{usable}} @$constraints) {
    my $col = $constraint->{col};
    my ($member, $optype);

    # build a Perl code fragment. Those fragments will be gathered
    # and eval-ed in FILTER(), for deciding which rows match the constraints.
    if ($col == -1) {
      # constraint on rowid
      $member = '$i';
      $optype = $NUM;
    }
    else {
      my $get_col = $self->{options}{arrayrefs} ? "->[$col]"
                  : $self->{options}{hashrefs}  ? "->{$self->{headers}[$col]}"
                  : $self->{options}{colref}    ? ""
                  : die "corrupted data in ->{options}";
      $member = '$self->row($i)' . $get_col;
      $optype = $self->{optypes}[$col];
    }
    my $op    = $SQLOP2PERLOP{$constraint->{op}}[$optype];
    my $quote = $op eq '=~' ? 'qr' : 'q';
    push @conditions, "($member $op ${quote}{%s})";

    # info passed back to the SQLite core -- see vtab.html in sqlite doc
    $constraint->{argvIndex} = $ix++;
    $constraint->{omit}      = 1;
  }

  # further info for the SQLite core
  my $outputs = {
    idxNum           => 1,
    idxStr           => (join(" && ", @conditions) || "1"),
    orderByConsumed  => 0,
    estimatedCost    => 1.0,
    estimatedRows    => undef,
  };

  return $outputs;
}


#----------------------------------------------------------------------
# methods for data update
#----------------------------------------------------------------------

sub _build_new_row {
  my ($self, $values) = @_;

  return $self->{options}{arrayrefs} ? $values
       : $self->{options}{hashrefs}  ? { mesh @{$self->{headers}}, @$values }
       : $self->{options}{colref}    ? $values->[0]
       : die "corrupted data in ->{options}";
}


sub INSERT {
  my ($self, $new_rowid, @values) = @_;

  my $new_row = $self->_build_new_row(\@values);

  if (defined $new_rowid) {
    not ${$self->{rows}}->[$new_rowid]
      or die "can't INSERT : rowid $new_rowid already in use";
    ${$self->{rows}}->[$new_rowid] = $new_row;
  }
  else {
    push @${$self->{rows}}, $new_row;
    return $#${$self->{rows}};
  }
}

sub DELETE {
  my ($self, $old_rowid) = @_;

  delete ${$self->{rows}}->[$old_rowid];
}

sub UPDATE {
  my ($self, $old_rowid, $new_rowid, @values) = @_;

  my $new_row = $self->_build_new_row(\@values);

  if ($new_rowid == $old_rowid) {
    ${$self->{rows}}->[$old_rowid] = $new_row;
  }
  else {
    delete ${$self->{rows}}->[$old_rowid];
    ${$self->{rows}}->[$new_rowid] = $new_row;
  }
}


#======================================================================
package DBD::SQLite::VirtualTable::PerlData::Cursor;
#======================================================================
use strict;
use warnings;
use base "DBD::SQLite::VirtualTable::Cursor";


sub row {
  my ($self, $i) = @_;
  return ${$self->{vtable}{rows}}->[$i];
}

sub FILTER {
  my ($self, $idxNum, $idxStr, @values) = @_;

  # build a method coderef to fetch matching rows
  my $perl_code = sprintf "sub {my (\$self, \$i) = \@_; $idxStr}", @values;

  $self->{is_wanted_row} = eval $perl_code
    or die "couldn't eval q{$perl_code} : $@";

  # position the cursor to the first matching row (or to eof)
  $self->{row_ix} = -1;
  $self->NEXT;
}


sub EOF {
  my ($self) = @_;

  return $self->{row_ix} > $#${$self->{vtable}{rows}};
}

sub NEXT {
  my ($self) = @_;

  do {
    $self->{row_ix} += 1
  } until $self->EOF || $self->{is_wanted_row}->($self, $self->{row_ix});
}


sub COLUMN {
  my ($self, $idxCol) = @_;

  my $row = $self->row($self->{row_ix});


  return $self->{vtable}{options}{arrayrefs} ? $row->[$idxCol]
       : $self->{vtable}{options}{hashrefs}  ?
                   $row->{$self->{vtable}{headers}[$idxCol]}
       : $self->{vtable}{options}{colref}    ? $row
       : die "corrupted data in ->{options}";
}

sub ROWID {
  my ($self) = @_;

  return $self->{row_ix};
}


1;

__END__

=head1 NAME

DBD::SQLite::VirtualTable::PerlData -- virtual table hooked to Perl data

=head1 SYNOPSIS

Within Perl :

  $dbh->sqlite_create_module(perl => "DBD::SQLite::VirtualTable::PerlData");

Then, within SQL :


  CREATE VIRTUAL TABLE atbl USING perl(foo, bar, etc,
                                       arrayrefs="some::global::var::aref")

  CREATE VIRTUAL TABLE htbl USING perl(foo, bar, etc,
                                       hashrefs="some::global::var::href")

  CREATE VIRTUAL TABLE ctbl USING perl(single_col
                                       colref="some::global::var::ref")


  SELECT foo, bar FROM atbl WHERE ...;


=head1 DESCRIPTION

A C<PerlData> virtual table is a database view on some datastructure
within a Perl program. The data can be read or modified both from SQL
and from Perl. This is useful for simple import/export
operations, for debugging purposes, for joining data from different
sources, etc.


=head1 PARAMETERS

Parameters for creating a C<PerlData> virtual table are specified
within the C<CREATE VIRTUAL TABLE> statement, mixed with regular
column declarations, but with an '=' sign.

The only authorized (and mandatory) parameter is the one that
specifies the Perl datastructure to which the virtual table is bound.
The Perl data must be given as a fully qualified name of a global variable;
it can be one of three different kinds :

=over

=item C<arrayrefs>

arrayref that contains an arrayref for each row

=item C<hashrefs>

arrayref that contains a hashref for each row

=item C<colref>

arrayref that contains a single scalar for each row
(obviously this is a single-column virtual table)

=back

=head1 USAGE

[TODO]

=head1 AUTHOR

Laurent Dami E<lt>dami@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright Laurent Dami, 2014.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
