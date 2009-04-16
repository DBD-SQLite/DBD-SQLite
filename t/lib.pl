#   lib.pl is the file where database specific things should live,
#   whereever possible. For example, you define certain constants
#   here and the like.

use strict;
use File::Spec ();

use vars qw($childPid);

$::COL_NULLABLE = 1;
$::COL_KEY = 2;

#   This function generates a mapping of ANSI type names to
#   database specific type names; it is called by TableDefinition().
#
sub AnsiTypeToDb ($;$) {
    my ($type, $size) = @_;
    my ($ret);

    if ((lc $type) eq 'char'  ||  (lc $type) eq 'varchar') {
	$size ||= 1;
	return (uc $type) . " ($size)";
    } elsif ((lc $type) eq 'blob'  ||  (lc $type) eq 'real'  ||
	       (lc $type) eq 'integer') {
	return uc $type;
    } elsif ((lc $type) eq 'int') {
	return 'INTEGER';
    } else {
	warn "Unknown type $type\n";
	$ret = $type;
    }
    $ret;
}


#
#   This function generates a table definition based on an
#   input list. The input list consists of references, each
#   reference referring to a single column. The column
#   reference consists of column name, type, size and a bitmask of
#   certain flags, namely
#
#       $COL_NULLABLE - true, if this column may contain NULL's
#       $COL_KEY - true, if this column is part of the table's
#           primary key
#
#   Hopefully there's no big need for you to modify this function,
#   if your database conforms to ANSI specifications.
#

sub TableDefinition ($@) {
    my($tablename, @cols) = @_;
    my($def);

    #
    #   Should be acceptable for most ANSI conformant databases;
    #
    #   msql 1 uses a non-ANSI definition of the primary key: A
    #   column definition has the attribute "PRIMARY KEY". On
    #   the other hand, msql 2 uses the ANSI fashion ...
    #
    my($col, @keys, @colDefs, $keyDef);

    #
    #   Count number of keys
    #
    @keys = ();
    foreach $col (@cols) {
	if ($$col[2] & $::COL_KEY) {
	    push(@keys, $$col[0]);
	}
    }

    foreach $col (@cols) {
	my $colDef = $$col[0] . " " . AnsiTypeToDb($$col[1], $$col[2]);
	if (!($$col[3] & $::COL_NULLABLE)) {
	    $colDef .= " NOT NULL";
	}
	push(@colDefs, $colDef);
    }
    if (@keys) {
	$keyDef = ", PRIMARY KEY (" . join(", ", @keys) . ")";
    } else {
	$keyDef = "";
    }
    $def = sprintf("CREATE TABLE %s (%s%s)", $tablename,
		   join(", ", @colDefs), $keyDef);
}

open (STDERR, ">&STDOUT") || die "Cannot redirect stderr" ;  
select (STDERR) ; $| = 1 ;
select (STDOUT) ; $| = 1 ;


#
#   The Testing() function builds the frame of the test; it can be called
#   in many ways, see below.
#
#   Usually there's no need for you to modify this function.
#
#       Testing() (without arguments) indicates the beginning of the
#           main loop; it will return, if the main loop should be
#           entered (which will happen twice, once with $state = 1 and
#           once with $state = 0)
#       Testing('off') disables any further tests until the loop ends
#       Testing('group') indicates the begin of a group of tests; you
#           may use this, for example, if there's a certain test within
#           the group that should make all other tests fail.
#       Testing('disable') disables further tests within the group; must
#           not be called without a preceding Testing('group'); by default
#           tests are enabled
#       Testing('enabled') reenables tests after calling Testing('disable')
#       Testing('finish') terminates a group; any Testing('group') must
#           be paired with Testing('finish')
#
#   You may nest test groups.
#
{
    # Note the use of the pairing {} in order to get local, but static,
    # variables.
    my (@stateStack, $count, $off);

    $count = 0;

    sub Testing(;$) {
	my ($command) = shift;
	if (!defined($command)) {
	    @stateStack = ();
	    $off = 0;
	    if ($count == 0) {
		++$count;
		$::state = 1;
	    } elsif ($count == 1) {
		my($d);
		if ($off) {
		    print "1..0\n";
		    exit 0;
		}
		++$count;
		$::state = 0;
		print "1..$::numTests\n";
	    } else {
		return 0;
	    }
	    if ($off) {
		$::state = 1;
	    }
	    $::numTests = 0;
	} elsif ($command eq 'off') {
	    $off = 1;
	    $::state = 0;
	} elsif ($command eq 'group') {
	    push(@stateStack, $::state);
	} elsif ($command eq 'disable') {
	    $::state = 0;
	} elsif ($command eq 'enable') {
	    if ($off) {
		$::state = 0;
	    } else {
		my $s;
		$::state = 1;
		foreach $s (@stateStack) {
		    if (!$s) {
			$::state = 0;
			last;
		    }
		}
	    }
	    return;
	} elsif ($command eq 'finish') {
	    $::state = pop(@stateStack);
	} else {
	    die("Testing: Unknown argument\n");
	}
	return 1;
    }


#
#   Read a single test result
#

    sub Test ($;$$) {
	my($result, $error, $diag) = @_;
       
        ++$::numTests;
	if ($count == 2) {
	    if (defined($diag)) {
	        printf("$diag%s", (($diag =~ /\n$/) ? "" : "\n"));
	    }
	    if ($::state || $result) {
		print "ok $::numTests ". (defined($error) ? "$error\n" : "\n");
		return 1;
	    } else {
		my ($pack, $file, $line) = caller();
		print("not ok $::numTests at line $line - " .
			(defined($error) ? "$error\n" : "\n"));
		print("FAILED Test $::numTests - " .
			(defined($error) ? "$error\n" : "\n"));
		return 0;
	    }
	}
	return 1;
    }
}


#
#   Print a DBI error message
#
sub DbiError ($$) {
    my($rc, $err) = @_;
    $rc ||= 0;
    $err ||= '';
    print "Test $::numTests: DBI error $rc, $err\n";
}

sub ErrMsg { print (@_); }
sub ErrMsgF { printf (@_); }

1;
