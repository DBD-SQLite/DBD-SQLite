#define PERL_NO_GET_CONTEXT

#include "SQLiteXS.h"

DBISTATE_DECLARE;

MODULE = DBD::SQLite          PACKAGE = DBD::SQLite::db

PROTOTYPES: DISABLE

BOOT:
    sv_setpv(get_sv("DBD::SQLite::sqlite_version",        TRUE|GV_ADDMULTI), SQLITE_VERSION);
    sv_setiv(get_sv("DBD::SQLite::sqlite_version_number", TRUE|GV_ADDMULTI), SQLITE_VERSION_NUMBER);

IV
last_insert_rowid(dbh)
    SV *dbh
    ALIAS:
        DBD::SQLite::db::sqlite_last_insert_rowid = 1
    CODE:
    {
        D_imp_dbh(dbh);
        RETVAL = (IV)sqlite3_last_insert_rowid(imp_dbh->db);
    }
    OUTPUT:
        RETVAL

static int
create_function(dbh, name, argc, func)
    SV *dbh
    char *name
    int argc
    SV *func
    ALIAS:
        DBD::SQLite::db::sqlite_create_function = 1
    CODE:
    {
        RETVAL = sqlite_db_create_function(aTHX_ dbh, name, argc, func );
    }
    OUTPUT:
        RETVAL

#ifndef SQLITE_OMIT_LOAD_EXTENSION

static int
enable_load_extension(dbh, onoff)
    SV *dbh
    int onoff
    ALIAS:
        DBD::SQLite::db::sqlite_enable_load_extension = 1
    CODE:
    {
        RETVAL = sqlite_db_enable_load_extension(aTHX_ dbh, onoff );
    }
    OUTPUT:
        RETVAL

static int
load_extension(dbh, file, proc = 0)
    SV *dbh
    const char *file
    const char *proc
    ALIAS:
        DBD::SQLite::db::sqlite_load_extension = 1
    CODE:
    {
        RETVAL = sqlite_db_load_extension(aTHX_ dbh, file, proc);
    }
    OUTPUT:
        RETVAL

#endif

static int
create_aggregate(dbh, name, argc, aggr)
    SV *dbh
    char *name
    int argc
    SV *aggr
    ALIAS:
        DBD::SQLite::db::sqlite_create_aggregate = 1
    CODE:
    {
        RETVAL = sqlite_db_create_aggregate(aTHX_ dbh, name, argc, aggr );
    }
    OUTPUT:
        RETVAL

static int
create_collation(dbh, name, func)
    SV *dbh
    char *name
    SV *func
    ALIAS:
        DBD::SQLite::db::sqlite_create_collation = 1
    CODE:
    {
        RETVAL = sqlite_db_create_collation(aTHX_ dbh, name, func );
    }
    OUTPUT:
        RETVAL


static void
collation_needed(dbh, callback)
    SV *dbh
    SV *callback
    ALIAS:
        DBD::SQLite::db::sqlite_collation_needed = 1
    CODE:
    {
        sqlite_db_collation_needed(aTHX_ dbh, callback );
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
        RETVAL = sqlite_db_progress_handler(aTHX_ dbh, n_opcodes, handler );
    }
    OUTPUT:
        RETVAL

static int
sqlite_trace(dbh, callback)
    SV *dbh
    SV *callback
    CODE:
    {
        RETVAL = sqlite_db_trace(aTHX_ dbh, callback );
    }
    OUTPUT:
        RETVAL

static int
profile(dbh, callback)
    SV *dbh
    SV *callback
    ALIAS:
        DBD::SQLite::db::sqlite_profile = 1
    CODE:
    {
        RETVAL = sqlite_db_profile(aTHX_ dbh, callback );
    }
    OUTPUT:
        RETVAL

SV*
commit_hook(dbh, hook)
    SV *dbh
    SV *hook
    ALIAS:
        DBD::SQLite::db::sqlite_commit_hook = 1
    CODE:
    {
        RETVAL = (SV*) sqlite_db_commit_hook( aTHX_ dbh, hook );
    }
    OUTPUT:
        RETVAL

SV*
rollback_hook(dbh, hook)
    SV *dbh
    SV *hook
    ALIAS:
        DBD::SQLite::db::sqlite_rollback_hook = 1
    CODE:
    {
        RETVAL = (SV*) sqlite_db_rollback_hook( aTHX_ dbh, hook );
    }
    OUTPUT:
        RETVAL

SV*
update_hook(dbh, hook)
    SV *dbh
    SV *hook
    ALIAS:
        DBD::SQLite::db::sqlite_update_hook = 1
    CODE:
    {
        RETVAL = (SV*) sqlite_db_update_hook( aTHX_ dbh, hook );
    }
    OUTPUT:
        RETVAL


static int
set_authorizer(dbh, authorizer)
    SV *dbh
    SV *authorizer
    ALIAS:
        DBD::SQLite::db::sqlite_set_authorizer = 1
    CODE:
    {
        RETVAL = sqlite_db_set_authorizer( aTHX_ dbh, authorizer );
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
        RETVAL = sqlite_db_busy_timeout(aTHX_ dbh, timeout );
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

HV*
table_column_metadata(dbh, dbname, tablename, columnname)
    SV* dbh
    SV* dbname
    SV* tablename
    SV* columnname
    ALIAS:
        DBD::SQLite::db::sqlite_table_column_metadata = 1
    CODE:
        RETVAL = sqlite_db_table_column_metadata(aTHX_ dbh, dbname, tablename, columnname);
    OUTPUT:
        RETVAL

SV*
db_filename(dbh)
    SV* dbh
    ALIAS:
        DBD::SQLite::db::sqlite_db_filename = 1
    CODE:
        RETVAL = sqlite_db_filename(aTHX_ dbh);
    OUTPUT:
        RETVAL

static int
register_fts3_perl_tokenizer(dbh)
    SV *dbh
    ALIAS:
        DBD::SQLite::db::sqlite_register_fts3_perl_tokenizer = 1
    CODE:
        RETVAL = sqlite_db_register_fts3_perl_tokenizer(aTHX_ dbh);
    OUTPUT:
        RETVAL

HV*
db_status(dbh, reset = 0)
    SV* dbh
    int reset
    ALIAS:
        DBD::SQLite::db::sqlite_db_status = 1
    CODE:
        RETVAL = (HV*)_sqlite_db_status(aTHX_ dbh, reset);
    OUTPUT:
        RETVAL


MODULE = DBD::SQLite          PACKAGE = DBD::SQLite::st

PROTOTYPES: DISABLE

HV*
st_status(sth, reset = 0)
    SV* sth
    int reset
    ALIAS:
        DBD::SQLite::st::sqlite_st_status = 1
    CODE:
        RETVAL = (HV*)_sqlite_st_status(aTHX_ sth, reset);
    OUTPUT:
        RETVAL

MODULE = DBD::SQLite          PACKAGE = DBD::SQLite

# a couple of constants exported from sqlite3.h

PROTOTYPES: ENABLE

static int
compile_options()
    CODE:
        int n = 0;
        AV* av = (AV*)sqlite_compile_options();
        if (av) {
            int i;
            n = av_len(av) + 1;
            EXTEND(sp, n);
            for (i = 0; i < n; i++) {
                PUSHs(AvARRAY(av)[i]);
            }
        }
        XSRETURN(n);

HV*
sqlite_status(reset = 0)
    int reset
    CODE:
        RETVAL = (HV*)_sqlite_status(reset);
    OUTPUT:
        RETVAL

static int
OK()
    CODE:
        RETVAL = SQLITE_OK;
    OUTPUT:
        RETVAL

static int
DENY()
    CODE:
        RETVAL = SQLITE_DENY;
    OUTPUT:
        RETVAL

static int
IGNORE()
    CODE:
        RETVAL = SQLITE_IGNORE;
    OUTPUT:
        RETVAL

static int
CREATE_INDEX()
    CODE:
        RETVAL = SQLITE_CREATE_INDEX;
    OUTPUT:
        RETVAL

static int
CREATE_TABLE()
    CODE:
        RETVAL = SQLITE_CREATE_TABLE;
    OUTPUT:
        RETVAL

static int
CREATE_TEMP_INDEX()
    CODE:
        RETVAL = SQLITE_CREATE_TEMP_INDEX;
    OUTPUT:
        RETVAL

static int
CREATE_TEMP_TABLE()
    CODE:
        RETVAL = SQLITE_CREATE_TEMP_TABLE;
    OUTPUT:
        RETVAL

static int
CREATE_TEMP_TRIGGER()
    CODE:
        RETVAL = SQLITE_CREATE_TEMP_TRIGGER;
    OUTPUT:
        RETVAL

static int
CREATE_TEMP_VIEW()
    CODE:
        RETVAL = SQLITE_CREATE_TEMP_VIEW;
    OUTPUT:
        RETVAL

static int
CREATE_TRIGGER()
    CODE:
        RETVAL = SQLITE_CREATE_TRIGGER;
    OUTPUT:
        RETVAL

static int
CREATE_VIEW()
    CODE:
        RETVAL = SQLITE_CREATE_VIEW;
    OUTPUT:
        RETVAL

static int
DELETE()
    CODE:
        RETVAL = SQLITE_DELETE;
    OUTPUT:
        RETVAL

static int
DROP_INDEX()
    CODE:
        RETVAL = SQLITE_DROP_INDEX;
    OUTPUT:
        RETVAL

static int
DROP_TABLE()
    CODE:
        RETVAL = SQLITE_DROP_TABLE;
    OUTPUT:
        RETVAL

static int
DROP_TEMP_INDEX()
    CODE:
        RETVAL = SQLITE_DROP_TEMP_INDEX;
    OUTPUT:
        RETVAL

static int
DROP_TEMP_TABLE()
    CODE:
        RETVAL = SQLITE_DROP_TEMP_TABLE;
    OUTPUT:
        RETVAL

static int
DROP_TEMP_TRIGGER()
    CODE:
        RETVAL = SQLITE_DROP_TEMP_TRIGGER;
    OUTPUT:
        RETVAL

static int
DROP_TEMP_VIEW()
    CODE:
        RETVAL = SQLITE_DROP_TEMP_VIEW;
    OUTPUT:
        RETVAL

static int
DROP_TRIGGER()
    CODE:
        RETVAL = SQLITE_DROP_TRIGGER;
    OUTPUT:
        RETVAL

static int
DROP_VIEW()
    CODE:
        RETVAL = SQLITE_DROP_VIEW;
    OUTPUT:
        RETVAL

static int
INSERT()
    CODE:
        RETVAL = SQLITE_INSERT;
    OUTPUT:
        RETVAL

static int
PRAGMA()
    CODE:
        RETVAL = SQLITE_PRAGMA;
    OUTPUT:
        RETVAL

static int
READ()
    CODE:
        RETVAL = SQLITE_READ;
    OUTPUT:
        RETVAL

static int
SELECT()
    CODE:
        RETVAL = SQLITE_SELECT;
    OUTPUT:
        RETVAL

static int
TRANSACTION()
    CODE:
        RETVAL = SQLITE_TRANSACTION;
    OUTPUT:
        RETVAL

static int
UPDATE()
    CODE:
        RETVAL = SQLITE_UPDATE;
    OUTPUT:
        RETVAL

static int
ATTACH()
    CODE:
        RETVAL = SQLITE_ATTACH;
    OUTPUT:
        RETVAL

static int
DETACH()
    CODE:
        RETVAL = SQLITE_DETACH;
    OUTPUT:
        RETVAL

static int
ALTER_TABLE()
    CODE:
        RETVAL = SQLITE_ALTER_TABLE;
    OUTPUT:
        RETVAL

static int
REINDEX()
    CODE:
        RETVAL = SQLITE_REINDEX;
    OUTPUT:
        RETVAL

static int
ANALYZE()
    CODE:
        RETVAL = SQLITE_ANALYZE;
    OUTPUT:
        RETVAL

static int
CREATE_VTABLE()
    CODE:
        RETVAL = SQLITE_CREATE_VTABLE;
    OUTPUT:
        RETVAL

static int
DROP_VTABLE()
    CODE:
        RETVAL = SQLITE_DROP_VTABLE;
    OUTPUT:
        RETVAL

static int
FUNCTION()
    CODE:
        RETVAL = SQLITE_FUNCTION;
    OUTPUT:
        RETVAL

static int
SAVEPOINT()
    CODE:
#if SQLITE_VERSION_NUMBER >= 3006011
        RETVAL = SQLITE_SAVEPOINT;
#else
		RETVAL = -1;
#endif
    OUTPUT:
        RETVAL

static int
OPEN_READONLY()
    CODE:
        RETVAL = SQLITE_OPEN_READONLY;
    OUTPUT:
        RETVAL

static int
OPEN_READWRITE()
    CODE:
        RETVAL = SQLITE_OPEN_READWRITE;
    OUTPUT:
        RETVAL

static int
OPEN_CREATE()
    CODE:
        RETVAL = SQLITE_OPEN_CREATE;
    OUTPUT:
        RETVAL

static int
OPEN_NOMUTEX()
    CODE:
        RETVAL = SQLITE_OPEN_NOMUTEX;
    OUTPUT:
        RETVAL

static int
OPEN_FULLMUTEX()
    CODE:
        RETVAL = SQLITE_OPEN_FULLMUTEX;
    OUTPUT:
        RETVAL

static int
OPEN_SHAREDCACHE()
    CODE:
        RETVAL = SQLITE_OPEN_SHAREDCACHE;
    OUTPUT:
        RETVAL

static int
OPEN_PRIVATECACHE()
    CODE:
        RETVAL = SQLITE_OPEN_PRIVATECACHE;
    OUTPUT:
        RETVAL

static int
OPEN_URI()
    CODE:
        RETVAL = SQLITE_OPEN_URI;
    OUTPUT:
        RETVAL



INCLUDE: SQLite.xsi
