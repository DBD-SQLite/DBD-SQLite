package DBD::SQLite::FTS3Transitional;
use strict;
use warnings;
no warnings 'uninitialized';

use Exporter 'import';
our @EXPORT_OK = qw/fts3_convert/;


sub fts3_convert {
  my $in  = shift;
  my $out = "";

  # decompose input string into tokens
  my @tokens = $in =~ / -       # minus sign
                      | \bOR\b  # OR keyword
                      | ".*?"   # phrase query
                      | \S+     # term
                      /xg;

  # build the output string
  while (@tokens) {

    # -a => (NOT a)
    if ($tokens[0] eq '-') {
      my (undef, $right) = splice(@tokens, 0, 2);
      $out .= " (NOT $right)";
    }

    # a OR b => (a OR b)
    elsif (@tokens >= 2 && $tokens[1] eq 'OR') {
      my ($left, undef, $right) = splice(@tokens, 0, 3);
      if ($right eq '-') {
        $right = "NOT " . shift @tokens;
      }
      $out .= " ($left OR $right)";
    }

    # plain term
    else {
      $out .= " " . shift @tokens;
    }
  }

  return $out;
}


1;

__END__

=head1 NAME

DBD::SQLite::FTS3Transitional - helper function for migrating FTS3 applications

=head1 SYNOPSIS

  use DBD::SQLite::FTS3Transitional qw/fts3_convert/;
  my $new_match_syntax = fts3_convert($old_match_syntax);
  my $sql = "SELECT ... FROM ... WHERE col MATCH $new_match_syntax";

=head1 DESCRIPTION

Starting from version 1.31, C<DBD::SQLite> uses the new, recommended
"Enhanced Query Syntax" for binary set operators in fulltext FTS3 queries
(AND, OR, NOT, possibly nested with parenthesis). 

Previous versions of C<DBD::SQLite> used the
"Standard Query Syntax" (see L<http://www.sqlite.org/fts3.html#section_3_2>).

This module helps converting SQLite application built with the old,
"Standard" query syntax, to the new "Extended" syntax.

=head1 FUNCTIONS

=head2 fts3_convert

Takes as input a string for the MATCH clause in a FTS3 fulltext search;
returns the same clause rewritten in new, "Extended" syntax.

=head1 AUTHOR

Laurent Dami E<lt>dami@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2010 Laurent Dami.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
