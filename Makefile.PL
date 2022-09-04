# From ExtUtils::MakeMaker 6.48 and DBI 1.43
use 5.006;
use strict;
use ExtUtils::MakeMaker;
use Config;
use File::Spec;

sub DEVELOPER_ONLY () {
	return -d '.git' ? 1 : 0;
}

# Some dependencies need to be more aggressive on Windows
sub WINLIKE () {
	return 1 if $^O eq 'MSWin32';
	return 1 if $^O eq 'cygwin';
	return 1 if $^O eq 'msys';
	return '';
}

# Make setting optional MakeMaker parameters more readable
sub OPTIONAL {
	return () unless $ExtUtils::MakeMaker::VERSION ge shift;
	return @_;
}

# Are we upgrading from a critically out of date version?
eval {
	require DBD::SQLite;
	if ( $DBD::SQLite::VERSION < 1.0 ) {
		print <<EOT;

**** WARNING **** WARNING **** WARNING **** WARNING **** WARNING ****

Your version of DBD::SQLite currently installed ($DBD::SQLite::VERSION) uses
the old sqlite database format. This version of DBD::SQLite will *NOT*
open these files, and installing this module may cause problems on your
system. If this is a live environment you should upgrade with caution.

To upgrade a database, download and install both sqlite 2.x and 3.x from
http://www.sqlite.org/ and issue:

  sqlite OLD.DB .dump | sqlite3 NEW.DB

DBD::SQLite will NOT automatically upgrade a database for you, and using
this version against an old SQLite database WILL lead to database
corruption.

EOT
		if ( prompt("Continue?", "N") !~ /^y/i ) {
			print "Exiting\n";
			exit(-1);
		}
	}
};

# Because DBI generates a postamble at configure-time, we need
# the required version of DBI very early.
my $DBI_required = 1.57;
eval {
	require DBI;
};
if ( $@ or DBI->VERSION < $DBI_required ) {
	print "DBI $DBI_required is required to configure this module; please install it or upgrade your CPAN/CPANPLUS shell.\n";
	exit(0);
}

# See if we have a C compiler
# The following code is adapted from Module::Install::Can
SCOPE: {
	# Fix Cygwin bug on maybe_command();
	if ( $^O eq 'cygwin' ) {
		require ExtUtils::MM_Cygwin;
		require ExtUtils::MM_Win32;
		if ( ! defined(&ExtUtils::MM_Cygwin::maybe_command) ) {
			*ExtUtils::MM_Cygwin::maybe_command = sub {
				my ($self, $file) = @_;
				if ($file =~ m{^/cygdrive/}i and ExtUtils::MM_Win32->can('maybe_command')) {
					ExtUtils::MM_Win32->maybe_command($file);
				} else {
					ExtUtils::MM_Unix->maybe_command($file);
				}
			}
		}
	}

	sub can_run {
		my $cmd = shift;
		my $_cmd = $cmd;
		return $_cmd if (-x $_cmd or $_cmd = MM->maybe_command($_cmd));

		for my $dir ( (split /$Config::Config{path_sep}/, $ENV{PATH}), '.' ) {
			next if $dir eq '';
			my $abs = File::Spec->catfile($dir, $_[1]);
			return $abs if (-x $abs or $abs = MM->maybe_command($abs));
		}

		return;
	}

	sub can_cc {
		my @chunks = split(/ /, $Config::Config{cc}) or return;

		# $Config{cc} may contain args; try to find out the program part
		while ( @chunks ) {
			return can_run("@chunks") || (pop(@chunks), next);
		}

		return;
	}

	unless ( can_cc() ) {
		print "We can't locate a C compiler from your Config.pm.\n";
		exit(0);
	}
}

# Determine if we are going to use the provided SQLite code, or an already-
# installed copy. To this end, look for two command-line parameters:
#
#    USE_LOCAL_SQLITE -- If non-false, force use of the installed version
#    SQLITE_LOCATION  -- If passed, look for headers and libs under this root
#
# In absense of either of those, expect SQLite 3.X.X libs and headers in the
# common places known to Perl or the C compiler.
# 
# Note to Downstream Packagers:
# This block is if ( 0 ) to discourage casual users building against
# the system SQLite. We expect that anyone sophisticated enough to use
# a system sqlite is also sophisticated enough to have a patching system
# that can change the if ( 0 ) to if ( 1 )
my ($sqlite_local, $sqlite_base, $sqlite_lib, $sqlite_inc);
if ( 0 ) {
	require File::Spec;
	if ( $sqlite_base = (grep(/SQLITE_LOCATION=.*/, @ARGV))[0] ) {
		$sqlite_base =~ /=(.*)/;
		$sqlite_base = $1;
		$sqlite_lib = File::Spec->catdir( $sqlite_base, 'lib'     );
		$sqlite_inc = File::Spec->catdir( $sqlite_base, 'include' );
	}
	if ( $sqlite_local = (grep(/USE_LOCAL_SQLITE=.*/, @ARGV))[0] ) {
		$sqlite_local =~ /=(.*)/;
		$sqlite_local = "$1" ? 1 : 0;
		if ( $sqlite_local ) {
			# Keep these from making into CFLAGS/LDFLAGS
			undef $sqlite_lib;
			undef $sqlite_inc;
		}
	}
	if ( my $my_inc = (grep /SQLITE_INC=.*/, @ARGV)[0] ) {
		$my_inc =~ /=(.*)/;
		$sqlite_inc = $1;
	}
	if ( my $my_lib = (grep /SQLITE_LIB=.*/, @ARGV)[0] ) {
		$my_lib =~ /=(.*)/;
		$sqlite_lib = $1;
	}

	# Now check for a compatible sqlite3
	unless ( $sqlite_local ) {
		my ($dir, $file, $fh, $version);
		print "Checking installed SQLite version...\n" if $ENV{AUTOMATED_TESTING};
		if ( $sqlite_inc ) {
			open($fh, '< ' , File::Spec->catfile($sqlite_inc, 'sqlite3.h'))
				or die "Error opening sqlite3.h in $sqlite_inc: $!";
			while ( defined($_ = <$fh>) ) {
				if (/\#define\s+SQLITE_VERSION_NUMBER\s+(\d+)/) {
					$version = $1;
					last;
				}
			}
			close($fh);
		} else {
			# Go hunting for the file (Matt: Add more dirs here as you see fit)
			foreach $dir ( [ qw(usr include) ], [ qw(usr local include) ] ) {
				$file = File::Spec->catfile('', @$dir, 'sqlite3.h');
				next unless (-f $file);
				open($fh, "<", $file) or die "Error opening $file: $!";
				while ( defined($_ = <$fh>) ) {
					if (/\#define\s+SQLITE_VERSION_NUMBER\s+(\d+)/) {
						$version = $1;
						last;
					}
				}
				close($fh);
				last if $version;
			}
		}
		unless ( $version && ($version >= 3006000) ) {
			warn "SQLite version must be at least 3.6.0. No header file at that\n";
			warn "version or higher was found. Using the local version instead.\n";
			$sqlite_local = 1;
			undef $sqlite_lib;
			undef $sqlite_inc;
		} else {
			print "Looks good\n" if $ENV{AUTOMATED_TESTING};
		}
	}
} else {
	# Always the bundled one.
	# XXX: ... and this message should be more informative.
	$sqlite_local = 1;
	print "We're using the bundled sqlite library.\n" if $ENV{AUTOMATED_TESTING};
}

@ARGV = grep( ! /SQLITE_LOCATION|USE_LOCAL_SQLITE|SQLITE_LIB|SQLITE_INC/, @ARGV );





#####################################################################
# Prepare Compiler Options

my @CC_LIBS = ();
if ( $sqlite_lib ) {
	push @CC_LIBS, "-L$sqlite_lib";
}
unless ( $sqlite_local ) {
	push @CC_LIBS, '-lsqlite3';
}

my @CC_INC = (
	'-I.',
	'-I$(DBI_INSTARCH_DIR)',
);
if ( $sqlite_inc ) {
	push @CC_INC, "-I$sqlite_inc";
}

my @CC_DEFINE = (
	'-DSQLITE_ENABLE_FTS4',             # for sqlite >= 3.7.4
	'-DSQLITE_ENABLE_FTS3_PARENTHESIS', # for sqlite >= 3.6.10
	'-DSQLITE_ENABLE_RTREE',            # for sqlite >= 3.6.10
	'-DSQLITE_ENABLE_COLUMN_METADATA',
#	'-DSQLITE_ENABLE_STAT3',            # for sqlite >= 3.7.9
#	'-DSQLITE_ENABLE_STAT4',            # for sqlite >= 3.8.3.1
	'-DSQLITE_ENABLE_JSON1',            # for sqlite >= 3.9.0
	'-DSQLITE_ENABLE_FTS5',             # for sqlite >= 3.9.0
	'-DSQLITE_ENABLE_MATH_FUNCTIONS',   # for sqlite >= 3.35.0
	'-DNDEBUG=1',
);

# for upstream security concern, this should be set only if requested
if ($ENV{SQLITE_ENABLE_FTS3_TOKENIZER}) {
	push @CC_DEFINE, '-DSQLITE_ENABLE_FTS3_TOKENIZER'; # for sqlite >= 3.11.0
}

if ($ENV{SQLITE_MAX_LENGTH} && $ENV{SQLITE_MAX_LENGTH} =~ m/^[0-9]+$/) {
	push @CC_DEFINE, join '=', '-DSQLITE_MAX_LENGTH', $ENV{SQLITE_MAX_LENGTH}
		if $ENV{SQLITE_MAX_LENGTH} >= 100 && $ENV{SQLITE_MAX_LENGTH} <= ((2**31)-1);
}

if (DEVELOPER_ONLY) {
	# for sqlite >= 3.8.8
	push @CC_DEFINE, '-DSQLITE_ENABLE_API_ARMOR';
}

if ( $^O eq 'cygwin') {
	push @CC_DEFINE, '-DSQLITE_TEMP_STORE=2';
#	push @CC_DEFINE, '-DTHREADSAFE=0'; # requires this for 3.8.7-8
}
if ( $Config{d_usleep} || $Config{osname} =~ m/linux/ ) {
	push @CC_DEFINE, '-DHAVE_USLEEP=1';
}
if ( !$Config{usethreads} and $Config{libs} !~ /pthread/ ) {
	push @CC_DEFINE, '-DTHREADSAFE=0';
}
if ($^O eq 'hpux' and $Config{osvers} <= 10.20) {
	# HP-UX 10.20 does not have pread () at all
	push @CC_DEFINE,
		'-DSQLITE_OMIT_LOAD_EXTENSION',
		'-UUSE_PREAD',
		'-UUSE_PREAD64',
		'-USQLITE_ENABLE_LOCKING_STYLE',
		'-DMAP_FAILED="((void *)-1)"';
}
if ($^O eq 'darwin') {
	my ($osmajor, $osminor) = split /\./, $Config{osvers};
	if ($osmajor < 8 or ($osmajor == 8 && $osminor <= 11)) {
		push @CC_DEFINE, '-DSQLITE_WITHOUT_ZONEMALLOC=1';
	}
	push @CC_DEFINE, '-DSQLITE_ENABLE_LOCKING_STYLE=0';
}
if ($^O eq 'aix') {
	push @CC_DEFINE, '-DSQLITE_DISABLE_DIRSYNC';
}
if ($^O =~ /bsd/i && $^O !~ /(?:open|net)bsd/) {
	push @CC_DEFINE, '-D_XOPEN_SOURCE';
}

if (!$Config{usedl}) {
    push @CC_DEFINE, '-DSQLITE_OMIT_LOAD_EXTENSION';
}

my (@CCFLAGS, @LDFLAGS, @LDDLFLAGS);

if ($ENV{TEST_DBD_SQLITE_WITH_ASAN}) {
    push @CCFLAGS, '-fsanitize=address -static-libasan -fuse-ld=gold -fno-omit-frame-pointer -g -O2';
    push @LDFLAGS, '-fsanitize=address -static-libasan -fuse-ld=gold -fno-omit-frame-pointer -g -O2';
    push @LDDLFLAGS, '-fsanitize=address -static-libasan -fuse-ld=gold -fno-omit-frame-pointer -g -O2';
}

# RT #70135: See if ld supports Bsymbolic; 
unless ($^O eq 'MSWin32' && $Config{ld} =~ /link/) {
	for my $path (File::Spec->path) {
		if (MM->maybe_command("$path/ld")) {
			my $devnull = File::Spec->devnull;
			my $output = `$path/ld --help 2>$devnull`;
			if ($output =~ /Bsymbolic/) {
				push @CCFLAGS, '-Wl,-Bsymbolic';
				push @LDFLAGS, '-Wl,-Bsymbolic';
				push @LDDLFLAGS, '-Wl,-Bsymbolic';
			}
			last;
		}
	}
}

if ($^O eq 'solaris' && $Config{gccversion}) {
	push @CCFLAGS, "-std=gnu99";
}

my %CC_OPTIONS = (
	INC          => join( ' ', @CC_INC    ),
	DEFINE       => join( ' ', @CC_DEFINE ),
);

$CC_OPTIONS{LIBS}      = join ' ', @CC_LIBS if @CC_LIBS;
$CC_OPTIONS{CCFLAGS}   = join ' ', $Config{ccflags}, @CCFLAGS if @CCFLAGS;
$CC_OPTIONS{LDFLAGS}   = join ' ', $Config{ldflags}, @LDFLAGS if @LDFLAGS;
$CC_OPTIONS{LDDLFLAGS} = join ' ', $Config{lddlflags}, @LDDLFLAGS if @LDDLFLAGS;




#####################################################################
# Hand off to ExtUtils::MakeMaker

WriteMakefile(
	NAME             => 'DBD::SQLite',
	ABSTRACT         => 'Self Contained SQLite RDBMS in a DBI Driver',
	VERSION_FROM     => 'lib/DBD/SQLite.pm',
	AUTHOR           => 'Adam Kennedy <adamk@cpan.org>',
	# Release manager (can this be an array?)
	PREREQ_PM        => {
		'Tie::Hash'     => 0,
		'File::Spec'    => (WINLIKE ? '3.27' : '0.82'),
		'DBI'           => $DBI_required,
		'Test::More'    => '0.88', # done_testing
		( WINLIKE ? (
			'Win32' => '0.30',
		) : () ),
	},
	# XXX: VOVKASM suggested to remove this OPTIMIZE line to use
	# the same optimization as perl itself. However, it turned out
	# this change broke a test under some environment, and thus, may
	# break other applications eventually. I'm not sure if this is
	# worth the trouble.
	# OPTIMIZE => $Config{optimize} . ($^O eq 'solaris' && !$Config{gccversion} ? "" : " -O2"),
	OPTIONAL( '6.48',
		MIN_PERL_VERSION => '5.006',
	),
	OPTIONAL( '6.31',
		LICENSE => 'perl',
	),
	OPTIONAL( '6.46',
		# Use META_ADD instead of META_MERGE so that we can remove
		# any build-time dependencies that MakeMaker will put into
		# the requires field.
		META_ADD => {
			dynamic_config => 1,
			configure_requires => {
				'ExtUtils::MakeMaker' => '6.48',
				# This is not allowed to be computed
				'File::Spec'          => '0.82',
				'DBI'                 => $DBI_required,
			},
			build_requires => {
				'File::Spec'          => (WINLIKE ? '3.27' : '0.82'),
				'Test::More'          => '0.88',
			},
			requires => {
				'Tie::Hash' => 0,
				'DBI'       => $DBI_required,
                'Scalar::Util' => 0,
				( WINLIKE ? (
					'Win32' => '0.30',
				) : () ),
			},
			resources => {
				license     => 'http://dev.perl.org/licenses/',
				bugtracker  => 'https://github.com/DBD-SQLite/DBD-SQLite/issues',
				repository  => 'https://github.com/DBD-SQLite/DBD-SQLite',
				MailingList => 'http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/dbd-sqlite',
			},
			no_index => {
				directory => [ qw{
					t inc util
				} ],
			},
		},
	),
	OBJECT           => ( $sqlite_local
		? '$(O_FILES)'
		: 'SQLite.o dbdimp_fts3.o dbdimp_fts5.o'
	),
	depend           => {
        	'dbdimp.o' => 'dbdimp_fts3_tokenizer.inc dbdimp_fts5_tokenizer.inc dbdimp_virtual_table.inc',
	},
	clean            => {
		FILES => 'SQLite.xsi config.h tv.log *.old',
	},
        test             => {
                TESTS => 't/*.t t/*/*.t',
        },
	PL_FILES         => {},
	EXE_FILES        => [],

	%CC_OPTIONS,
);

package MY;

use Config;

sub postamble {
	require DBI;
	require DBI::DBD;
	my $postamble = eval {
		DBI::DBD::dbd_postamble(@_)
	};
    if (-e 'sqlite3.c' && -e 'sqlite3.h' && -e 'sqlite3ext.h') {
		my $S = $^O eq 'MSWin32' ? '\\' : '/';  # only Win32 (not cygwin)
		my $share = "\$(INST_LIB)${S}auto${S}share${S}dist${S}\$(DISTNAME)";
		my $perm_dir = $ExtUtils::MakeMaker::VERSION >= 6.52 ? '$(PERM_DIR)' : '755';
		$postamble .= <<"SHARE";
config ::
\t\$(NOECHO) \$(MKPATH) "$share"
\t\$(NOECHO) \$(CHMOD) $perm_dir "$share"
\t\$(NOECHO) \$(CP) "sqlite3.c" "$share${S}sqlite3.c"
\t\$(NOECHO) \$(CP) "sqlite3.h" "$share${S}sqlite3.h"
\t\$(NOECHO) \$(CP) "sqlite3ext.h" "$share${S}sqlite3ext.h"
SHARE
	}
	return $postamble;
}

sub libscan {
	my ($self, $path) = @_;
	return if $path =~ /\.pl$/;
	($path =~ m/\~$/) ? undef : $path;
}

sub test_via_harness {
	my ($self, $perl, $tests) = @_;
	if ( $^O eq 'hpux' and $Config{osvers} <= 10.20 ) {
		return qq{\tPERL_DL_NONLAZY=0 $perl "-MExtUtils::Command::MM" }
		     . qq{"-e" "test_harness(\$(TEST_VERBOSE), '\$(INST_LIB)', '\$(INST_ARCHLIB)')" $tests\n};
	} else {
		$self->SUPER::test_via_harness($perl, $tests);
	}
}

sub test_via_script {
	my ($self, $perl, $script) = @_;
	if ( $^O eq 'hpux' and $Config{osvers} <= 10.20 ) {
		return qq{\tPERL_DL_NONLAZY=0 $perl "-I\$(INST_LIB)" "-I\$(INST_ARCHLIB)" $script\n};
	} else {
		$self->SUPER::test_via_script($perl, $script);
	}
}
