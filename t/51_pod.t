use strict;
use warnings;
use Test::More;

BEGIN {
	plan skip_all =>
		'set $ENV{AUTHOR_TEST} '.
		'to enable this test'
		unless $ENV{AUTHOR_TEST};
}

# Ensure a recent version of Test::Pod
my $min_tp = 1.22;
eval "use Test::Pod $min_tp";
plan skip_all => "Test::Pod $min_tp required for testing POD" if $@;
all_pod_files_ok();
