#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;
use Test::NoWarnings;

plan tests => 3 * @CALL_FUNCS * 3 + 1;

# The following snippets are copied from Cookbook.pod by hand.
# Don't forget to update here when the pod is updated.
# Or, use/coin something like Test::Snippets for better synching.

SCOPE: {
  package variance;
  
  sub new { bless [], shift; }
  
  sub step {
      my ( $self, $value ) = @_;
  
      push @$self, $value;
  }
  
  sub finalize {
      my $self = $_[0];
  
      my $n = @$self;
  
      # Variance is NULL unless there is more than one row
      return undef unless $n || $n == 1;
  
      my $mu = 0;
      foreach my $v ( @$self ) {
          $mu += $v;
      }
      $mu /= $n;
  
      my $sigma = 0;
      foreach my $v ( @$self ) {
          $sigma += ($v - $mu)**2;
      }
      $sigma = $sigma / ($n - 1);
  
      return $sigma;
  }
}

SCOPE2: {
  package variance2;
  
  sub new { bless {sum => 0, count=>0, hash=> {} }, shift; }
  
  sub step {
      my ( $self, $value ) = @_;
      my $hash = $self->{hash};
  
      # by truncating and hashing, we can comsume many more data points
      $value = int($value); # change depending on need for precision
                            # use sprintf for arbitrary fp precision
      if (exists $hash->{$value}) {
          $hash->{$value}++;
      } else {
          $hash->{$value} = 1;
      }
      $self->{sum} += $value;
      $self->{count}++;
  }
  
  sub finalize {
      my $self = $_[0];
  
      # Variance is NULL unless there is more than one row
      return undef unless $self->{count} > 1;
  
      # calculate avg
      my $mu = $self->{sum} / $self->{count};
  
      my $sigma = 0;
      while (my ($h, $v) = each %{$self->{hash}}) {
          $sigma += (($h - $mu)**2) * $v;
      }
      $sigma = $sigma / ($self->{count} - 1);
  
      return $sigma;
  }
}

SCOPE3: {
  package variance3;
  
  sub new { bless {mu=>0, count=>0, S=>0}, shift; }
  
  sub step {
      my ( $self, $value ) = @_;
      $self->{count}++;
      my $delta = $value - $self->{mu};
      $self->{mu} += $delta/$self->{count};
      $self->{S} += $delta*($value - $self->{mu});
  }
  
  sub finalize {
      my $self = $_[0];
      return $self->{S} / ($self->{count} - 1);
  }
}

foreach my $variance (qw/variance variance2 variance3/) {
	foreach my $call_func (@CALL_FUNCS) {
		my $dbh = connect_ok( PrintError => 0 );
		$dbh->do('CREATE TABLE results (group_name, score)');
		my $sth = $dbh->prepare('INSERT INTO results VALUES (?,?)');
		$sth->execute('foo', 100);
		$sth->execute('foo', 50);
		$sth->finish;

		$dbh->$call_func($variance, 1, $variance, "create_aggregate");

		my $result = $dbh->selectrow_arrayref(<<"END_SQL");
		    SELECT group_name, ${variance}(score)
		    FROM results
		    GROUP BY group_name;
END_SQL

		is $result->[0] => 'foo';
		is $result->[1] => 1250;
	}
}
