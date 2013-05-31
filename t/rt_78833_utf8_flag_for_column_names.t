#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use t::lib::Test;
use Test::More;
BEGIN {
	if ( $] >= 5.008005 ) {
		plan( tests => 29 * 2 + 1 );
	} else {
		plan( skip_all => 'Unicode is not supported before 5.8.5' );
	}
}
use Test::NoWarnings;
use Encode;

unicode_test("\x{263A}");  # (decoded) smiley character
unicode_test("\x{0100}");  # (decoded) capital A with macron

sub unicode_test {
    my $unicode = shift;

    ok Encode::is_utf8($unicode), "correctly decoded";

    my $unicode_encoded = encode_utf8($unicode);

    { # tests for an environment where everything is encoded

        my $dbh = connect_ok(sqlite_unicode => 0);
        $dbh->do("pragma foreign_keys = on");
        my $unicode_quoted = $dbh->quote_identifier($unicode_encoded);
        $dbh->do("create table $unicode_quoted (id, $unicode_quoted primary key)");
        $dbh->do("create table bar (id, ref references $unicode_quoted ($unicode_encoded))");

        ok $dbh->do("insert into $unicode_quoted values (?, ?)", undef, 1, "text"), "insert successfully";
        ok $dbh->do("insert into $unicode_quoted (id, $unicode_quoted) values (?, ?)", undef, 2, "text2"), "insert with unicode name successfully";

        {
            my $sth = $dbh->prepare("insert into $unicode_quoted (id) values (:$unicode_encoded)");
            $sth->bind_param(":$unicode_encoded", 5);
            $sth->execute;
            my ($id) = $dbh->selectrow_array("select id from $unicode_quoted where id = :$unicode_encoded", undef, 5);
            is $id => 5, "unicode placeholders";
        }

        {
            my $sth = $dbh->prepare("select * from $unicode_quoted where id = ?");
            $sth->execute(1);
            my $row = $sth->fetchrow_hashref;
            is $row->{id} => 1, "got correct row";
            is $row->{$unicode_encoded} => "text", "got correct (encoded) unicode column data";
            ok !exists $row->{$unicode}, "(decoded) unicode column does not exist";
        }

        {
            my $sth = $dbh->prepare("select $unicode_quoted from $unicode_quoted where id = ?");
            $sth->execute(1);
            my $row = $sth->fetchrow_hashref;
            is $row->{$unicode_encoded} => "text", "got correct (encoded) unicode column data";
            ok !exists $row->{$unicode}, "(decoded) unicode column does not exist";
        }

        {
            my $sth = $dbh->prepare("select id from $unicode_quoted where $unicode_quoted = ?");
            $sth->execute("text");
            my ($id) = $sth->fetchrow_array;
            is $id => 1, "got correct id by the (encoded) unicode column value";
        }

        {
            my $sth = $dbh->column_info(undef, undef, $unicode_encoded, $unicode_encoded);
            my $column_info = $sth->fetchrow_hashref;
            is $column_info->{COLUMN_NAME} => $unicode_encoded, "column_info returns the correctly encoded column name";
        }

        {
            my $sth = $dbh->primary_key_info(undef, undef, $unicode_encoded);
            my $primary_key_info = $sth->fetchrow_hashref;
            is $primary_key_info->{COLUMN_NAME} => $unicode_encoded, "primary_key_info returns the correctly encoded primary key name";
        }

        {
            my $sth = $dbh->foreign_key_info(undef, undef, $unicode_encoded, undef, undef, 'bar');
            my $foreign_key_info = $sth->fetchrow_hashref;
            is $foreign_key_info->{PKCOLUMN_NAME} => $unicode_encoded, "foreign_key_info returns the correctly encoded foreign key name";
        }

        {
            my $sth = $dbh->table_info(undef, undef, $unicode_encoded);
            my $table_info = $sth->fetchrow_hashref;
            is $table_info->{TABLE_NAME} => $unicode_encoded, "table_info returns the correctly encoded table name";
        }
    }

    { # tests for an environment where everything is decoded

        my $dbh = connect_ok(sqlite_unicode => 1);
        $dbh->do("pragma foreign_keys = on");
        my $unicode_quoted = $dbh->quote_identifier($unicode);
        $dbh->do("create table $unicode_quoted (id, $unicode_quoted primary key)");
        $dbh->do("create table bar (id, ref references $unicode_quoted ($unicode_quoted))");

        ok $dbh->do("insert into $unicode_quoted values (?, ?)", undef, 1, "text"), "insert successfully";
        ok $dbh->do("insert into $unicode_quoted (id, $unicode_quoted) values (?, ?)", undef, 2, "text2"), "insert with unicode name successfully";

        {
            my $sth = $dbh->prepare("insert into $unicode_quoted (id) values (:$unicode)");
            $sth->bind_param(":$unicode", 5);
            $sth->execute;
            my ($id) = $dbh->selectrow_array("select id from $unicode_quoted where id = :$unicode", undef, 5);
            is $id => 5, "unicode placeholders";
        }

        {
            my $sth = $dbh->prepare("select * from $unicode_quoted where id = ?");
            $sth->execute(1);
            my $row = $sth->fetchrow_hashref;
            is $row->{id} => 1, "got correct row";
            is $row->{$unicode} => "text", "got correct (decoded) unicode column data";
            ok !exists $row->{$unicode_encoded}, "(encoded) unicode column does not exist";
        }

        {
            my $sth = $dbh->prepare("select $unicode_quoted from $unicode_quoted where id = ?");
            $sth->execute(1);
            my $row = $sth->fetchrow_hashref;
            is $row->{$unicode} => "text", "got correct (decoded) unicode column data";
            ok !exists $row->{$unicode_encoded}, "(encoded) unicode column does not exist";
        }

        {
            my $sth = $dbh->prepare("select id from $unicode_quoted where $unicode_quoted = ?");
            $sth->execute("text2");
            my ($id) = $sth->fetchrow_array;
            is $id => 2, "got correct id by the (decoded) unicode column value";
        }

        {
            my $sth = $dbh->column_info(undef, undef, $unicode, $unicode);
            my $column_info = $sth->fetchrow_hashref;
            is $column_info->{COLUMN_NAME} => $unicode, "column_info returns the correctly decoded column name";
        }

        {
            my $sth = $dbh->primary_key_info(undef, undef, $unicode);
            my $primary_key_info = $sth->fetchrow_hashref;
            is $primary_key_info->{COLUMN_NAME} => $unicode, "primary_key_info returns the correctly decoded primary key name";
        }

        {
            my $sth = $dbh->foreign_key_info(undef, undef, $unicode, undef, undef, 'bar');
            my $foreign_key_info = $sth->fetchrow_hashref;
            is $foreign_key_info->{PKCOLUMN_NAME} => $unicode, "foreign_key_info returns the correctly decoded foreign key name";
        }

        {
            my $sth = $dbh->table_info(undef, undef, $unicode);
            my $table_info = $sth->fetchrow_hashref;
            is $table_info->{TABLE_NAME} => $unicode, "table_info returns the correctly decoded table name";
        }
    }
}
