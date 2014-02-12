#!/usr/bin/perl

use strict;
use FindBin;
use File::Spec::Functions ':ALL';
use LWP::Simple qw(getstore);
use ExtUtils::Command;

chdir(catdir($FindBin::Bin, updir())) or die "Failed to change to the dist root";

my $version = shift || die "Usage: getsqlite.pl <version>\n";

# The http://www.sqlite.org/sqlite-amalgamation-$version.tar.gz name format changed starting with 3.7.4
# We will let user specify any SQLite version in either the old or new format, and normalize.
my @version_parts;
if ($version =~ m/^[0-9](?:\.[0-9]+){0,3}$/) {
    # $version is X.Y+.Z+.W+ style used for SQLite <= 3.7.3
    @version_parts = map { (0 + $_) } (split /\./, $version);
}
elsif ($version =~ m/^[0-9](?:[0-9]{2}){0,3}$/) {
    # $version is XYYZZWW style used for SQLite >= 3.7.4
    @version_parts = map { 0 + $_ } ((substr $version, 0, 1), ((substr $version, 1) =~ m/[0-9]{2}/g));
}
else {
    die "improper <version> format for [$version]\n";
}
my $version_as_num = sprintf( q{%u%02u%02u%02u}, @version_parts );
my $version_dotty = join '.', ($version_parts[3] ? @version_parts : @version_parts[0..2]);
my $is_pre_30704_style = ($version_as_num < 3070400);
my $version_for_url = $is_pre_30704_style ? $version_dotty : $version_as_num;
my $year = "";
if ($version_as_num >= 3080300) {
  $year = "2014/";
} elsif ($version_as_num >= 3071600) {
  $year = "2013/";
}

my $url_to_download = qq{http://www.sqlite.org/${year}sqlite-}
    . ($is_pre_30704_style ? q{amalgamation} : q{autoconf})
    . qq{-$version_for_url.tar.gz};
print("downloading $url_to_download\n");
my $rv = getstore(
	$url_to_download, 
	"sqlite.tar.gz",
);
die "Failed to download" if $rv != 200;
print("done\n");

rm_rf('sqlite') || rm_rf("sqlite-$version_dotty") || rm_rf("sqlite-amalgamation-$version_dotty");
xsystem("tar zxvf sqlite.tar.gz");
chdir("sqlite") || chdir("sqlite-$version_dotty") || chdir("sqlite-amalgamation-$version_dotty") || chdir("sqlite-autoconf-$version") || chdir("sqlite-autoconf-$version_as_num")
|| die "SQLite directory not found.";



# extract fts3_tokenizer.h from the amalgamation, because this is needed
# for compiling dbdimp.c
open my $amalg, "sqlite3.c"                or die $!;
open my $fts3_tok, ">", "fts3_tokenizer.h" or die $!;

for (<$amalg>) {
  print $fts3_tok $_  if    m{^/\*+ Begin file fts3_tokenizer\.h}
                        ... m{^/\*+ End of fts3_tokenizer\.h};
}
close $amalg;
close $fts3_tok;

xsystem("cp sqlite3.c ../");
xsystem("cp sqlite3.h ../");
xsystem("cp sqlite3ext.h ../");
xsystem("cp fts3_tokenizer.h ../");

exit(0);


sub xsystem {
    local $, = ", ";
    print("@_\n");
    my $ret = system(@_);
    if ($ret != 0) {
       die "system(@_) failed: $?";
    }
}


