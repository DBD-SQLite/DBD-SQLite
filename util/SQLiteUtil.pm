package SQLiteUtil;

use strict;
use warnings;
use base 'Exporter';
use HTTP::Tiny;
use File::Copy;

our @EXPORT = qw/
  extract_constants versions srcdir mirror copy_files
/;

our $ROOT = "$FindBin::Bin/..";
our $SRCDIR = "$ROOT/tmp/src";

my %since = (
  IOERR_LOCK => '3006002',
  CONFIG_PCACHE => '3006006',
  CONFIG_GETPCACHE => '3006006',
  IOERR_CLOSE => '3006007',
  IOERR_DIR_CLOSE => '3006007',
  GET_LOCKPROXYFILE => '3006007',
  SET_LOCKPROXYFILE => '3006007',
  LAST_ERRNO => '3006007',
  SAVEPOINT => '3006008',
  LOCKED_SHAREDCACHE => '3006012',
  MUTEX_STATIC_OPEN => '3006012',
  OPEN_SHAREDCACHE => '3006018',
  OPEN_PRIVATECACHE => '3006018',
  LIMIT_TRIGGER_DEPTH => '3006018',
  CONFIG_LOG => '3006023',
  OPEN_AUTOPROXY => '3006023',
  IOCAP_UNDELETABLE_WHEN_OPEN => '3007000',
  IOERR_SHMOPEN => '3007000',
  IOERR_SHMSIZE => '3007000',
  IOERR_SHMLOCK => '3007000',
  BUSY_RECOVERY => '3007000',
  CANTOPEN_NOTEMPDIR => '3007000',
  OPEN_WAL => '3007000',
  FCNTL_SIZE_HINT => '3007000',
  DBSTATUS_CACHE_USED => '3007000',
  DBSTATUS_MAX => '3007000',
  STMTSTATUS_AUTOINDEX => '3007000',
  FCNTL_CHUNK_SIZE => '3007001',
  STATUS_MALLOC_COUNT => '3007001',
  DBSTATUS_SCHEMA_USED => '3007001',
  DBSTATUS_STMT_USED => '3007001',
  FCNTL_FILE_POINTER => '3007004',
  MUTEX_STATIC_PMEM => '3007005',
  FCNTL_SYNC_OMITTED => '3007005',
  DBSTATUS_LOOKASIDE_HIT => '3007005',
  DBSTATUS_LOOKASIDE_MISS_SIZE => '3007005',
  DBSTATUS_LOOKASIDE_MISS_FULL => '3007005',
  DBCONFIG_ENABLE_FKEY => '3007006',
  DBCONFIG_ENABLE_TRIGGER => '3007006',
  CONFIG_URI => '3007007',
  IOERR_SHMMAP => '3007007',
  IOERR_SEEK => '3007007',
  CORRUPT_VTAB => '3007007',
  READONLY_RECOVERY => '3007007',
  READONLY_CANTLOCK => '3007007',
  OPEN_URI => '3007007',
  FCNTL_WIN32_AV_RETRY => '3007008',
  FCNTL_PERSIST_WAL => '3007008',
  FCNTL_OVERWRITE => '3007009',
  DBSTATUS_CACHE_HIT => '3007009',
  DBSTATUS_CACHE_MISS => '3007009',
  CONFIG_PCACHE2 => '3007010',
  CONFIG_GETPCACHE2 => '3007010',
  IOCAP_POWERSAFE_OVERWRITE => '3007010',
  FCNTL_VFSNAME => '3007010',
  FCNTL_POWERSAFE_OVERWRITE => '3007010',
  ABORT_ROLLBACK => '3007011',
  FCNTL_PRAGMA => '3007011',
  CANTOPEN_ISDIR => '3007012',
  DBSTATUS_CACHE_WRITE => '3007012',
  OPEN_MEMORY => '3007013',
  CONFIG_COVERING_INDEX_SCAN => '3007015',
  CONFIG_SQLLOG => '3007015',
  IOERR_DELETE_NOENT => '3007015',
  CANTOPEN_FULLPATH => '3007015',
  FCNTL_BUSYHANDLER => '3007015',
  FCNTL_TEMPFILENAME => '3007015',
  READONLY_ROLLBACK => '3007016',
  CONSTRAINT_CHECK => '3007016',
  CONSTRAINT_COMMITHOOK => '3007016',
  CONSTRAINT_FOREIGNKEY => '3007016',
  CONSTRAINT_FUNCTION => '3007016',
  CONSTRAINT_NOTNULL => '3007016',
  CONSTRAINT_PRIMARYKEY => '3007016',
  CONSTRAINT_TRIGGER => '3007016',
  CONSTRAINT_UNIQUE => '3007016',
  CONSTRAINT_VTAB => '3007016',
  CONFIG_MMAP_SIZE => '3007017',
  IOERR_MMAP => '3007017',
  NOTICE_RECOVER_WAL => '3007017',
  NOTICE_RECOVER_ROLLBACK => '3007017',
  NOTICE => '3007017',
  WARNING => '3007017',
  FCNTL_MMAP_SIZE => '3007017',
  IOERR_GETTEMPPATH => '3008000',
  BUSY_SNAPSHOT => '3008000',
  WARNING_AUTOINDEX => '3008000',
  DBSTATUS_DEFERRED_FKS => '3008000',
  STMTSTATUS_VM_STEP => '3008000',
  IOERR_CONVPATH => '3008001',
  CANTOPEN_CONVPATH => '3008001',
  CONFIG_WIN32_HEAPSIZE => '3008002',
  CONSTRAINT_ROWID => '3008002',
  FCNTL_TRACE => '3008002',
  RECURSIVE => '3008003',
  READONLY_DBMOVED => '3008003',
  FCNTL_HAS_MOVED => '3008003',
  FCNTL_SYNC => '3008003',
  FCNTL_COMMIT_PHASETWO => '3008003',
  IOCAP_IMMUTABLE => '3008005',
  FCNTL_WIN32_SET_HANDLE => '3008005',
  MUTEX_STATIC_APP1 => '3008006',
  MUTEX_STATIC_APP2 => '3008006',
  MUTEX_STATIC_APP3 => '3008006',
  AUTH_USER => '3008007',
  LIMIT_WORKER_THREADS => '3008007',
  CONFIG_PCACHE_HDRSZ => '3008008',
  CONFIG_PMASZ => '3008008',

  status_parameters_for_prepared_statements => '3006004',
  extended_result_codes => '3006005',
  database_connection_configuration_options => '3007000',
  flags_for_the_xshmlock_vfs_method => '3007000',
  maximum_xshmlock_index => '3007000',
  virtual_table_constraint_operator_codes => '3007001',
  checkpoint_operation_parameters => '3007006',
  conflict_resolution_modes => '3007007',
  virtual_table_configuration_options => '3007007',
  function_flags => '3008003',
  checkpoint_mode_values => '3008008',
  prepared_statement_scan_status_opcodes => '3008008',
);

my %until = (
  CONFIG_CHUNKALLOC => '3006004',
  DBCONFIG_LOOKASIDE => '3006023',
  virtual_table_indexing_information => '3007000',
  checkpoint_operation_parameters => '3008007',
);

my %ignore = map {$_ => 1} qw/
  OPEN_DELETEONCLOSE OPEN_EXCLUSIVE OPEN_AUTOPROXY
  OPEN_MAIN_DB OPEN_TEMP_DB OPEN_TRANSIENT_DB
  OPEN_MAIN_JOURNAL OPEN_TEMP_JOURNAL
  OPEN_SUBJOURNAL OPEN_MASTER_JOURNAL OPEN_WAL
/;

my %compat = map {$_ => 1} qw/
  authorizer_action_codes
  authorizer_return_codes
  flags_for_file_open_operations
/;


sub extract_constants {
  my $file = shift;
  $file ||= "$FindBin::Bin/../sqlite3.h";
  open my $fh, '<', $file or die "$file: $!";
  my $tag;
  my %constants;
  while(<$fh>) {
    if (/^\*\* CAPI3REF: (.+)/) {
      $tag = lc $1;
      $tag =~ s/[ \-]+/_/g;
      ($tag) = $tag =~ /^(\w+)/;
      $tag =~ s/_$//;
      if ($tag =~ /
        testing_interface |
        library_version_numbers |
        configuration_options | device_characteristics |
        file_locking | vfs_method | xshmlock_index |
        mutex_types | scan_status | run_time_limit |
        standard_file_control | status_parameters |
        synchronization_type | virtual_table_constraint |
        virtual_table_indexing_information |
        checkpoint_operation_parameters | checkpoint_mode | 
        conflict_resolution | text_encodings
      /x) {
        print "$tag is ignored\n";
        $tag = '';
      }
      next;
    }
    if ($tag && /^#define SQLITE_(\S+)\s+(?:\d|\(SQLITE)/) {
      my $name = $1;
      next if $ignore{$name};
      if (my $version = $since{$name} || $since{$tag}) {
        push @{$constants{"${tag}_${version}"} ||= []}, $name;
        push @{$constants{"_${tag}_${version}"} ||= []}, $name if $compat{$tag};
      } else {
        push @{$constants{$tag} ||= []}, $name;
        push @{$constants{"_$tag"} ||= []}, $name if $compat{$tag};
      }
    }
  }
  unshift @{$constants{_authorizer_return_codes}}, 'OK';

  %constants;
}

my %bad_dist = map {$_ => 1} qw/3061601/;
sub versions {
  my $res = HTTP::Tiny->new->get("http://sqlite.org/changes.html");
  reverse grep {$_->as_num >= 3060100 && !$bad_dist{$_->as_num}} map {s/_/./g; SQLiteUtil::Version->new($_)} $res->{content} =~ /name="version_(3_[\d_]+)"/g;
}

sub srcdir {
  my $version = SQLiteUtil::Version->new(shift);
  my ($dir) = grep {-d $_} (
    "$SRCDIR/sqlite-$version",
    "$SRCDIR/sqlite-autoconf-$version",
    "$SRCDIR/sqlite-amalgamation-$version",
  );
  $dir;
}

sub download_url {
  my $version = shift;
  my $year = $version->year;
  join '', 
    "http://www.sqlite.org/",
    ($version->year ? $version->year."/" : ""),
    "sqlite-".($version->archive_type)."-$version.tar.gz";
}

sub mirror {
  my $version = shift;
  my $file = "$SRCDIR/sqlite-$version.tar.gz";
  unless (-f $file) {
    my $url = download_url($version);
    print "Downloading $version...\n";
    my $res = HTTP::Tiny->new->mirror($url => $file);
    die "Can't mirror $file: ".$res->{reason} unless $res->{success};
  }
  my $dir = srcdir($version);
  unless ($dir && -d $dir) {
    my $cwd = Cwd::cwd;
    chdir($SRCDIR);
    system("tar xf sqlite-$version.tar.gz");
    chdir($cwd);
    $dir = srcdir($version) or die "Can't find srcdir";
  }
  open my $fh, '<', "$dir/sqlite3.c" or die $!;
  open my $out, '>', "$dir/fts3_tokenizer.h" or die $!;
  while(<$fh>) {
    print $out $_ if m{\*+ Begin file fts3_tokenizer\.h}
                  ...m{^/\*+ End of fts3_tokenizer\.h};
  }
  $dir;
}

sub copy_files {
  my $version = shift;
  my $dir = srcdir($version) or return;
  copy("$dir/sqlite3.c", $ROOT);
  copy("$dir/sqlite3.h", $ROOT);
  copy("$dir/sqlite3ext.h", $ROOT);
  copy("$dir/fts3_tokenizer.h", $ROOT);
}

package SQLiteUtil::Version;

use overload '""' => sub {
  my $self = shift;
  $self->as_num < 3070400 ? $self->dotted : $self->as_num;
};

sub new {
  my ($class, $version) = @_;
  my @parts;
  if ($version =~ m/^3(?:\.[0-9]+){2,3}$/) {
    @parts = split /\./, $version;
  }
  elsif ($version =~ m/^3(?:[0-9]{2}){2,3}$/) {
    @parts = $version =~ /^(3)([0-9]{2})([0-9]{2})([0-9]{2})?$/;
  }
  else {
    die "improper <version> format for [$version]\n";
  }
  bless \@parts, $class;
}

sub as_num {
  my $self = shift;
  sprintf '%u%02u%02u%02u', map {$_ || 0} @$self[0..3];
}

sub dotted {
  my $self = shift;
  join '.', $self->[3] ? @$self : @$self[0..2];
}

sub year {
  my $self = shift;
  my $version = $self->as_num;
  return 2015 if $version >= 3080800;
  return 2014 if $version >= 3080300;
  return 2013 if $version >= 3071600;
  return;
}

sub archive_type {
  shift->as_num > 3070400 ? "autoconf" : "amalgamation";
}

1;
