package t::lib::Test;

# Support code for DBD::SQLite tests

use strict;

# Always load the DBI module
use DBI ();

# Delete temporary files
sub clean {
	my @files = qw{
		foo
		foo-journal
	};
	foreach my $file ( @files ) {
		unlink $file if -e $file;
	}
}

# Clean up temporary test files both at the beginning and end of the
# test script.
BEGIN { clean() }
END   { clean() }

1;
