#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use lib "t/lib";
use SQLiteTest qw/connect_ok @CALL_FUNCS/;
use Test::More;
use DBD::SQLite::Constants qw/:database_connection_configuration_options/;

plan tests => 38 * @CALL_FUNCS + 3;

# LOOKASIDE
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'LOOKASIDE is not supported', 2 if !SQLITE_DBCONFIG_LOOKASIDE;
	    my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
        eval { $dbh->$func(SQLITE_DBCONFIG_LOOKASIDE, 1, 'db_config') };
        ok $@, 'LOOKASIDE is not supported';
        like $@ => qr/LOOKASIDE is not supported/;
    }
}

# MAINDBNAME
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'MAINDBNAME is not supported', 2 if !SQLITE_DBCONFIG_MAINDBNAME;
    	my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
        eval { $dbh->$func(SQLITE_DBCONFIG_MAINDBNAME, 1, 'db_config') };
        ok $@, 'MAINDBNAME is not supported';
        like $@ => qr/MAINDBNAME is not supported/;
    }
}

# ENABLE_FKEY
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'ENABLE_FKEY is not supported', 3 if !SQLITE_DBCONFIG_ENABLE_FKEY;
    	my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
        my $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_FKEY, -1, 'db_config');
        diag "current ENABLE_FKEY value: $ret";

        $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_FKEY, 1, 'db_config');
        is $ret => 1, 'enable foreign key';

        # TODO: add foreign key check

        $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_FKEY, 0, 'db_config');
        is $ret => 0, 'disable foreign key';
    }
}

# ENABLE_TRIGGER
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'ENABLE_TRIGGER is not supported', 3 if !SQLITE_DBCONFIG_ENABLE_TRIGGER;
    	my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
        my $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_TRIGGER, -1, 'db_config');
        diag "current ENABLE_TRIGGER value: $ret";

        $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_TRIGGER, 1, 'db_config');
        is $ret => 1, 'enable trigger';

        # TODO: add trigger check

        $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_TRIGGER, 0, 'db_config');
        is $ret => 0, 'disable trigger';
    }
}

# ENABLE_FTS3_TOKENIZER
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'ENABLE_FTS3_TOKENIZER is not supported', 3 if !SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER;
    	my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
        my $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER, -1, 'db_config');
        diag "current ENABLE_FTS3_TOKENIZER value: $ret";

        $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER, 1, 'db_config');
        is $ret => 1, 'enable fts3_tokenizer';

        # TODO: add fts3_tokenizer check

        $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER, 0, 'db_config');
        is $ret => 0, 'disable fts3_tokenizer';
    }
}

# ENABLE_LOAD_EXTENSION
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'ENABLE_LOAD_EXTENSION is not supported', 3 if !SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION;
    	my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
        my $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION, -1, 'db_config');
        diag "current ENABLE_LOAD_EXTENSION value: $ret";

        $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION, 1, 'db_config');
        is $ret => 1, 'enable load_extension';

        # TODO: add load_extension check

        $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION, 0, 'db_config');
        is $ret => 0, 'disable load_extension';
    }
}

# NO_CKPT_ON_CLOSE
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'NO_CKPT_ON_CLOSE is not supported', 3 if !SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE;
    	my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
        my $ret = $dbh->$func(SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE, -1, 'db_config');
        diag "current NO_CKPT_ON_CLOSE value: $ret";

        $ret = $dbh->$func(SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE, 1, 'db_config');
        is $ret => 1, 'no checkpoint on close';

        # TODO: add checkpoint check

        $ret = $dbh->$func(SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE, 0, 'db_config');
        is $ret => 0, 'checkpoint on close';
    }
}

# ENABLE_QPSG
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'ENABLE_QPSG is not supported', 3 if !SQLITE_DBCONFIG_ENABLE_QPSG;
    	my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
        my $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_QPSG, -1, 'db_config');
        diag "current ENABLE_OPSG value: $ret";

        $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_QPSG, 1, 'db_config');
        is $ret => 1, 'enable query planner stability guarantee';

        # TODO: add qpsg check

        $ret = $dbh->$func(SQLITE_DBCONFIG_ENABLE_QPSG, 0, 'db_config');
        is $ret => 0, 'disable query planner stability guarantee';
    }
}

# TRIGGER_EQP
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'TRIGGER_EQP is not supported', 3 if !SQLITE_DBCONFIG_TRIGGER_EQP;
    	my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
        my $ret = $dbh->$func(SQLITE_DBCONFIG_TRIGGER_EQP, -1, 'db_config');
        diag "current TRIGGER_EQP value: $ret";

        $ret = $dbh->$func(SQLITE_DBCONFIG_TRIGGER_EQP, 1, 'db_config');
        is $ret => 1, 'trigger explain query plan';

        # TODO: add trigger check

        $ret = $dbh->$func(SQLITE_DBCONFIG_TRIGGER_EQP, 0, 'db_config');
        is $ret => 0, 'no trigger explain query plan';
    }
}

# RESET_DATABASE
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'RESET_DATABASE is not supported', 3 if !SQLITE_DBCONFIG_RESET_DATABASE;
    	my $dbh = connect_ok(RaiseError => 1, PrintError => 0);
        my $ret = $dbh->$func(SQLITE_DBCONFIG_RESET_DATABASE, -1, 'db_config');
        diag "current RESET_DATABASE value: $ret";

        $ret = $dbh->$func(SQLITE_DBCONFIG_RESET_DATABASE, 1, 'db_config');
        is $ret => 1, 'enable reset database';

        # TODO: add reset check

        $ret = $dbh->$func(SQLITE_DBCONFIG_RESET_DATABASE, 0, 'db_config');
        is $ret => 0, 'disable reset database';
    }
}

# DEFENSIVE
for my $func (@CALL_FUNCS) {
    SKIP: {
        skip 'DEFENSIVE is not supported', 8 if !SQLITE_DBCONFIG_DEFENSIVE;
    	my $dbh = connect_ok(RaiseError => 1, PrintError => 0);

        my $sql = 'CREATE TABLE foo (id, text)';
        $dbh->do($sql);
        $dbh->do('PRAGMA writable_schema=ON');
        my $row = $dbh->selectrow_hashref('SELECT * FROM sqlite_master WHERE name = ?', {Slice => +{}}, 'foo');
        is $row->{sql} => $sql, 'found sql';

        my $ret = $dbh->$func(SQLITE_DBCONFIG_DEFENSIVE, -1, 'db_config');
        diag "current DEFENSIVE value: $ret";

        $ret = $dbh->$func(SQLITE_DBCONFIG_DEFENSIVE, 1, 'db_config');
        is $ret => 1;
        eval { $dbh->do('UPDATE sqlite_master SET name = ? WHERE name = ?', undef, 'bar', 'foo'); };
        ok $@, "updating sqlite_master is prohibited";
        like $@ => qr/table sqlite_master may not be modified/;

        $ret = $dbh->$func(SQLITE_DBCONFIG_DEFENSIVE, 0, 'db_config');
        is $ret => 0;
        $ret = $dbh->do('UPDATE sqlite_master SET name = ? WHERE name = ?', undef, 'bar', 'foo');
        ok $ret, 'updating sqlite_master is succeeded';
        $row = $dbh->selectrow_hashref('SELECT * FROM sqlite_master WHERE name = ?', {Slice => +{}}, 'foo');
        ok !$row, 'sql not found';
    }
}

# DEFENSIVE at connection
SKIP: {
    skip 'DEFENSIVE is not supported', 8 if !SQLITE_DBCONFIG_DEFENSIVE;
    my $dbh = connect_ok(RaiseError => 1, PrintError => 0, sqlite_defensive => 1);

    my $sql = 'CREATE TABLE foo (id, text)';
    $dbh->do($sql);
    $dbh->do('PRAGMA writable_schema=ON');
    eval { $dbh->do('UPDATE sqlite_master SET name = ? WHERE name = ?', undef, 'bar', 'foo'); };
    ok $@, "updating sqlite_master is prohibited";
    like $@ => qr/table sqlite_master may not be modified/;
}
