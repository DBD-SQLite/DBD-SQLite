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
    ALIAS:
        DBD::SQLite::db::sqlite_last_insert_rowid = 1
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
    ALIAS:
        DBD::SQLite::db::sqlite_create_function = 1
    CODE:
    {
        sqlite3_db_create_function(aTHX_ dbh, name, argc, func );
    }

void
enable_load_extension(dbh, onoff)
    SV *dbh
    int onoff
    ALIAS:
        DBD::SQLite::db::sqlite_enable_load_extension = 1
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
    ALIAS:
        DBD::SQLite::db::sqlite_create_aggregate = 1
    CODE:
    {
        sqlite3_db_create_aggregate(aTHX_ dbh, name, argc, aggr );
    }

void
create_collation(dbh, name, func)
    SV *dbh
    char *name
    SV *func
    ALIAS:
        DBD::SQLite::db::sqlite_create_collation = 1
    CODE:
    {
        sqlite3_db_create_collation(aTHX_ dbh, name, func );
    }

static int
progress_handler(dbh, n_opcodes, handler)
    SV *dbh
    int n_opcodes
    SV *handler
    ALIAS:
        DBD::SQLite::db::sqlite_progress_handler = 1
    CODE:
    {
        RETVAL = sqlite3_db_progress_handler(aTHX_ dbh, n_opcodes, handler );
    }
    OUTPUT:
        RETVAL

int
busy_timeout(dbh, timeout=0)
    SV *dbh
    int timeout
    ALIAS:
        DBD::SQLite::db::sqlite_busy_timeout = 1
    CODE:
        RETVAL = sqlite3_db_busy_timeout(aTHX_ dbh, timeout );
    OUTPUT:
        RETVAL

static int
backup_from_file(dbh, filename)
    SV *dbh
    char *filename
    ALIAS:
        DBD::SQLite::db::sqlite_backup_from_file = 1
    CODE:
        RETVAL = sqlite_db_backup_from_file(aTHX_ dbh, filename);
    OUTPUT:
        RETVAL

static int
backup_to_file(dbh, filename)
    SV *dbh
    char *filename
    ALIAS:
        DBD::SQLite::db::sqlite_backup_to_file = 1
    CODE:
        RETVAL = sqlite_db_backup_to_file(aTHX_ dbh, filename);
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
