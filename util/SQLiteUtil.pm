package SQLiteUtil;

use strict;
use warnings;
use FindBin;
use Cwd;
use base 'Exporter';
use HTTP::Tiny;
use File::Copy;

our @EXPORT = qw/
  extract_constants versions srcdir mirror copy_files tweak_pod
  check_api_history
/;

our $ROOT = "$FindBin::Bin/..";
our $SRCDIR = "$ROOT/tmp/src";
our $VERBOSE = $ENV{SQLITE_UTIL_VERBOSE};

my %since = (
  IOERR_LOCK => '3006002',
  OPEN_FULLMUTEX => '3006002',
  STMTSTATUS_FULLSCAN_STEP => '3006004',
  STMTSTATUS_SORT => '3006004',
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
  DBCONFIG_LOOKASIDE => '3007000',
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
  DETERMINISTIC => '3008003',
  IOCAP_IMMUTABLE => '3008005',
  FCNTL_WIN32_SET_HANDLE => '3008005',
  MUTEX_STATIC_APP1 => '3008006',
  MUTEX_STATIC_APP2 => '3008006',
  MUTEX_STATIC_APP3 => '3008006',
  AUTH_USER => '3008007',
  LIMIT_WORKER_THREADS => '3008007',
  CONFIG_PCACHE_HDRSZ => '3008008',
  CONFIG_PMASZ => '3008008',
  IOERR_VNODE => '3009000',
  INDEX_SCAN_UNIQUE => '3009000',
  IOERR_AUTH => '3010000',
  DBCONFIG_ENABLE_FTS3_TOKENIZER => '3012002',
  DBCONFIG_ENABLE_LOAD_EXTENSION => '3013000',
  DBSTATUS_CACHE_USED_SHARED => '3014000',
  DBCONFIG_MAINDBNAME => '3015000',
  DBCONFIG_NO_CKPT_ON_CLOSE => '3016000',
  STMTSTATUS_REPREPARE => '3020000',
  STMTSTATUS_RUN => '3020000',
  STMTSTATUS_MEMUSED => '3020000',
  DBCONFIG_ENABLE_QPSG => '3020000',
  IOERR_BEGIN_ATOMIC => '3021000',
  IOERR_COMMIT_ATOMIC => '3021000',
  IOERR_ROLLBACK_ATOMIC => '3021000',
  ERROR_MISSING_COLLSEQ => '3022000',
  ERROR_RETRY => '3022000',
  READONLY_CANTINIT => '3022000',
  READONLY_DIRECTORY => '3022000',
  DBCONFIG_MAX => '3022000',
  DBCONFIG_TRIGGER_EQP => '3022000',
  DBSTATUS_CACHE_SPILL => '3023000',
  LOCKED_VTAB => '3024000',
  CORRUPT_SEQUENCE => '3024000',
  DBCONFIG_RESET_DATABASE => '3024000',
  ERROR_SNAPSHOT => '3025000',
  CANTOPEN_DIRTYWAL => '3025000',
  CHANGESETSTART_INVERT => '3026000',
  PREPARE_NORMALIZE => '3026000',
  SESSION_CONFIG_STRMSIZE => '3026000',
  DBCONFIG_DEFENSIVE => '3026000',
  DBCONFIG_WRITABLE_SCHEMA => '3028000',
  DBCONFIG_LEGACY_ALTER_TABLE => '3029000',
  DBCONFIG_DQS_DML => '3029000',
  DBCONFIG_DQS_DDL => '3029000',
  DBCONFIG_ENABLE_VIEW => '3030000',
  DIRECTONLY => '3030000',
  SUBTYPE => '3030000',
  DBCONFIG_LEGACY_FILE_FORMAT => '3031000',
  DBCONFIG_TRUSTED_SCHEMA => '3031000',
  CANTOPEN_SYMLINK => '3031000',
  CONSTRAINT_PINNED => '3031000',
  OK_SYMLINK => '3031000',
  OPEN_NOFOLLOW => '3031000',
  INNOCUOUS => '3031000',
  IOERR_DATA => '3032000',
  BUSY_TIMEOUT => '3032000',
  CORRUPT_INDEX => '3032000',
  OPEN_SUPER_JOURNAL => '3033000',
  TXN_NONE => '3034000',
  TXN_READ => '3034000',
  TXN_WRITE => '3034000',
  IOERR_CORRUPTFS => '3034000',
  SESSION_OBJCONFIG_SIZE => '3036000',
  CONSTRAINT_DATATYPE => '3037000',
  OPEN_EXRESCODE => '3037000',
  NOTICE_RBU => '3041000',
  DBCONFIG_STMT_SCANSTATUS => '3042000',
  DBCONFIG_REVERSE_SCANORDER => '3042000',

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
  sql_trace_event_codes => '3014000',
  allowed_return_values_from_sqlite3_txn_state => '3034000',
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
  OK_LOAD_PERMANENTLY PREPARE_PERSISTENT
  SESSION_OBJCONFIG_SIZE
/;

my $ignore_tag_re = join '|', (
  'configuration_options', # for sqlite3_config
  'device_characteristics', # for sqlite3_io_methods
  'standard_file_control_opcodes', # for sqlite3_io_methods/sqlite3_file_control
  'flags_for_sqlite3_deserialize', # for sqlite3_deserialize (SQLITE_ENABLE_DESERIALIZE)
  'flags_for_sqlite3_serialize', # for sqlite3_serialize (SQLITE_ENABLE_DESERIALIZE)
  'sql_trace_event_codes', # for sqlite3_trace_v2
  'prepared_statement_scan_status_opcodes', # for sqlite3_stmt_scanstatus (SQLITE_ENABLE_STMT_SCANSTATUS)
  'checkpoint_mode_values', # for sqlite3_wal_checkpoint_v2
  'virtual_table_configuration_options', # for sqlite3_vtab_config
  'prepare_flags', # for sqlite3_prepare_v3

  'delete_a_session_object',
  'prepared_statement_scan_status',

  # status flags (status methods are read-only at the moment)
  'status_parameters',
  'status_parameters_for_database_connections',
  'status_parameters_for_prepared_statements',

  # internal tags
  'mutex_types',
  'constants_returned_by_the_conflict_handler',
  'constants_passed_to_the_conflict_handler',
  'checkpoint_operation_parameters',
  'conflict_resolution_modes',
  'flags_for_the_xshmlock_vfs_method',
  'maximum_xshmlock_index',
  'win32_directory_types',
  'testing_interface',
  'flags_for_sqlite3changeset_apply_v2',
  'flags_for_sqlite3changeset_start_v2',
  'flags_for_the_xaccess_vfs_method',
  'synchronization_type_flags',
  'file_locking_levels',
  'values_for_sqlite3session_config',
  'virtual_table_scan_flags',
  'text_encodings',
  'virtual_table_constraint_operator_codes',
  'virtual_table_indexing_information',
  'options_for_sqlite3session_object_config',
);

my %compat = map {$_ => 1} qw/
  authorizer_action_codes
  authorizer_return_codes
  flags_for_file_open_operations
/;

my %known_versions;

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
      $tag =~ s/[\[\]]//g;
      ($tag) = $tag =~ /^(\w+)/;
      $tag =~ s/_$//;
      if ($tag =~ /^($ignore_tag_re)/) {
        print "$tag is ignored\n" if $VERBOSE;
        $tag = '';
      }
      next;
    }
    if ($tag && /^#\s*define SQLITE_(\S+)\s+(\d+|\(SQLITE)/) {
      my ($name, $value) = ($1, $2);
      if ($name eq 'VERSION_NUMBER' and $value =~ /^\d+$/) {
          $known_versions{$value} = 1;
      }
      next if $ignore{$name};
      if (my $version = $since{$name} || $since{$tag}) {
        $known_versions{$version} //= 0;
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

my %bad_dist = map {$_ => 1} qw/3061601 3120000 3090300 3120100 3180100/;
sub versions {
  my $res = HTTP::Tiny->new->get("https://sqlite.org/changes.html");
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
    "sqlite-".($version->archive_type)."-$version".$version->extension;
}

sub mirror {
  my $version = shift;
  my $name = "sqlite-$version".$version->extension;
  my $file = "$SRCDIR/$name";
  unless (-f $file) {
    my $url = download_url($version);
    print "Downloading $version from $url...\n";
    my $res = HTTP::Tiny->new->mirror($url => $file);
    if (!$res->{success}) {
        warn "Can't mirror $url: ".$res->{reason};
        return;
    }
    my $content_type = $res->{headers}{'content-type'};
    if ($content_type !~ /x\-gzip/) {
        unlink $file;
        die "Not a gzipped tarball: ".$content_type;
    }
  }
  my $dir = srcdir($version);
  unless ($dir && -d $dir) {
    my $cwd = Cwd::cwd;
    chdir($SRCDIR);
    if ($version->is_snapshot) {
      system("unzip -d sqlite-$version -o $name");
    } else {
      system("tar xf $name");
    }
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

sub tweak_pod {
  my $version = shift;
  my $dotted = $version->dotted;
  my $pmfile = "$ROOT/lib/DBD/SQLite.pm";
  my $body = do { open my $fh, '<', $pmfile or die $!; local $/; <$fh> };
  $body =~ s/S<[\d\.]+>/S<$dotted>/g or die "Can't find a placeholder for SQLite version";
  open my $out, '>', "$pmfile.tmp" or die $!;
  print $out $body;
  close $out;
  rename "$pmfile.tmp" => $pmfile or die "Can't rename $pmfile.tmp to $pmfile: $!";
}

sub check_api_history {
  require Array::Diff;
  my %current;
  for my $version (versions()) {
    print "checking $version...\n" if $VERBOSE;
    my $dir = srcdir($version);
    unless ($dir && -d $dir) {
      $dir = mirror($version) or next;
    }
    my %constants = extract_constants("$dir/sqlite3.h");
    if (%current) {
      for my $key (sort keys %current) {
        print "$version: deleted $key\n" if !exists $constants{$key};
      }
      for my $key (sort keys %constants) {
        next if $key =~ /^_/; # compat
        if (!exists $current{$key}) {
          if (my $has_unknown_changes = grep {!$since{$_}} @{$constants{$key} // []}) {
            print "$version: added $key\n";
            for (sort @{$constants{$key}}) {
              print "  $_\n";
            }
          }
          next;
        }
        my $diff = Array::Diff->diff($current{$key}, $constants{$key});
        print "$version: added $_ ($key)\n" for @{$diff->added || []};
        print "$version: deleted $_ ($key)\n" for @{$diff->deleted || []};
      }
    }
    %current = %constants;
  }
  if (my @wrong_versions = grep {!$known_versions{$_}} keys %known_versions) {
    warn "WRONG VERSIONS: ".join(",", sort @wrong_versions);
  }
}

package SQLiteUtil::Version;

use overload '""' => sub {
  my $self = shift;
  $self->as_num < 3070400 ? $self->dotted : $self->as_num;
};

sub new {
  my ($class, $version) = @_;
  my @parts;
  if ($version =~ m/^3(?:\.[0-9]+){1,3}$/) {
    @parts = split /\./, $version;
  }
  elsif ($version =~ m/^3(?:[0-9]{2}){2,3}$/) {
    @parts = $version =~ /^(3)([0-9]{2})([0-9]{2})([0-9]{2})?$/;
  }
  elsif ($version =~ m/^(20\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/) {
    @parts = ($1, $2, $3, $4, $5);
  }
  else {
    die "improper <version> format for [$version]\n";
  }
  bless \@parts, $class;
}

sub as_num {
  my $self = shift;
  return sprintf '%04u%02u%02u%02u%02u', map {$_ || 0} @$self[0..4] if $self->is_snapshot;
  sprintf '%u%02u%02u%02u', map {$_ || 0} @$self[0..3];
}

sub dotted {
  my $self = shift;
  join '.', map {$_ + 0} ($self->[3] && $self->[3] + 0) ? @$self : @$self[0..2];
}

sub year {
  my $self = shift;
  return "snapshot" if $self->is_snapshot;
  my $version = $self->as_num;
  return 2024 if $version >= 3450000;
  return 2023 if $version >= 3410000;
  return 2022 if $version >= 3370200;
  return 2021 if $version >= 3340100;
  return 2020 if $version >= 3310000;
  return 2019 if $version >= 3270000;
  return 2018 if $version >= 3220000;
  return 2017 if $version >= 3160000;
  return 2016 if $version >= 3100000;
  return 2015 if $version >= 3080800;
  return 2014 if $version >= 3080300;
  return 2013 if $version >= 3071600;
  return;
}

sub archive_type {
  my $self = shift;
  return "amalgamation" if $self->is_snapshot;
  $self->as_num >= 3070400 ? "autoconf" : "amalgamation";
}

sub is_snapshot {
  shift->[0] =~ /^20\d\d/;
}

sub extension {
  my $self = shift;
  return ".zip" if $self->is_snapshot;
  return ".tar.gz";
}

1;
