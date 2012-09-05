#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More tests => 22;
use Test::NoWarnings;
use Encode;

my $unicode = "\x{263A}";  # (decoded) smiley character
ok Encode::is_utf8($unicode), "smiley is correctly decoded";

my $unicode_encoded = encode_utf8($unicode);

{ # tests for an environment where everything is encoded

    my $dbh = connect_ok(sqlite_unicode => 0);
    my $unicode_quoted = $dbh->quote_identifier($unicode_encoded);
    $dbh->do("create table foo (id, $unicode_quoted)");

    ok $dbh->do("insert into foo values (?, ?)", undef, 1, "text"), "insert successfully";
    ok $dbh->do("insert into foo (id, $unicode_quoted) values (?, ?)", undef, 2, "text2"), "insert with unicode name successfully";

    {
        my $sth = $dbh->prepare("select * from foo where id = ?");
        $sth->execute(1);
        my $row = $sth->fetchrow_hashref;
        is $row->{id} => 1, "got correct row";
        is $row->{$unicode_encoded} => "text", "got correct (encoded) unicode column data";
        ok !exists $row->{$unicode}, "(decoded) unicode column does not exist";
    }

    {
        my $sth = $dbh->prepare("select $unicode_quoted from foo where id = ?");
        $sth->execute(1);
        my $row = $sth->fetchrow_hashref;
        is $row->{$unicode_encoded} => "text", "got correct (encoded) unicode column data";
        ok !exists $row->{$unicode}, "(decoded) unicode column does not exist";
    }

    {
        my $sth = $dbh->prepare("select id from foo where $unicode_quoted = ?");
        $sth->execute("text");
        my ($id) = $sth->fetchrow_array;
        is $id => 1, "got correct id by the (encoded) unicode column value";
    }

    {
        my $sth = $dbh->column_info(undef, undef, 'foo', $unicode_encoded);
        my $column_info = $sth->fetchrow_hashref;
        is $column_info->{COLUMN_NAME} => $unicode_encoded, "column_info returns the correctly encoded column name";
    }
}

{ # tests for an environment where everything is decoded

    my $dbh = connect_ok(sqlite_unicode => 1);
    my $unicode_quoted = $dbh->quote_identifier($unicode);
    $dbh->do("create table foo (id, $unicode_quoted)");

    ok $dbh->do("insert into foo values (?, ?)", undef, 1, "text"), "insert successfully";
    ok $dbh->do("insert into foo (id, $unicode_quoted) values (?, ?)", undef, 2, "text2"), "insert with unicode name successfully";

    {
        my $sth = $dbh->prepare("select * from foo where id = ?");
        $sth->execute(1);
        my $row = $sth->fetchrow_hashref;
        is $row->{id} => 1, "got correct row";
        is $row->{$unicode} => "text", "got correct (decoded) unicode column data";
        ok !exists $row->{$unicode_encoded}, "(encoded) unicode column does not exist";
    }

    {
        my $sth = $dbh->prepare("select $unicode_quoted from foo where id = ?");
        $sth->execute(1);
        my $row = $sth->fetchrow_hashref;
        is $row->{$unicode} => "text", "got correct (decoded) unicode column data";
        ok !exists $row->{$unicode_encoded}, "(encoded) unicode column does not exist";
    }

    {
        my $sth = $dbh->prepare("select id from foo where $unicode_quoted = ?");
        $sth->execute("text2");
        my ($id) = $sth->fetchrow_array;
        is $id => 2, "got correct id by the (decoded) unicode column value";
    }

    {
        my $sth = $dbh->column_info(undef, undef, 'foo', $unicode);
        my $column_info = $sth->fetchrow_hashref;
        is $column_info->{COLUMN_NAME} => $unicode, "column_info returns the correctly decoded column name";
    }
}
