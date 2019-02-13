use strict;
use warnings;
use lib "t/lib";
use SQLiteTest;
use Test::More;
use if -d ".git", "Test::FailWarnings";

BEGIN { requires_sqlite('3.7.7') }

use DBI;
use DBD::SQLite;

my $dbfile = dbfile('foo');
my %uri = (
  base => "file:$dbfile",
  ro   => "file:$dbfile?mode=ro",
  rw   => "file:$dbfile?mode=rw",
  rwc  => "file:$dbfile?mode=rwc",
);

sub cleanup {
  unlink $dbfile if -f $dbfile;
  unlink "file" if -f "file"; # for Win32
  for (keys %uri) {
    unlink $uri{$_} if -f $uri{$_};
  }
}

cleanup();

SKIP: {
  skip 'URI filename is enabled', 1 if has_compile_option('USE_URI');
  my $dbh = eval {
    DBI->connect("dbi:SQLite:$uri{base}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok !$@ && $dbh && !-f $dbfile, "correct database is not created for uri";
  $dbh->disconnect;
  cleanup();
}

# uri=(uri)
{
  my $dbh = eval {
    DBI->connect("dbi:SQLite:uri=$uri{base}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok !$@ && $dbh && -f $dbfile && !-f $uri{base}, "correct database is created for uri";
  $dbh->disconnect;
  cleanup();
}

{
  my $dbh = eval {
    DBI->connect("dbi:SQLite:uri=$uri{ro}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok $@ && !$dbh && !-f $dbfile && !-f $uri{base} && !-f $uri{ro}, "failed to open a nonexistent readonly database for uri";
  cleanup();
}

{
  my $dbh = eval {
    DBI->connect("dbi:SQLite:uri=$uri{rw}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok $@ && !$dbh && !-f $dbfile && !-f $uri{base} && !-f $uri{rw}, "failed to open a nonexistent readwrite database for uri";
  cleanup();
}

{
  my $dbh = eval {
    DBI->connect("dbi:SQLite:uri=$uri{rwc}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok !$@ && $dbh && -f $dbfile && !-f $uri{base} && !-f $uri{rwc}, "correct database is created for uri";
  $dbh->disconnect;
  cleanup();
}

{
  eval {
    DBI->connect("dbi:SQLite:$dbfile", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok !$@ && -f $dbfile, "created a dbfile";

  my $dbh = eval {
    DBI->connect("dbi:SQLite:uri=$uri{ro}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok !$@ && $dbh && -f $dbfile && !-f $uri{base} && !-f $uri{ro}, "opened a correct readonly database for uri";
  $dbh->disconnect;
  cleanup();
}

{
  eval {
    DBI->connect("dbi:SQLite:$dbfile", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok !$@ && -f $dbfile, "created a dbfile";

  my $dbh = eval {
    DBI->connect("dbi:SQLite:uri=$uri{rw}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok !$@ && $dbh && -f $dbfile && !-f $uri{base} && !-f $uri{rw}, "opened a correct readwrite database for uri";
  $dbh->disconnect;
  cleanup();
}

# OPEN_URI flag
{
  my $dbh = eval {
    DBI->connect("dbi:SQLite:$uri{base}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
      sqlite_open_flags => DBD::SQLite::OPEN_URI,
    });
  };
  ok !$@ && $dbh && -f $dbfile && !-f $uri{base}, "correct database is created for uri";
  $dbh->disconnect;
  cleanup();
}

{
  my $dbh = eval {
    DBI->connect("dbi:SQLite:$uri{ro}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
      sqlite_open_flags => DBD::SQLite::OPEN_URI,
    });
  };
  ok $@ && !$dbh && !-f $dbfile && !-f $uri{base} && !-f $uri{ro}, "failed to open a nonexistent readonly database for uri";
  cleanup();
}

{
  my $dbh = eval {
    DBI->connect("dbi:SQLite:$uri{rw}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
      sqlite_open_flags => DBD::SQLite::OPEN_URI,
    });
  };
  ok $@ && !$dbh && !-f $dbfile && !-f $uri{base} && !-f $uri{rw}, "failed to open a nonexistent readwrite database for uri";
  cleanup();
}

{
  my $dbh = eval {
    DBI->connect("dbi:SQLite:$uri{rwc}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
      sqlite_open_flags => DBD::SQLite::OPEN_URI,
    });
  };
  ok !$@ && $dbh && -f $dbfile && !-f $uri{base} && !-f $uri{rwc}, "correct database is created for uri";
  $dbh->disconnect;
  cleanup();
}

{
  eval {
    DBI->connect("dbi:SQLite:$dbfile", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok !$@ && -f $dbfile, "created a dbfile";

  my $dbh = eval {
    DBI->connect("dbi:SQLite:$uri{ro}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
      sqlite_open_flags => DBD::SQLite::OPEN_URI,
    });
  };
  ok !$@ && $dbh && -f $dbfile && !-f $uri{base} && !-f $uri{ro}, "opened a correct readonly database for uri";
  $dbh->disconnect;
  cleanup();
}

{
  eval {
    DBI->connect("dbi:SQLite:$dbfile", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
    });
  };
  ok !$@ && -f $dbfile, "created a dbfile";

  my $dbh = eval {
    DBI->connect("dbi:SQLite:$uri{rw}", undef, undef, {
      PrintError => 0,
      RaiseError => 1,
      sqlite_open_flags => DBD::SQLite::OPEN_URI,
    });
  };
  ok !$@ && $dbh && -f $dbfile && !-f $uri{base} && !-f $uri{rw}, "opened a correct readwrite database for uri";
  $dbh->disconnect;
  cleanup();
}

done_testing;
