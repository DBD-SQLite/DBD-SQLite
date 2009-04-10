#define PERL_NO_GET_CONTEXT

#include "SQLiteXS.h"

DBISTATE_DECLARE;

MODULE = DBD::SQLite          PACKAGE = DBD::SQLite::db

PROTOTYPES: DISABLE

BOOT:
    sv_setpv(get_sv("DBD::SQLite::sqlite_version", TRUE|GV_ADDMULTI), SQLITE_VERSION);

AV *
list_tables(dbh)
    SV *dbh
    CODE:
    {
        RETVAL = newAV();
    }
    OUTPUT:
        RETVAL

IV
last_insert_rowid(dbh)
    SV *dbh
    CODE:
    {
        D_imp_dbh(dbh);
        RETVAL = sqlite3_last_insert_rowid(imp_dbh->db);
    }
    OUTPUT:
        RETVAL

void
create_function(dbh, name, argc, func)
    SV *dbh
    char *name
    int argc
    SV *func
    CODE:
    {
        sqlite3_db_create_function(aTHX_ dbh, name, argc, func );
    }

void
enable_load_extension(dbh, onoff)
    SV *dbh
    int onoff
    CODE:
    {
        sqlite3_db_enable_load_extension(aTHX_ dbh, onoff );
    }

void
create_aggregate(dbh, name, argc, aggr)
    SV *dbh
    char *name
    int argc
    SV *aggr
    CODE:
    {
        sqlite3_db_create_aggregate(aTHX_ dbh, name, argc, aggr );
    }

void
create_collation(dbh, name, func)
    SV *dbh
    char *name
    SV *func
    CODE:
    {
        sqlite3_db_create_collation(aTHX_ dbh, name, func );
    }

void
progress_handler(dbh, n_opcodes, handler)
    SV *dbh
    int n_opcodes
    SV *handler
    CODE:
    {
        sqlite3_db_progress_handler(aTHX_ dbh, n_opcodes, handler );
    }

int
busy_timeout(dbh, timeout=0)
  SV *dbh
  int timeout
  CODE:
    RETVAL = dbd_set_sqlite3_busy_timeout(aTHX_ dbh, timeout );
  OUTPUT:
    RETVAL

MODULE = DBD::SQLite          PACKAGE = DBD::SQLite::st

PROTOTYPES: DISABLE

void
reset(sth)
    SV *sth
    CODE:
    {
        sqlite_st_reset(aTHX_ sth);
    }

MODULE = DBD::SQLite          PACKAGE = DBD::SQLite

INCLUDE: SQLite.xsi
