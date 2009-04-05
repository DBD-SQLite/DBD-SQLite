#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 12;
use t::lib::Test;

my $dbh = connect_ok();

$dbh->do('drop table if exists artist');
$dbh->do(<<'');
create table artist (
  id int not null primary key,
  name text not null
)

ok ( $dbh->do(q/insert into artist (id,name) values(1, 'Leonardo da Vinci')/), 'insert');

# length works in a select list...
my $sth = $dbh->prepare('select length(name) from artist where id=?');
ok ( $sth->execute(1), 'execute, select length' );
is ( $sth->fetchrow_arrayref->[0], 17, 'select length result' );

# but not in a where clause...
my $statement = 'select count(*) from artist where length(name) > ?';

# ...not with bind args
$sth = $dbh->prepare($statement);
ok ( $sth->execute(2), "execute: $statement : [2]" );
is ( $sth->fetchrow_arrayref->[0], 1, "result of: $statement : [2]" );
# ...works without bind args, though!
$statement =~ s/\?/2/;
$sth = $dbh->prepare($statement);
ok ( $sth->execute, "execute: $statement" );
is ( $sth->fetchrow_arrayref->[0], 1, "result of: $statement" );

### it does work, however, from the sqlite3 CLI...
# require Shell;
# $Shell::raw = 1;
# is ( sqlite3($db, "'$statement;'"), "1\n", 'sqlite3 CLI' );

# (Jess Robinson discovered that it passes with an arg of 1)
$statement =~ s/2/1/;
$sth = $dbh->prepare($statement);
ok ( $sth->execute, "execute: $statement" );
is ( $sth->fetchrow_arrayref->[0], 1, "result of: $statement" );

# (...but still not with bind args)
$statement =~ s/1/?/;
$sth = $dbh->prepare($statement);
ok ( $sth->execute(1), "execute: $statement : [1]" );
is ( $sth->fetchrow_arrayref->[0], 1, "result of: $statement [1]" );
