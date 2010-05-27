#!/usr/bin/perl

use strict;
BEGIN {
    $|  = 1;
    $^W = 1;
}

use t::lib::Test;
use Test::More;
BEGIN {
    require DBD::SQLite;
    if (DBD::SQLite->can('compile_options')
        && grep /ENABLE_ICU/, DBD::SQLite::compile_options()) {
        plan( tests => 16 );
    } else {
        plan( skip_all => 'requires SQLite ICU plugin to be enabled' );
    }
}
# use Test::NoWarnings;

my @isochars = (ord("K"), 0xf6, ord("n"), ord("i"), ord("g"));
my $koenig   = pack("U*", @isochars);
my $konig    = 'konig';
utf8::encode($koenig);

{   # without ICU
    my @expected = ($koenig, $konig);

    my $dbh = connect_ok();
    $dbh->do('create table foo (bar text)');
    foreach my $str (reverse @expected) {
        $dbh->do('insert into foo values(?)', undef, $str);
    }
    my $sth = $dbh->prepare('select bar from foo order by bar');
    $sth->execute;
    my @got;
    while(my ($value) = $sth->fetchrow_array) {
        push @got, $value;
    }
    for (my $i = 0; $i < @expected; $i++) {
        is $got[$i] => $expected[$i], "got: $got[$i]";
    }
}

{   # with ICU
    my @expected = ($konig, $koenig);

    my $dbh = connect_ok();
    eval { $dbh->do('select icu_load_collation("de_DE", "german")') };
    ok !$@, "installed icu collation";
    # XXX: as of this writing, a warning is known to be printed.
    $dbh->do('create table foo (bar text collate german)');
    foreach my $str (reverse @expected) {
        $dbh->do('insert into foo values(?)', undef, $str);
    }
    my $sth = $dbh->prepare('select bar from foo order by bar');
    $sth->execute;
    my @got;
    while(my ($value) = $sth->fetchrow_array) {
        push @got, $value;
    }
    for (my $i = 0; $i < @expected; $i++) {
        is $got[$i] => $expected[$i], "got: $got[$i]";
    }
}

{   # more ICU
    my @expected = qw(
        flusse
        Flusse
        fluße
        Fluße
        flüsse
        flüße
        Fuße
    );

    my $dbh = connect_ok();
    eval { $dbh->do('select icu_load_collation("de_DE", "german")') };
    ok !$@, "installed icu collation";
    # XXX: as of this writing, a warning is known to be printed.
    $dbh->do('create table foo (bar text collate german)');
    foreach my $str (reverse @expected) {
        $dbh->do('insert into foo values(?)', undef, $str);
    }
    my $sth = $dbh->prepare('select bar from foo order by bar');
    $sth->execute;
    my @got;
    while(my ($value) = $sth->fetchrow_array) {
        push @got, $value;
    }
    for (my $i = 0; $i < @expected; $i++) {
        is $got[$i] => $expected[$i], "got: $got[$i]";
    }
}
