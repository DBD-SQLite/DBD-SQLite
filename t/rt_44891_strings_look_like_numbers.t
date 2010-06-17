#!/usr/bin/perl

use strict;
BEGIN {
    $|  = 1;
    $^W = 1;
}

use t::lib::Test;
use Test::More;
use DBD::SQLite;
use Test::NoWarnings;

my @values = qw/
    0 1 1.0 1.1 2.0 1.0e+001 0000 01010101 10010101
    0000002100000517
    0000002200000517
    0000001e00000517
    00002.000
    test 01234test -test +test
    0.123e 0.123e+
    0. .123 -.123 +.123
    -1 -1.0 -1.1 -2.0 -1.0e-001 -0000 -0101 -002.00
    +1 +1.0 +1.1 +2.0 +1.0e-001 +0000 +0101 +002.00
    1234567890123456789012345678901234567890
    -1234567890123456789012345678901234567890
    +1234567890123456789012345678901234567890
    *1234567890123456789012345678901234567890
    -9223372036854775807 +9223372036854775806
    -9223372036854775808 +9223372036854775807
    -9223372036854775809 +9223372036854775808
    -2147483646 +2147483647
    -2147483647 +2147483648
    -2147483648 +2147483649
    + -
/;

my @types = ('', 'text', 'integer', 'real');

my %prior_DBD_SQLITE_1_30_behaviors = prior_DBD_SQLITE_1_30_behaviors();
my %sqlite3_bin_behaviors = sqlite3_bin_behaviors();

my $has_sqlite;
my $sqlite3_bin;
eval {
    $sqlite3_bin = -f 'sqlite3' ? './sqlite3' : 'sqlite3';
    my $sqlite3_version = `$sqlite3_bin --version`;
    chomp $sqlite3_version;
    $has_sqlite = $sqlite3_version eq $DBD::SQLite::sqlite_version ? 1 : 0;
};
unless ($has_sqlite) {
    diag "requires sqlite3 $DBD::SQLite::sqlite_version executable for extra tests";
}

plan tests => @values * (3 + $has_sqlite) * @types + 1;

for my $type (@types) {
    my $typename = $type || 'default';
    for my $value (@values) {
        my $dbh = connect_ok( RaiseError => 1, AutoCommit => 1 );
        $dbh->do("create table foo (value $type)");
        ok $dbh->do('insert into foo values(?)', undef, $value), "inserting $value into a $typename column";
        my ($got) = $dbh->selectrow_array('select value from foo where value = ?', undef, $value);
        $got = '' unless defined $got;
        if ($got eq $value) {
            pass "type: $typename got: $got expected: $value";
        }
        else {
            my $old_behavior = $prior_DBD_SQLITE_1_30_behaviors{$type}{$value};
            $old_behavior = '' unless defined $old_behavior;
            my $sqlite3_behavior = $sqlite3_bin_behaviors{$type}{$value};
            $sqlite3_behavior = '' unless defined $sqlite3_behavior;
            if ($sqlite3_behavior eq $got) {
                pass "same as the sqlite3 bin: type: $typename got: $got expected: $value sqlite3_behavior: $sqlite3_behavior";
            }
            else {
                if ($old_behavior eq $got) {
                    TODO: {
                        local $TODO = "same as the old behavior";
                        fail "same as the old behavior: type: $typename got: $got expected: $value sqlite3_behavior: $sqlite3_behavior";
                    }
                }
                else {
                    fail "type: $typename got: $got expected: $value old_behavior: $old_behavior sqlite3_behavior: $sqlite3_behavior";
                }
            }
        }

        if ($has_sqlite) {
            my $cmd = "create table f (v $type);insert into f values(\"$value\");select * from f;";
            my $got_from_bin = `$sqlite3_bin -list ':memory:' '$cmd'`;
            chomp $got_from_bin;
            if ($got_from_bin eq $got) {
                pass "sqlite3: type: $typename got: $got expected: $value";
            }
            else {
                TODO: {
                    local $TODO = "sqlite3 shell behaves differently";
                    fail "sqlite3: type: $typename got: $got expected: $value got_from_bin: $got_from_bin";
                }
            }
        }
    }
}

sub prior_DBD_SQLITE_1_30_behaviors {(
    integer => {
        '1.0'               => 1,
        '2.0'               => 2,
        '1.0e+001'          => 10,
        '0000'              => 0,
        '01010101'          => 1010101,
        '0000002100000517'  => 2100000517,
        '0000002200000517'  => 2200000517,
        '0000001e00000517'  => 'inf',
        '00002.000'         => 2,
        '-1.0',             => -1,
        '-2.0',             => -2,
        '-1.0e-001'         => -0.1,
        '-0000'             => 0,
        '-0101'             => -101,
        '-002.00'           => -2,
        '+1',               => 1,
        '+1.0'              => 1,
        '+1.1'              => 1.1,
        '+2.0'              => 2,
        '+1.0e-001'         => 0.1,
        '+0000'             => 0,
        '+0101',            => 101,
        '+002.00'           => 2,
        '1234567890123456789012345678901234567890'  => '1.23456789012346e+39',
        '-1234567890123456789012345678901234567890' => '-1.23456789012346e+39',
        '+1234567890123456789012345678901234567890' => '1.23456789012346e+39',
        '-9223372036854775807'                      => '-9.22337203685478e+18',
        '+9223372036854775806',                     => '9.22337203685478e+18',
        '-9223372036854775808',                     => '-9.22337203685478e+18',
        '+9223372036854775807',                     => '9.22337203685478e+18',
        '-9223372036854775809',                     => '-9.22337203685478e+18',
        '+9223372036854775808',                     => '9.22337203685478e+18',
        '+2147483647',                              => '2147483647',
        '+2147483648',                              => '2147483648',
        '+2147483649',                              => '2147483649',
    },
    real => {
        '1.0'               => 1,
        '2.0'               => 2,
        '1.0e+001'          => 10,
        '0000'              => 0,
        '01010101'          => 1010101,
        '0000002100000517'  => 2100000517,
        '0000002200000517'  => 2200000517,
        '0000001e00000517'  => 'inf',
        '00002.000'         => 2,
        '-1.0',             => -1,
        '-2.0',             => -2,
        '-1.0e-001'         => -0.1,
        '-0000'             => 0,
        '-0101'             => -101,
        '-002.00'           => -2,
        '+1',               => 1,
        '+1.0'              => 1,
        '+1.1'              => 1.1,
        '+2.0'              => 2,
        '+1.0e-001'         => 0.1,
        '+0000'             => 0,
        '+0101',            => 101,
        '+002.00'           => 2,
        '1234567890123456789012345678901234567890'  => '1.23456789012346e+39',
        '-1234567890123456789012345678901234567890' => '-1.23456789012346e+39',
        '+1234567890123456789012345678901234567890' => '1.23456789012346e+39',
        '-9223372036854775807'                      => '',
        '+9223372036854775806',                     => '',
        '-9223372036854775808',                     => '-9.22337203685478e+18',
        '+9223372036854775807',                     => '',
        '-9223372036854775809',                     => '-9.22337203685478e+18',
        '+9223372036854775808',                     => '9.22337203685478e+18',
        '+2147483647',                              => '2147483647',
        '+2147483648',                              => '2147483648',
        '+2147483649',                              => '2147483649',
    },
)}

sub sqlite3_bin_behaviors {(
    integer => {
        '0000001e00000517'      => 'Inf',                   # previously 'inf'
        '+9223372036854775806'  => '9223372036854775806',   # previously 9.22337203685478e+18
        '+9223372036854775807'  => '9223372036854775807',   # previously 9.22337203685478e+18
    },
    real => {
        '0'                     => '0.0',                   # previously 0
        '1'                     => '1.0',                   # previously 1
        '1.0e+001'              => '10.0',                  # previously 10
        '0000'                  => '0.0',                   # previously 0
        '01010101'              => '1010101.0',             # previously 1010101
        '10010101'              => '10010101.0',            # previously 10010101
        '0000002100000517'      => '2100000517.0',          # previously 2100000517
        '0000002200000517'      => '2200000517.0',          # previously 2200000517
        '0000001e00000517'      => 'Inf',                   # previously 'inf'
        '00002.000'             => '2.0',                   # previously 2
        '-1'                    => '-1.0',                  # previously -1
        '-0000'                 => '0.0',                   # previously 0
        '-0101'                 => '-101.0',                # previously -101
        '-002.00'               => '-2.0',                  # previously -2
        '+1'                    => '1.0',                   # previously 1
        '+1.0'                  => '1.0',                   # previously 1
        '+2.0'                  => '2.0',                   # previously 2
        '+0000'                 => '0.0',                   # previously 0
        '+0101'                 => '101.0',                 # previously 101
        '+002.00'               => '2.0',                   # previously 2
        '-2147483646'           => '-2147483646.0',         # previously -2147483646
        '+2147483647'           => '2147483647.0',          # previously 2147483647
        '-2147483647'           => '-2147483647.0',         # previously -2147483647
        '+2147483648'           => '2147483648.0',          # previously 2147483648
        '-2147483648'           => '-2147483648.0',         # previously -2147483648
        '+2147483649'           => '2147483649.0',          # previously 2147483649
    },
)}
