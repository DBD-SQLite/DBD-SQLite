use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
BEGIN {
    unless (has_compile_option('ENABLE_ICU')) {
        plan( skip_all => 'requires SQLite ICU plugin to be enabled' );
    }
}
# use if -d ".git", "Test::FailWarnings";

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

done_testing;
