#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use Test::More tests => 22;

use_ok('DBD::SQLite');

my $noprintquerymsg = '(Set ENV{PRINT_QUERY} to true value to see query)';
my $tinfo;

my $dbh = DBI->connect('DBI:SQLite::memory:');
ok( ref $dbh, "create new db" );

# ###### 
# First we create our schema (attached in __DATA__)
#
my $slurp;
while (my $line = <DATA>) {
    $slurp .= $line;
}
QUERY:
for my $query (split m/ ; /xms, $slurp) {

    # remove newline + leading and trailing whitespace.
    chomp $query;
    $query =~ s/^ \s+  //xms;
    $query =~ s/  \s+ $//xms;
    next QUERY if not $query;

    # execute the query.
    my $sth = $dbh->prepare($query);
    $tinfo  = $ENV{PRINT_QUERY}  ?  "prepare: $query"
                                 :  "prepare: $noprintquerymsg";
    ok( ref $sth, $tinfo);
    my $ret = $sth->execute( );
    $tinfo  = $ENV{PRINT_QUERY}  ?  "execute: $query"
                                 :  "execute: $noprintquerymsg";
    ok( $ret, $tinfo);
    
    $sth->finish( );
}

# ######
# Then we test the bug.
# 


# We test with both 'DISTINCT(t.name) [..]' and 'DISTINCT t.name [..]'
#
my $query_with_parens = trim(q{
    SELECT DISTINCT(t.name), t.tagid
        FROM objtagmap m,tags t
    WHERE (m.objid = 1)
    AND   (t.tagid = m.tagid)
});

my $query_without_parens = trim(q{
    SELECT DISTINCT t.name, t.tagid
        FROM objtagmap m,tags t
    WHERE (m.objid = 1)
    AND   (t.tagid = m.tagid)
});

foreach my $query (($query_with_parens, $query_without_parens)) {

    # just to print readable test descriptions.
    my $abbrev = substr $query, 0, 25;

    my $sth = $dbh->prepare($query);
    ok( ref $sth, "prepare $abbrev" );
    my $ret = $sth->execute( );
    ok( $ret, "execute $abbrev" );

    while (my $hres = $sth->fetchrow_hashref) {
        # Here we should get two hash keys: 'name' and 'tagid'.
        ok( exists $hres->{name}, 'exists $hres->{name}' );
        ok( exists $hres->{tagid}, 'exists $hres->{tagid}' );
        if (! exists $hres->{name}) {
	    $Data::Dumper::Varname = '';
            eval 'require Data::Dumper;';
            if (! $@) {
                $Data::Dumper::Varname = 'fetchrow_hashref';
                print {*STDERR} "#[RT #26775] The keys we got was: ",
                      Data::Dumper::Dumper($hres), "\n";
            }
        }
    }
    $sth->finish;
}

$dbh->disconnect;

sub trim {
    my ($string) = @_;
    $string =~ s/^ \s+  //xms;
    $string =~ s/  \s+ $//xms;
    $string =~ s/\s+/ /xms;
    return $string;
}

# DATA has schema for 3 tables. object, tags, and objtagmap.
# We create an article object and a tag, and then we connect the article object with the
# tag.

__DATA__
CREATE TABLE object (
    id INTEGER PRIMARY KEY NOT NULL,
    parent INTEGER NOT NULL DEFAULT 1,
    name VARCHAR(255) NOT NULL,
    type CHAR(16) NOT NULL default 'directory'
);

CREATE TABLE objtagmap (
    id INTEGER PRIMARY KEY NOT NULL,
    objid INTEGER NOT NULL,
    tagid INTEGER NOT NULL
);

CREATE TABLE tags (
    tagid INTEGER PRIMARY KEY NOT NULL,
    name char(32) NOT NULL
);

INSERT INTO object (id, parent, name, type) VALUES
(1, 1, 'All about the the distinct hash key problem, and how to survive
deadly weapons', 'article');

INSERT INTO tags(tagid, name) VALUES (1,'bugs');

INSERT INTO objtagmap(id, objid, tagid) VALUES(1, 1, 1);
