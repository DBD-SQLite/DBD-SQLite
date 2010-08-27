#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;
use Test::NoWarnings;

my @tests = (
  ['foo bar'              => 'foo bar'                       ],
  ['foo -bar'             => 'foo (NOT bar)'                 ],
  ['foo* -bar*'           => 'foo* (NOT bar*)'               ],
  ['foo bar OR bie buz'   => 'foo (bar OR bie) buz'          ],
  ['-foo bar OR -bie buz' => '(NOT foo) (bar OR NOT bie) buz'],
  ['"kyrie eleison" OR "christe eleison"' 
                  => '("kyrie eleison" OR "christe eleison")'],
 );


plan tests => 1 + @tests;

use DBD::SQLite::FTS3Transitional qw/fts3_convert/;

foreach my $t (@tests) {
  my ($old_syntax, $expected_new) = @$t;
  my $new = fts3_convert($old_syntax);
  $new =~ s/^\s+//;
  is($new, $expected_new, $old_syntax);
}


