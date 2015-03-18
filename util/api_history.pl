#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use SQLiteUtil;
use Array::Diff;

my %current;
for my $version (versions()) {
  print "checking $version...\n";
  my $dir = srcdir($version);
  unless ($dir && -d $dir) {
    $dir = mirror($version) or next;
  }
  my %constants = extract_constants("$dir/sqlite3.h");
  if (%current) {
    for (sort keys %current) {
      print "$version: deleted $_\n" if !exists $constants{$_};
    }
    for (sort keys %constants) {
      if (!exists $current{$_}) {
        print "$version: added $_\n";
        next;
      }
      my $diff = Array::Diff->diff($current{$_}, $constants{$_});
      print "$version: added $_\n" for @{$diff->added || []};
      print "$version: deleted $_\n" for @{$diff->deleted || []};
    }
  }
  %current = %constants;
}
