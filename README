NAME
  DBD::SQLite - Self-contained RDBMS in a DBI Driver

SYNOPSIS
    use DBI;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");

DESCRIPTION
  SQLite is a public domain file-based relational database engine
  that you can find at <http://www.sqlite.org/>.

  DBD::SQLite is a Perl DBI driver for SQLite, that includes the
  entire thing in the distribution. So in order to get a fast
  transaction capable RDBMS working for your perl project you simply
  have to install this module, and nothing else.

  SQLite supports the following features:

  Implements a large subset of SQL92
      See <http://www.sqlite.org/lang.html> for details.

  A complete DB in a single disk file
      Everything for your database is stored in a single disk file,
      making it easier to move things around than with DBD::CSV.

  Atomic commit and rollback
      Yes, DBD::SQLite is small and light, but it supports full
      transactions!

  Extensible
      User-defined aggregate or regular functions can be registered
      with the SQL parser.

  There's lots more to it, so please refer to the docs on the SQLite
  web page, listed above, for SQL details. Also refer to DBI for
  details on how to use DBI itself. The API works like every DBI
  module does. However, currently many statement attributes are not
  implemented or are limited by the typeless nature of the SQLite
  database.

SQLITE VERSION
  DBD::SQLite is usually compiled with a bundled SQLite library
  (SQLite version 3.25.3 as of this release) for consistency.
  However, a different version of SQLite may sometimes be used for
  some reasons like security, or some new experimental features.

  You can look at $DBD::SQLite::sqlite_version ("3.x.y" format) or
  $DBD::SQLite::sqlite_version_number ("3xxxyyy" format) to find
  which version of SQLite is actually used. You can also check
  "DBD::SQLite::Constants::SQLITE_VERSION_NUMBER()".

  You can also find how the library is compiled by calling
  "DBD::SQLite::compile_options()" (see below).

NOTABLE DIFFERENCES FROM OTHER DRIVERS
 Database Name Is A File Name
  SQLite creates a file per a database. You should pass the "path"
  of the database file (with or without a parent directory) in the
  DBI connection string (as a database "name"):

    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");

  The file is opened in read/write mode, and will be created if it
  does not exist yet.

  Although the database is stored in a single file, the directory
  containing the database file must be writable by SQLite because
  the library will create several temporary files there.

  If the filename $dbfile is ":memory:", then a private, temporary
  in-memory database is created for the connection. This in-memory
  database will vanish when the database connection is closed. It is
  handy for your library tests.

  Note that future versions of SQLite might make use of additional
  special filenames that begin with the ":" character. It is
  recommended that when a database filename actually does begin with
  a ":" character you should prefix the filename with a pathname
  such as "./" to avoid ambiguity.

  If the filename $dbfile is an empty string, then a private,
  temporary on-disk database will be created. This private database
  will be automatically deleted as soon as the database connection
  is closed.

  As of 1.41_01, you can pass URI filename (see
  <http://www.sqlite.org/uri.html>) as well for finer control:

    my $dbh = DBI->connect("dbi:SQLite:uri=file:$path_to_dbfile?mode=rwc");

  Note that this is not for remote SQLite database connection. You
  can only connect to a local database.

 Read-Only Database
  You can set sqlite_open_flags (only) when you connect to a
  database:

    use DBD::SQLite::Constants qw/:file_open/;
    my $dbh = DBI->connect("dbi:SQLite:$dbfile", undef, undef, {
      sqlite_open_flags => SQLITE_OPEN_READONLY,
    });

  See <http://www.sqlite.org/c3ref/open.html> for details.

  As of 1.49_05, you can also make a database read-only by setting
  "ReadOnly" attribute to true (only) when you connect to a
  database. Actually you can set it after you connect, but in that
  case, it can't make the database read-only, and you'll see a
  warning (which you can hide by turning "PrintWarn" off).

 DBD::SQLite And File::Temp
  When you use File::Temp to create a temporary file/directory for
  SQLite databases, you need to remember:

  tempfile may be locked exclusively
      You may want to use "tempfile()" to create a temporary
      database filename for DBD::SQLite, but as noted in
      File::Temp's POD, this file may have an exclusive lock under
      some operating systems (notably Mac OSX), and result in a
      "database is locked" error. To avoid this, set EXLOCK option
      to false when you call tempfile().

        ($fh, $filename) = tempfile($template, EXLOCK => 0);

  CLEANUP may not work unless a database is disconnected
      When you set CLEANUP option to true when you create a
      temporary directory with "tempdir()" or "newdir()", you may
      have to disconnect databases explicitly before the temporary
      directory is gone (notably under MS Windows).

  (The above is quoted from the pod of File::Temp.)

  If you don't need to keep or share a temporary database, use
  ":memory:" database instead. It's much handier and cleaner for
  ordinary testing.

 DBD::SQLite and fork()
  Follow the advice in the SQLite FAQ
  (<https://sqlite.org/faq.html>).

      Under Unix, you should not carry an open SQLite database
      across a fork() system call into the child process. Problems
      will result if you do.

  You shouldn't (re)use a database handle you created (probably to
  set up a database schema etc) before you fork(). Otherwise, you
  might see a database corruption in the worst case.

  If you need to fork(), (re)open a database after you fork(). You
  might also want to tweak "sqlite_busy_timeout" and
  "sqlite_use_immediate_transaction" (see below), depending on your
  needs.

  If you need a higher level of concurrency than SQLite supports,
  consider using other client/server database engines.

 Accessing A Database With Other Tools
  To access the database from the command line, try using "dbish"
  which comes with the DBI::Shell module. Just type:

    dbish dbi:SQLite:foo.db

  On the command line to access the file foo.db.

  Alternatively you can install SQLite from the link above without
  conflicting with DBD::SQLite and use the supplied "sqlite3"
  command line tool.

 Blobs
  As of version 1.11, blobs should "just work" in SQLite as text
  columns. However this will cause the data to be treated as a
  string, so SQL statements such as length(x) will return the length
  of the column as a NUL terminated string, rather than the size of
  the blob in bytes. In order to store natively as a BLOB use the
  following code:

    use DBI qw(:sql_types);
    my $dbh = DBI->connect("dbi:SQLite:dbfile","","");
  
    my $blob = `cat foo.jpg`;
    my $sth = $dbh->prepare("INSERT INTO mytable VALUES (1, ?)");
    $sth->bind_param(1, $blob, SQL_BLOB);
    $sth->execute();

  And then retrieval just works:

    $sth = $dbh->prepare("SELECT * FROM mytable WHERE id = 1");
    $sth->execute();
    my $row = $sth->fetch;
    my $blobo = $row->[1];
  
    # now $blobo == $blob

 Functions And Bind Parameters
  As of this writing, a SQL that compares a return value of a
  function with a numeric bind value like this doesn't work as you
  might expect.

    my $sth = $dbh->prepare(q{
      SELECT bar FROM foo GROUP BY bar HAVING count(*) > ?;
    });
    $sth->execute(5);

  This is because DBD::SQLite assumes that all the bind values are
  text (and should be quoted) by default. Thus the above statement
  becomes like this while executing:

    SELECT bar FROM foo GROUP BY bar HAVING count(*) > "5";

  There are three workarounds for this.

  Use bind_param() explicitly
      As shown above in the "BLOB" section, you can always use
      "bind_param()" to tell the type of a bind value.

        use DBI qw(:sql_types);  # Don't forget this
  
        my $sth = $dbh->prepare(q{
          SELECT bar FROM foo GROUP BY bar HAVING count(*) > ?;
        });
        $sth->bind_param(1, 5, SQL_INTEGER);
        $sth->execute();

  Add zero to make it a number
      This is somewhat weird, but works anyway.

        my $sth = $dbh->prepare(q{
          SELECT bar FROM foo GROUP BY bar HAVING count(*) > (? + 0);
        });
        $sth->execute(5);

  Use SQL cast() function
      This is more explicit way to do the above.

        my $sth = $dbh->prepare(q{
          SELECT bar FROM foo GROUP BY bar HAVING count(*) > cast(? as integer);
        });
        $sth->execute(5);

  Set "sqlite_see_if_its_a_number" database handle attribute
      As of version 1.32_02, you can use
      "sqlite_see_if_its_a_number" to let DBD::SQLite to see if the
      bind values are numbers or not.

        $dbh->{sqlite_see_if_its_a_number} = 1;
        my $sth = $dbh->prepare(q{
          SELECT bar FROM foo GROUP BY bar HAVING count(*) > ?;
        });
        $sth->execute(5);

      You can set it to true when you connect to a database.

        my $dbh = DBI->connect('dbi:SQLite:foo', undef, undef, {
          AutoCommit => 1,
          RaiseError => 1,
          sqlite_see_if_its_a_number => 1,
        });

      This is the most straightforward solution, but as noted above,
      existing data in your databases created by DBD::SQLite have
      not always been stored as numbers, so this *might* cause other
      obscure problems. Use this sparingly when you handle existing
      databases. If you handle databases created by other tools like
      native "sqlite3" command line tool, this attribute would help
      you.

      As of 1.41_04, "sqlite_see_if_its_a_number" works only for
      bind values with no explicit type.

        my $dbh = DBI->connect('dbi:SQLite:foo', undef, undef, {
          AutoCommit => 1,
          RaiseError => 1,
          sqlite_see_if_its_a_number => 1,
        });
        my $sth = $dbh->prepare('INSERT INTO foo VALUES(?)');
        # '1.230' will be inserted as a text, instead of 1.23 as a number,
        # even though sqlite_see_if_its_a_number is set.
        $sth->bind_param(1, '1.230', SQL_VARCHAR);
        $sth->execute;

 Placeholders
  SQLite supports several placeholder expressions, including "?" and
  ":AAAA". Consult the DBI and SQLite documentation for details.

  <http://www.sqlite.org/lang_expr.html#varparam>

  Note that a question mark actually means a next unused (numbered)
  placeholder. You're advised not to use it with other (numbered or
  named) placeholders to avoid confusion.

    my $sth = $dbh->prepare(
      'update TABLE set a=?1 where b=?2 and a IS NOT ?1'
    );
    $sth->execute(1, 2);

 Pragma
  SQLite has a set of "Pragma"s to modify its operation or to query
  for its internal data. These are specific to SQLite and are not
  likely to work with other DBD libraries, but you may find some of
  these are quite useful, including:

  journal_mode
      You can use this pragma to change the journal mode for SQLite
      databases, maybe for better performance, or for compatibility.

      Its default mode is "DELETE", which means SQLite uses a
      rollback journal to implement transactions, and the journal is
      deleted at the conclusion of each transaction. If you use
      "TRUNCATE" instead of "DELETE", the journal will be truncated,
      which is usually much faster.

      A "WAL" (write-ahead log) mode is introduced as of SQLite
      3.7.0. This mode is persistent, and it stays in effect even
      after closing and reopening the database. In other words, once
      the "WAL" mode is set in an application or in a test script,
      the database becomes inaccessible by older clients. This tends
      to be an issue when you use a system "sqlite3" executable
      under a conservative operating system.

      To fix this, You need to issue "PRAGMA journal_mode = DELETE"
      (or "TRUNCATE") beforehand, or install a newer version of
      "sqlite3".

  legacy_file_format
      If you happen to need to create a SQLite database that will
      also be accessed by a very old SQLite client (prior to 3.3.0
      released in Jan. 2006), you need to set this pragma to ON
      before you create a database.

  reverse_unordered_selects
      You can set this pragma to ON to reverse the order of results
      of SELECT statements without an ORDER BY clause so that you
      can see if applications are making invalid assumptions about
      the result order.

      Note that SQLite 3.7.15 (bundled with DBD::SQLite 1.38_02)
      enhanced its query optimizer and the order of results of a
      SELECT statement without an ORDER BY clause may be different
      from the one of the previous versions.

  synchronous
      You can set set this pragma to OFF to make some of the
      operations in SQLite faster with a possible risk of database
      corruption in the worst case. See also "Performance" section
      below.

  See <http://www.sqlite.org/pragma.html> for more details.

 Foreign Keys
  SQLite has started supporting foreign key constraints since 3.6.19
  (released on Oct 14, 2009; bundled in DBD::SQLite 1.26_05). To be
  exact, SQLite has long been able to parse a schema with foreign
  keys, but the constraints has not been enforced. Now you can issue
  a "foreign_keys" pragma to enable this feature and enforce the
  constraints, preferably as soon as you connect to a database and
  you're not in a transaction:

    $dbh->do("PRAGMA foreign_keys = ON");

  And you can explicitly disable the feature whenever you like by
  turning the pragma off:

    $dbh->do("PRAGMA foreign_keys = OFF");

  As of this writing, this feature is disabled by default by the
  SQLite team, and by us, to secure backward compatibility, as this
  feature may break your applications, and actually broke some for
  us. If you have used a schema with foreign key constraints but
  haven't cared them much and supposed they're always ignored for
  SQLite, be prepared, and please do extensive testing to ensure
  that your applications will continue to work when the foreign keys
  support is enabled by default.

  See <http://www.sqlite.org/foreignkeys.html> for details.

 Transactions
  DBI/DBD::SQLite's transactions may be a bit confusing. They behave
  differently according to the status of the "AutoCommit" flag:

  When the AutoCommit flag is on
      You're supposed to always use the auto-commit mode, except you
      explicitly begin a transaction, and when the transaction
      ended, you're supposed to go back to the auto-commit mode. To
      begin a transaction, call "begin_work" method, or issue a
      "BEGIN" statement. To end it, call "commit/rollback" methods,
      or issue the corresponding statements.

        $dbh->{AutoCommit} = 1;
  
        $dbh->begin_work; # or $dbh->do('BEGIN TRANSACTION');
  
        # $dbh->{AutoCommit} is turned off temporarily during a transaction;
  
        $dbh->commit; # or $dbh->do('COMMIT');
  
        # $dbh->{AutoCommit} is turned on again;

  When the AutoCommit flag is off
      You're supposed to always use the transactional mode, until
      you explicitly turn on the AutoCommit flag. You can explicitly
      issue a "BEGIN" statement (only when an actual transaction has
      not begun yet) but you're not allowed to call "begin_work"
      method (if you don't issue a "BEGIN", it will be issued
      internally). You can commit or roll it back freely. Another
      transaction will automatically begin if you execute another
      statement.

        $dbh->{AutoCommit} = 0;
  
        # $dbh->do('BEGIN TRANSACTION') is not necessary, but possible
  
        ...
  
        $dbh->commit; # or $dbh->do('COMMIT');
  
        # $dbh->{AutoCommit} stays intact;
  
        $dbh->{AutoCommit} = 1;  # ends the transactional mode

  This "AutoCommit" mode is independent from the autocommit mode of
  the internal SQLite library, which always begins by a "BEGIN"
  statement, and ends by a "COMMIT" or a <ROLLBACK>.

 Transaction and Database Locking
  The default transaction behavior of SQLite is "deferred", that
  means, locks are not acquired until the first read or write
  operation, and thus it is possible that another thread or process
  could create a separate transaction and write to the database
  after the "BEGIN" on the current thread has executed, and
  eventually cause a "deadlock". To avoid this, DBD::SQLite
  internally issues a "BEGIN IMMEDIATE" if you begin a transaction
  by calling "begin_work" or by turning off "AutoCommit" (since
  1.38_01).

  If you really need to turn off this feature for some reasons, set
  "sqlite_use_immediate_transaction" database handle attribute to
  false, and the default "deferred" transaction will be used.

    my $dbh = DBI->connect("dbi:SQLite::memory:", "", "", {
      sqlite_use_immediate_transaction => 0,
    });

  Or, issue a "BEGIN" statement explicitly each time you begin a
  transaction.

  See <http://sqlite.org/lockingv3.html> for locking details.

 "$sth->finish" and Transaction Rollback
  As the DBI doc says, you almost certainly do not need to call
  "finish" in DBI method if you fetch all rows (probably in a loop).
  However, there are several exceptions to this rule, and
  rolling-back of an unfinished "SELECT" statement is one of such
  exceptional cases.

  SQLite prohibits "ROLLBACK" of unfinished "SELECT" statements in a
  transaction (See <http://sqlite.org/lang_transaction.html> for
  details). So you need to call "finish" before you issue a
  rollback.

    $sth = $dbh->prepare("SELECT * FROM t");
    $dbh->begin_work;
    eval {
        $sth->execute;
        $row = $sth->fetch;
        ...
        die "For some reason";
        ...
    };
    if($@) {
       $sth->finish;  # You need this for SQLite
       $dbh->rollback;
    } else {
       $dbh->commit;
    }

 Processing Multiple Statements At A Time
  DBI's statement handle is not supposed to process multiple
  statements at a time. So if you pass a string that contains
  multiple statements (a "dump") to a statement handle (via
  "prepare" or "do"), DBD::SQLite only processes the first
  statement, and discards the rest.

  If you need to process multiple statements at a time, set a
  "sqlite_allow_multiple_statements" attribute of a database handle
  to true when you connect to a database, and "do" method takes care
  of the rest (since 1.30_01, and without creating DBI's statement
  handles internally since 1.47_01). If you do need to use "prepare"
  or "prepare_cached" (which I don't recommend in this case, because
  typically there's no placeholder nor reusable part in a dump), you
  can look at << $sth->{sqlite_unprepared_statements} >> to retrieve
  what's left, though it usually contains nothing but white spaces.

 TYPE statement attribute
  Because of historical reasons, DBD::SQLite's "TYPE" statement
  handle attribute returns an array ref of string values, contrary
  to the DBI specification. This value is also less useful for
  SQLite users because SQLite uses dynamic type system (that means,
  the datatype of a value is associated with the value itself, not
  with its container).

 Performance
  SQLite is fast, very fast. Matt processed his 72MB log file with
  it, inserting the data (400,000+ rows) by using transactions and
  only committing every 1000 rows (otherwise the insertion is quite
  slow), and then performing queries on the data.

  Queries like count(*) and avg(bytes) took fractions of a second to
  return, but what surprised him most of all was:

    SELECT url, count(*) as count
    FROM access_log
    GROUP BY url
    ORDER BY count desc
    LIMIT 20

  To discover the top 20 hit URLs on the site (<http://axkit.org>),
  and it returned within 2 seconds. He was seriously considering
  switching his log analysis code to use this little speed demon!

  Oh yeah, and that was with no indexes on the table, on a 400MHz
  PIII.

  For best performance be sure to tune your hdparm settings if you
  are using linux. Also you might want to set:

    PRAGMA synchronous = OFF

  Which will prevent SQLite from doing fsync's when writing (which
  slows down non-transactional writes significantly) at the expense
  of some peace of mind. Also try playing with the cache_size
  pragma.

  The memory usage of SQLite can also be tuned using the cache_size
  pragma.

    $dbh->do("PRAGMA cache_size = 800000");

  The above will allocate 800M for DB cache; the default is 2M. Your
  sweet spot probably lies somewhere in between.

DRIVER PRIVATE ATTRIBUTES
 Database Handle Attributes
  sqlite_version
      Returns the version of the SQLite library which DBD::SQLite is
      using, e.g., "2.8.0". Can only be read.

  sqlite_unicode
      If set to a true value, DBD::SQLite will turn the UTF-8 flag
      on for all text strings coming out of the database (this
      feature is currently disabled for perl < 5.8.5). For more
      details on the UTF-8 flag see perlunicode. The default is for
      the UTF-8 flag to be turned off.

      Also note that due to some bizarreness in SQLite's type system
      (see <http://www.sqlite.org/datatype3.html>), if you want to
      retain blob-style behavior for some columns under
      "$dbh->{sqlite_unicode} = 1" (say, to store images in the
      database), you have to state so explicitly using the
      3-argument form of "bind_param" in DBI when doing updates:

        use DBI qw(:sql_types);
        $dbh->{sqlite_unicode} = 1;
        my $sth = $dbh->prepare("INSERT INTO mytable (blobcolumn) VALUES (?)");
  
        # Binary_data will be stored as is.
        $sth->bind_param(1, $binary_data, SQL_BLOB);

      Defining the column type as "BLOB" in the DDL is not
      sufficient.

      This attribute was originally named as "unicode", and renamed
      to "sqlite_unicode" for integrity since version 1.26_06. Old
      "unicode" attribute is still accessible but will be deprecated
      in the near future.

  sqlite_allow_multiple_statements
      If you set this to true, "do" method will process multiple
      statements at one go. This may be handy, but with performance
      penalty. See above for details.

  sqlite_use_immediate_transaction
      If you set this to true, DBD::SQLite tries to issue a "begin
      immediate transaction" (instead of "begin transaction") when
      necessary. See above for details.

      As of version 1.38_01, this attribute is set to true by
      default. If you really need to use "deferred" transactions for
      some reasons, set this to false explicitly.

  sqlite_see_if_its_a_number
      If you set this to true, DBD::SQLite tries to see if the bind
      values are number or not, and does not quote if they are
      numbers. See above for details.

  sqlite_extended_result_codes
      If set to true, DBD::SQLite uses extended result codes where
      appropriate (see <http://www.sqlite.org/rescode.html>).

 Statement Handle Attributes
  sqlite_unprepared_statements
      Returns an unprepared part of the statement you pass to
      "prepare". Typically this contains nothing but white spaces
      after a semicolon. See above for details.

METHODS
  See also to the DBI documentation for the details of other common
  methods.

 table_info
    $sth = $dbh->table_info(undef, $schema, $table, $type, \%attr);

  Returns all tables and schemas (databases) as specified in
  "table_info" in DBI. The schema and table arguments will do a
  "LIKE" search. You can specify an ESCAPE character by including an
  'Escape' attribute in \%attr. The $type argument accepts a comma
  separated list of the following types 'TABLE', 'VIEW', 'LOCAL
  TEMPORARY' and 'SYSTEM TABLE' (by default all are returned). Note
  that a statement handle is returned, and not a direct list of
  tables.

  The following fields are returned:

  TABLE_CAT: Always NULL, as SQLite does not have the concept of
  catalogs.

  TABLE_SCHEM: The name of the schema (database) that the table or
  view is in. The default schema is 'main', temporary tables are in
  'temp' and other databases will be in the name given when the
  database was attached.

  TABLE_NAME: The name of the table or view.

  TABLE_TYPE: The type of object returned. Will be one of 'TABLE',
  'VIEW', 'LOCAL TEMPORARY' or 'SYSTEM TABLE'.

 primary_key, primary_key_info
    @names = $dbh->primary_key(undef, $schema, $table);
    $sth   = $dbh->primary_key_info(undef, $schema, $table, \%attr);

  You can retrieve primary key names or more detailed information.
  As noted above, SQLite does not have the concept of catalogs, so
  the first argument of the methods is usually "undef", and you'll
  usually set "undef" for the second one (unless you want to know
  the primary keys of temporary tables).

 foreign_key_info
    $sth = $dbh->foreign_key_info(undef, $pk_schema, $pk_table,
                                  undef, $fk_schema, $fk_table);

  Returns information about foreign key constraints, as specified in
  "foreign_key_info" in DBI, but with some limitations :

  *   information in rows returned by the $sth is incomplete with
      respect to the "foreign_key_info" in DBI specification. All
      requested fields are present, but the content is "undef" for
      some of them.

  The following nonempty fields are returned :

  PKTABLE_NAME: The primary (unique) key table identifier.

  PKCOLUMN_NAME: The primary (unique) key column identifier.

  FKTABLE_NAME: The foreign key table identifier.

  FKCOLUMN_NAME: The foreign key column identifier.

  KEY_SEQ: The column sequence number (starting with 1), when
  several columns belong to a same constraint.

  UPDATE_RULE: The referential action for the UPDATE rule. The
  following codes are defined:

    CASCADE              0
    RESTRICT             1
    SET NULL             2
    NO ACTION            3
    SET DEFAULT          4

  Default is 3 ('NO ACTION').

  DELETE_RULE: The referential action for the DELETE rule. The codes
  are the same as for UPDATE_RULE.

  DEFERRABILITY: The following codes are defined:

    INITIALLY DEFERRED   5
    INITIALLY IMMEDIATE  6
    NOT DEFERRABLE       7

  UNIQUE_OR_PRIMARY: Whether the column is primary or unique.

  Note: foreign key support in SQLite must be explicitly turned on
  through a "PRAGMA" command; see "Foreign keys" earlier in this
  manual.

 statistics_info
    $sth = $dbh->statistics_info(undef, $schema, $table,
                                  $unique_only, $quick);

  Returns information about a table and it's indexes, as specified
  in "statistics_info" in DBI, but with some limitations :

  *   information in rows returned by the $sth is incomplete with
      respect to the "statistics_info" in DBI specification. All
      requested fields are present, but the content is "undef" for
      some of them.

  The following nonempty fields are returned :

  TABLE_SCHEM: The name of the schema (database) that the table is
  in. The default schema is 'main', temporary tables are in 'temp'
  and other databases will be in the name given when the database
  was attached.

  TABLE_NAME: The name of the table

  NON_UNIQUE: Contains 0 for unique indexes, 1 for non-unique
  indexes

  INDEX_NAME: The name of the index

  TYPE: SQLite uses 'btree' for all it's indexes

  ORDINAL_POSITION: Column sequence number (starting with 1).

  COLUMN_NAME: The name of the column

 ping
    my $bool = $dbh->ping;

  returns true if the database file exists (or the database is
  in-memory), and the database connection is active.

DRIVER PRIVATE METHODS
  The following methods can be called via the func() method with a
  little tweak, but the use of func() method is now discouraged by
  the DBI author for various reasons (see DBI's document
  <https://metacpan.org/pod/DBI::DBD#Using-install_method()-to-expos
  e-driver-private-methods> for details). So, if you're using DBI >=
  1.608, use these "sqlite_" methods. If you need to use an older
  DBI, you can call these like this:

    $dbh->func( ..., "(method name without sqlite_ prefix)" );

  Exception: "sqlite_trace" should always be called as is, even with
  "func()" method (to avoid conflict with DBI's trace() method).

    $dbh->func( ..., "sqlite_trace");

 $dbh->sqlite_last_insert_rowid()
  This method returns the last inserted rowid. If you specify an
  INTEGER PRIMARY KEY as the first column in your table, that is the
  column that is returned. Otherwise, it is the hidden ROWID column.
  See the SQLite docs for details.

  Generally you should not be using this method. Use the DBI
  last_insert_id method instead. The usage of this is:

    $h->last_insert_id($catalog, $schema, $table_name, $field_name [, \%attr ])

  Running "$h->last_insert_id("","","","")" is the equivalent of
  running "$dbh->sqlite_last_insert_rowid()" directly.

 $dbh->sqlite_db_filename()
  Retrieve the current (main) database filename. If the database is
  in-memory or temporary, this returns "undef".

 $dbh->sqlite_busy_timeout()
  Retrieve the current busy timeout.

 $dbh->sqlite_busy_timeout( $ms )
  Set the current busy timeout. The timeout is in milliseconds.

 $dbh->sqlite_create_function( $name, $argc, $code_ref, $flags )
  This method will register a new function which will be usable in
  an SQL query. The method's parameters are:

  $name
      The name of the function. This is the name of the function as
      it will be used from SQL.

  $argc
      The number of arguments taken by the function. If this number
      is -1, the function can take any number of arguments.

  $code_ref
      This should be a reference to the function's implementation.

  $flags
      You can optionally pass an extra flag bit to create_function,
      which then would be ORed with SQLITE_UTF8 (default). As of
      1.47_02 (SQLite 3.8.9), only meaning bit is
      SQLITE_DETERMINISTIC (introduced at SQLite 3.8.3), which can
      make the function perform better. See C API documentation at
      <http://sqlite.org/c3ref/create_function.html> for details.

  For example, here is how to define a now() function which returns
  the current number of seconds since the epoch:

    $dbh->sqlite_create_function( 'now', 0, sub { return time } );

  After this, it could be used from SQL as:

    INSERT INTO mytable ( now() );

 REGEXP function
  SQLite includes syntactic support for an infix operator 'REGEXP',
  but without any implementation. The "DBD::SQLite" driver
  automatically registers an implementation that performs standard
  perl regular expression matching, using current locale. So for
  example you can search for words starting with an 'A' with a query
  like

    SELECT * from table WHERE column REGEXP '\bA\w+'

  If you want case-insensitive searching, use perl regex flags, like
  this :

    SELECT * from table WHERE column REGEXP '(?i:\bA\w+)'

  The default REGEXP implementation can be overridden through the
  "create_function" API described above.

  Note that regexp matching will not use SQLite indices, but will
  iterate over all rows, so it could be quite costly in terms of
  performance.

 $dbh->sqlite_create_collation( $name, $code_ref )
  This method manually registers a new function which will be usable
  in an SQL query as a COLLATE option for sorting. Such functions
  can also be registered automatically on demand: see section
  "COLLATION FUNCTIONS" below.

  The method's parameters are:

  $name
      The name of the function exposed to SQL.

  $code_ref
      Reference to the function's implementation. The driver will
      check that this is a proper sorting function.

 $dbh->sqlite_collation_needed( $code_ref )
  This method manually registers a callback function that will be
  invoked whenever an undefined collation sequence is required from
  an SQL statement. The callback is invoked as

    $code_ref->($dbh, $collation_name)

  and should register the desired collation using
  "sqlite_create_collation".

  An initial callback is already registered by "DBD::SQLite", so for
  most common cases it will be simpler to just add your collation
  sequences in the %DBD::SQLite::COLLATION hash (see section
  "COLLATION FUNCTIONS" below).

 $dbh->sqlite_create_aggregate( $name, $argc, $pkg, $flags )
  This method will register a new aggregate function which can then
  be used from SQL. The method's parameters are:

  $name
      The name of the aggregate function, this is the name under
      which the function will be available from SQL.

  $argc
      This is an integer which tells the SQL parser how many
      arguments the function takes. If that number is -1, the
      function can take any number of arguments.

  $pkg
      This is the package which implements the aggregator interface.

  $flags
      You can optionally pass an extra flag bit to create_aggregate,
      which then would be ORed with SQLITE_UTF8 (default). As of
      1.47_02 (SQLite 3.8.9), only meaning bit is
      SQLITE_DETERMINISTIC (introduced at SQLite 3.8.3), which can
      make the function perform better. See C API documentation at
      <http://sqlite.org/c3ref/create_function.html> for details.

  The aggregator interface consists of defining three methods:

  new()
      This method will be called once to create an object which
      should be used to aggregate the rows in a particular group.
      The step() and finalize() methods will be called upon the
      reference return by the method.

  step(@_)
      This method will be called once for each row in the aggregate.

  finalize()
      This method will be called once all rows in the aggregate were
      processed and it should return the aggregate function's
      result. When there is no rows in the aggregate, finalize()
      will be called right after new().

  Here is a simple aggregate function which returns the variance
  (example adapted from pysqlite):

    package variance;
  
    sub new { bless [], shift; }
  
    sub step {
        my ( $self, $value ) = @_;
  
        push @$self, $value;
    }
  
    sub finalize {
        my $self = $_[0];
  
        my $n = @$self;
  
        # Variance is NULL unless there is more than one row
        return undef unless $n || $n == 1;
  
        my $mu = 0;
        foreach my $v ( @$self ) {
            $mu += $v;
        }
        $mu /= $n;
  
        my $sigma = 0;
        foreach my $v ( @$self ) {
            $sigma += ($v - $mu)**2;
        }
        $sigma = $sigma / ($n - 1);
  
        return $sigma;
    }
  
    $dbh->sqlite_create_aggregate( "variance", 1, 'variance' );

  The aggregate function can then be used as:

    SELECT group_name, variance(score)
    FROM results
    GROUP BY group_name;

  For more examples, see the DBD::SQLite::Cookbook.

 $dbh->sqlite_progress_handler( $n_opcodes, $code_ref )
  This method registers a handler to be invoked periodically during
  long running calls to SQLite.

  An example use for this interface is to keep a GUI updated during
  a large query. The parameters are:

  $n_opcodes
      The progress handler is invoked once for every $n_opcodes
      virtual machine opcodes in SQLite.

  $code_ref
      Reference to the handler subroutine. If the progress handler
      returns non-zero, the SQLite operation is interrupted. This
      feature can be used to implement a "Cancel" button on a GUI
      dialog box.

      Set this argument to "undef" if you want to unregister a
      previous progress handler.

 $dbh->sqlite_commit_hook( $code_ref )
  This method registers a callback function to be invoked whenever a
  transaction is committed. Any callback set by a previous call to
  "sqlite_commit_hook" is overridden. A reference to the previous
  callback (if any) is returned. Registering an "undef" disables the
  callback.

  When the commit hook callback returns zero, the commit operation
  is allowed to continue normally. If the callback returns non-zero,
  then the commit is converted into a rollback (in that case, any
  attempt to *explicitly* call "$dbh->rollback()" afterwards would
  yield an error).

 $dbh->sqlite_rollback_hook( $code_ref )
  This method registers a callback function to be invoked whenever a
  transaction is rolled back. Any callback set by a previous call to
  "sqlite_rollback_hook" is overridden. A reference to the previous
  callback (if any) is returned. Registering an "undef" disables the
  callback.

 $dbh->sqlite_update_hook( $code_ref )
  This method registers a callback function to be invoked whenever a
  row is updated, inserted or deleted. Any callback set by a
  previous call to "sqlite_update_hook" is overridden. A reference
  to the previous callback (if any) is returned. Registering an
  "undef" disables the callback.

  The callback will be called as

    $code_ref->($action_code, $database, $table, $rowid)

  where

  $action_code
      is an integer equal to either "DBD::SQLite::INSERT",
      "DBD::SQLite::DELETE" or "DBD::SQLite::UPDATE" (see "Action
      Codes");

  $database
      is the name of the database containing the affected row;

  $table
      is the name of the table containing the affected row;

  $rowid
      is the unique 64-bit signed integer key of the affected row
      within that table.

 $dbh->sqlite_set_authorizer( $code_ref )
  This method registers an authorizer callback to be invoked
  whenever SQL statements are being compiled by the "prepare" in DBI
  method. The authorizer callback should return "DBD::SQLite::OK" to
  allow the action, "DBD::SQLite::IGNORE" to disallow the specific
  action but allow the SQL statement to continue to be compiled, or
  "DBD::SQLite::DENY" to cause the entire SQL statement to be
  rejected with an error. If the authorizer callback returns any
  other value, then "prepare" call that triggered the authorizer
  will fail with an error message.

  An authorizer is used when preparing SQL statements from an
  untrusted source, to ensure that the SQL statements do not try to
  access data they are not allowed to see, or that they do not try
  to execute malicious statements that damage the database. For
  example, an application may allow a user to enter arbitrary SQL
  queries for evaluation by a database. But the application does not
  want the user to be able to make arbitrary changes to the
  database. An authorizer could then be put in place while the
  user-entered SQL is being prepared that disallows everything
  except SELECT statements.

  The callback will be called as

    $code_ref->($action_code, $string1, $string2, $database, $trigger_or_view)

  where

  $action_code
      is an integer that specifies what action is being authorized
      (see "Action Codes").

  $string1, $string2
      are strings that depend on the action code (see "Action
      Codes").

  $database
      is the name of the database ("main", "temp", etc.) if
      applicable.

  $trigger_or_view
      is the name of the inner-most trigger or view that is
      responsible for the access attempt, or "undef" if this access
      attempt is directly from top-level SQL code.

 $dbh->sqlite_backup_from_file( $filename )
  This method accesses the SQLite Online Backup API, and will take a
  backup of the named database file, copying it to, and overwriting,
  your current database connection. This can be particularly handy
  if your current connection is to the special :memory: database,
  and you wish to populate it from an existing DB.

 $dbh->sqlite_backup_to_file( $filename )
  This method accesses the SQLite Online Backup API, and will take a
  backup of the currently connected database, and write it out to
  the named file.

 $dbh->sqlite_enable_load_extension( $bool )
  Calling this method with a true value enables loading (external)
  SQLite3 extensions. After the call, you can load extensions like
  this:

    $dbh->sqlite_enable_load_extension(1);
    $sth = $dbh->prepare("select load_extension('libsqlitefunctions.so')")
    or die "Cannot prepare: " . $dbh->errstr();

 $dbh->sqlite_load_extension( $file, $proc )
  Loading an extension by a select statement (with the
  "load_extension" SQLite3 function like above) has some
  limitations. If you need to, say, create other functions from an
  extension, use this method. $file (a path to the extension) is
  mandatory, and $proc (an entry point name) is optional. You need
  to call "sqlite_enable_load_extension" before calling
  "sqlite_load_extension".

 $dbh->sqlite_trace( $code_ref )
  This method registers a trace callback to be invoked whenever SQL
  statements are being run.

  The callback will be called as

    $code_ref->($statement)

  where

  $statement
      is a UTF-8 rendering of the SQL statement text as the
      statement first begins executing.

  Additional callbacks might occur as each triggered subprogram is
  entered. The callbacks for triggers contain a UTF-8 SQL comment
  that identifies the trigger.

  See also "TRACING" in DBI for better tracing options.

 $dbh->sqlite_profile( $code_ref )
  This method registers a profile callback to be invoked whenever a
  SQL statement finishes.

  The callback will be called as

    $code_ref->($statement, $elapsed_time)

  where

  $statement
      is the original statement text (without bind parameters).

  $elapsed_time
      is an estimate of wall-clock time of how long that statement
      took to run (in milliseconds).

  This method is considered experimental and is subject to change in
  future versions of SQLite.

  See also DBI::Profile for better profiling options.

 $dbh->sqlite_table_column_metadata( $dbname, $tablename, $columnname )
  is for internal use only.

 $dbh->sqlite_db_status()
  Returns a hash reference that holds a set of status information of
  database connection such as cache usage. See
  <http://www.sqlite.org/c3ref/c_dbstatus_options.html> for details.
  You may also pass 0 as an argument to reset the status.

 $sth->sqlite_st_status()
  Returns a hash reference that holds a set of status information of
  SQLite statement handle such as full table scan count. See
  <http://www.sqlite.org/c3ref/c_stmtstatus_counter.html> for
  details. Statement status only holds the current value.

    my $status = $sth->sqlite_st_status();
    my $cur = $status->{fullscan_step};

  You may also pass 0 as an argument to reset the status.

 $dbh->sqlite_create_module()
  Registers a name for a *virtual table module*. Module names must
  be registered before creating a new virtual table using the module
  and before using a preexisting virtual table for the module.
  Virtual tables are explained in DBD::SQLite::VirtualTable.

 $dbh->sqlite_limit( $category_id, $new_value )
  Sets a new run-time limit for the category, and returns the
  current limit. If the new value is a negative number (or omitted),
  the limit is unchanged and just returns the current limit.
  Category ids (SQLITE_LIMIT_LENGTH, SQLITE_LIMIT_VARIABLE_NUMBER,
  etc) can be imported from DBD::SQLite::Constants.

DRIVER FUNCTIONS
 DBD::SQLite::compile_options()
  Returns an array of compile options (available since SQLite
  3.6.23, bundled in DBD::SQLite 1.30_01), or an empty array if the
  bundled library is old or compiled with
  SQLITE_OMIT_COMPILEOPTION_DIAGS.

 DBD::SQLite::sqlite_status()
  Returns a hash reference that holds a set of status information of
  SQLite runtime such as memory usage or page cache usage (see
  <http://www.sqlite.org/c3ref/c_status_malloc_count.html> for
  details). Each of the entry contains the current value and the
  highwater value.

    my $status = DBD::SQLite::sqlite_status();
    my $cur  = $status->{memory_used}{current};
    my $high = $status->{memory_used}{highwater};

  You may also pass 0 as an argument to reset the status.

 DBD::SQLite::strlike($pattern, $string, $escape_char), DBD::SQLite::strglob($pattern, $string)
  As of 1.49_05 (SQLite 3.10.0), you can use these two functions to
  see if a string matches a pattern. These may be useful when you
  create a virtual table or a custom function. See
  <http://sqlite.org/c3ref/strlike.html> and
  <http://sqlite.org/c3ref/strglob.html> for details.

DRIVER CONSTANTS
  A subset of SQLite C constants are made available to Perl, because
  they may be needed when writing hooks or authorizer callbacks. For
  accessing such constants, the "DBD::SQLite" module must be
  explicitly "use"d at compile time. For example, an authorizer that
  forbids any DELETE operation would be written as follows :

    use DBD::SQLite;
    $dbh->sqlite_set_authorizer(sub {
      my $action_code = shift;
      return $action_code == DBD::SQLite::DELETE ? DBD::SQLite::DENY
                                                 : DBD::SQLite::OK;
    });

  The list of constants implemented in "DBD::SQLite" is given below;
  more information can be found ad at
  <http://www.sqlite.org/c3ref/constlist.html>.

 Authorizer Return Codes
    OK
    DENY
    IGNORE

 Action Codes
  The "set_authorizer" method registers a callback function that is
  invoked to authorize certain SQL statement actions. The first
  parameter to the callback is an integer code that specifies what
  action is being authorized. The second and third parameters to the
  callback are strings, the meaning of which varies according to the
  action code. Below is the list of action codes, together with
  their associated strings.

    # constant              string1         string2
    # ========              =======         =======
    CREATE_INDEX            Index Name      Table Name
    CREATE_TABLE            Table Name      undef
    CREATE_TEMP_INDEX       Index Name      Table Name
    CREATE_TEMP_TABLE       Table Name      undef
    CREATE_TEMP_TRIGGER     Trigger Name    Table Name
    CREATE_TEMP_VIEW        View Name       undef
    CREATE_TRIGGER          Trigger Name    Table Name
    CREATE_VIEW             View Name       undef
    DELETE                  Table Name      undef
    DROP_INDEX              Index Name      Table Name
    DROP_TABLE              Table Name      undef
    DROP_TEMP_INDEX         Index Name      Table Name
    DROP_TEMP_TABLE         Table Name      undef
    DROP_TEMP_TRIGGER       Trigger Name    Table Name
    DROP_TEMP_VIEW          View Name       undef
    DROP_TRIGGER            Trigger Name    Table Name
    DROP_VIEW               View Name       undef
    INSERT                  Table Name      undef
    PRAGMA                  Pragma Name     1st arg or undef
    READ                    Table Name      Column Name
    SELECT                  undef           undef
    TRANSACTION             Operation       undef
    UPDATE                  Table Name      Column Name
    ATTACH                  Filename        undef
    DETACH                  Database Name   undef
    ALTER_TABLE             Database Name   Table Name
    REINDEX                 Index Name      undef
    ANALYZE                 Table Name      undef
    CREATE_VTABLE           Table Name      Module Name
    DROP_VTABLE             Table Name      Module Name
    FUNCTION                undef           Function Name
    SAVEPOINT               Operation       Savepoint Name

COLLATION FUNCTIONS
 Definition
  SQLite v3 provides the ability for users to supply arbitrary
  comparison functions, known as user-defined "collation sequences"
  or "collating functions", to be used for comparing two text
  values. <http://www.sqlite.org/datatype3.html#collation> explains
  how collations are used in various SQL expressions.

 Builtin collation sequences
  The following collation sequences are builtin within SQLite :

  BINARY
      Compares string data using memcmp(), regardless of text
      encoding.

  NOCASE
      The same as binary, except the 26 upper case characters of
      ASCII are folded to their lower case equivalents before the
      comparison is performed. Note that only ASCII characters are
      case folded. SQLite does not attempt to do full UTF case
      folding due to the size of the tables required.

  RTRIM
      The same as binary, except that trailing space characters are
      ignored.

  In addition, "DBD::SQLite" automatically installs the following
  collation sequences :

  perl
      corresponds to the Perl "cmp" operator

  perllocale
      Perl "cmp" operator, in a context where "use locale" is
      activated.

 Usage
  You can write for example

    CREATE TABLE foo(
        txt1 COLLATE perl,
        txt2 COLLATE perllocale,
        txt3 COLLATE nocase
    )

  or

    SELECT * FROM foo ORDER BY name COLLATE perllocale

 Unicode handling
  If the attribute "$dbh->{sqlite_unicode}" is set, strings coming
  from the database and passed to the collation function will be
  properly tagged with the utf8 flag; but this only works if the
  "sqlite_unicode" attribute is set before the first call to a perl
  collation sequence . The recommended way to activate unicode is to
  set the parameter at connection time :

    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=foo", "", "",
        {
            RaiseError     => 1,
            sqlite_unicode => 1,
        }
    );

 Adding user-defined collations
  The native SQLite API for adding user-defined collations is
  exposed through methods "sqlite_create_collation" and
  "sqlite_collation_needed".

  To avoid calling these functions every time a $dbh handle is
  created, "DBD::SQLite" offers a simpler interface through the
  %DBD::SQLite::COLLATION hash : just insert your own collation
  functions in that hash, and whenever an unknown collation name is
  encountered in SQL, the appropriate collation function will be
  loaded on demand from the hash. For example, here is a way to sort
  text values regardless of their accented characters :

    use DBD::SQLite;
    $DBD::SQLite::COLLATION{no_accents} = sub {
      my ( $a, $b ) = map lc, @_;
      tr[��������������������������
        [aaaaaacdeeeeiiiinoooooouuuuy] for $a, $b;
      $a cmp $b;
    };
    my $dbh  = DBI->connect("dbi:SQLite:dbname=dbfile");
    my $sql  = "SELECT ... FROM ... ORDER BY ... COLLATE no_accents");
    my $rows = $dbh->selectall_arrayref($sql);

  The builtin "perl" or "perllocale" collations are predefined in
  that same hash.

  The COLLATION hash is a global registry within the current
  process; hence there is a risk of undesired side-effects.
  Therefore, to prevent action at distance, the hash is implemented
  as a "write-only" hash, that will happily accept new entries, but
  will raise an exception if any attempt is made to override or
  delete a existing entry (including the builtin "perl" and
  "perllocale").

  If you really, really need to change or delete an entry, you can
  always grab the tied object underneath %DBD::SQLite::COLLATION ---
  but don't do that unless you really know what you are doing. Also
  observe that changes in the global hash will not modify existing
  collations in existing database handles: it will only affect new
  *requests* for collations. In other words, if you want to change
  the behaviour of a collation within an existing $dbh, you need to
  call the "create_collation" method directly.

FULLTEXT SEARCH
  SQLite is bundled with an extension module for full-text indexing.
  Tables with this feature enabled can be efficiently queried to
  find rows that contain one or more instances of some specified
  words, in any column, even if the table contains many large
  documents.

  Explanations for using this feature are provided in a separate
  document: see DBD::SQLite::Fulltext_search.

R* TREE SUPPORT
  The RTREE extension module within SQLite adds support for creating
  a R-Tree, a special index for range and multidimensional queries.
  This allows users to create tables that can be loaded with (as an
  example) geospatial data such as latitude/longitude coordinates
  for buildings within a city :

    CREATE VIRTUAL TABLE city_buildings USING rtree(
       id,               -- Integer primary key
       minLong, maxLong, -- Minimum and maximum longitude
       minLat, maxLat    -- Minimum and maximum latitude
    );

  then query which buildings overlap or are contained within a
  specified region:

    # IDs that are contained within query coordinates
    my $contained_sql = <<"";
    SELECT id FROM city_buildings
       WHERE  minLong >= ? AND maxLong <= ?
       AND    minLat  >= ? AND maxLat  <= ?
  
    # ... and those that overlap query coordinates
    my $overlap_sql = <<"";
    SELECT id FROM city_buildings
       WHERE    maxLong >= ? AND minLong <= ?
       AND      maxLat  >= ? AND minLat  <= ?
  
    my $contained = $dbh->selectcol_arrayref($contained_sql,undef,
                          $minLong, $maxLong, $minLat, $maxLat);
  
    my $overlapping = $dbh->selectcol_arrayref($overlap_sql,undef,
                          $minLong, $maxLong, $minLat, $maxLat);

  For more detail, please see the SQLite R-Tree page
  (<http://www.sqlite.org/rtree.html>). Note that custom R-Tree
  queries using callbacks, as mentioned in the prior link, have not
  been implemented yet.

VIRTUAL TABLES IMPLEMENTED IN PERL
  SQLite has a concept of "virtual tables" which look like regular
  tables but are implemented internally through specific functions.
  The fulltext or R* tree features described in the previous
  chapters are examples of such virtual tables, implemented in C
  code.

  "DBD::SQLite" also supports virtual tables implemented in *Perl
  code*: see DBD::SQLite::VirtualTable for using or implementing
  such virtual tables. These can have many interesting uses for
  joining regular DBMS data with some other kind of data within your
  Perl programs. Bundled with the present distribution are :

  *   DBD::SQLite::VirtualTable::FileContent : implements a virtual
      column that exposes file contents. This is especially useful
      in conjunction with a fulltext index; see
      DBD::SQLite::Fulltext_search.

  *   DBD::SQLite::VirtualTable::PerlData : binds to a Perl array
      within the Perl program. This can be used for simple
      import/export operations, for debugging purposes, for joining
      data from different sources, etc.

  Other Perl virtual tables may also be published separately on
  CPAN.

FOR DBD::SQLITE EXTENSION AUTHORS
  Since 1.30_01, you can retrieve the bundled SQLite C source and/or
  header like this:

    use File::ShareDir 'dist_dir';
    use File::Spec::Functions 'catfile';
  
    # the whole sqlite3.h header
    my $sqlite3_h = catfile(dist_dir('DBD-SQLite'), 'sqlite3.h');
  
    # or only a particular header, amalgamated in sqlite3.c
    my $what_i_want = 'parse.h';
    my $sqlite3_c = catfile(dist_dir('DBD-SQLite'), 'sqlite3.c');
    open my $fh, '<', $sqlite3_c or die $!;
    my $code = do { local $/; <$fh> };
    my ($parse_h) = $code =~ m{(
      /\*+[ ]Begin[ ]file[ ]$what_i_want[ ]\*+
      .+?
      /\*+[ ]End[ ]of[ ]$what_i_want[ ]\*+/
    )}sx;
    open my $out, '>', $what_i_want or die $!;
    print $out $parse_h;
    close $out;

  You usually want to use this in your extension's "Makefile.PL",
  and you may want to add DBD::SQLite to your extension's
  "CONFIGURE_REQUIRES" to ensure your extension users use the same C
  source/header they use to build DBD::SQLite itself (instead of the
  ones installed in their system).

TO DO
  The following items remain to be done.

 Leak Detection
  Implement one or more leak detection tests that only run during
  AUTOMATED_TESTING and RELEASE_TESTING and validate that none of
  the C code we work with leaks.

 Stream API for Blobs
  Reading/writing into blobs using "sqlite2_blob_open" /
  "sqlite2_blob_close".

 Support for custom callbacks for R-Tree queries
  Custom queries of a R-Tree index using a callback are possible
  with the SQLite C API (<http://www.sqlite.org/rtree.html>), so one
  could potentially use a callback that narrowed the result set down
  based on a specific need, such as querying for overlapping
  circles.

SUPPORT
  Bugs should be reported via the CPAN bug tracker at

  <http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBD-SQLite>

  Note that bugs of bundled SQLite library (i.e. bugs in
  "sqlite3.[ch]") should be reported to the SQLite developers at
  sqlite.org via their bug tracker or via their mailing list.

  The master repository is on GitHub:

  <https://github.com/DBD-SQLite/DBD-SQLite>.

  We also have a mailing list:

  <http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/dbd-sqlite>

AUTHORS
  Matt Sergeant <matt@sergeant.org>

  Francis J. Lacoste <flacoste@logreport.org>

  Wolfgang Sourdeau <wolfgang@logreport.org>

  Adam Kennedy <adamk@cpan.org>

  Max Maischein <corion@cpan.org>

  Laurent Dami <dami@cpan.org>

  Kenichi Ishigaki <ishigaki@cpan.org>

COPYRIGHT
  The bundled SQLite code in this distribution is Public Domain.

  DBD::SQLite is copyright 2002 - 2007 Matt Sergeant.

  Some parts copyright 2008 Francis J. Lacoste.

  Some parts copyright 2008 Wolfgang Sourdeau.

  Some parts copyright 2008 - 2013 Adam Kennedy.

  Some parts copyright 2009 - 2013 Kenichi Ishigaki.

  Some parts derived from DBD::SQLite::Amalgamation copyright 2008
  Audrey Tang.

  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

  The full text of the license can be found in the LICENSE file
  included with this module.

