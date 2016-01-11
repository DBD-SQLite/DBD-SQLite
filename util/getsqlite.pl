#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use SQLiteUtil;

my $version = SQLiteUtil::Version->new(shift || (versions())[-1]);
mirror($version);
copy_files($version);
tweak_pod($version);
