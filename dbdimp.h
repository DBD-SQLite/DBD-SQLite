
#ifndef _DBDIMP_H
#define _DBDIMP_H   1

#include "SQLiteXS.h"
#include "sqlite3.h"

#define PERL_UNICODE_DOES_NOT_WORK_WELL           \
    (PERL_REVISION <= 5) && ((PERL_VERSION < 8)   \
 || (PERL_VERSION == 8 && PERL_SUBVERSION < 5))

/* 30 second timeout by default */
#define SQL_TIMEOUT 30000

#ifndef sqlite3_int64
#define sqlite3_int64 sqlite_int64
#endif

/* Driver Handle */
struct imp_drh_st {
    dbih_drc_t com;
    /* sqlite specific bits */
};

/* Database Handle */
struct imp_dbh_st {
    dbih_dbc_t com;
    /* sqlite specific bits */
    sqlite3 *db;
    bool unicode;
    bool handle_binary_nulls;
    int timeout;
    AV *functions;
    AV *aggregates;
    SV *collation_needed_callback;
    bool allow_multiple_statements;
    bool use_immediate_transaction;
    bool see_if_its_a_number;
};

/* Statement Handle */
struct imp_sth_st {
    dbih_stc_t com;
    /* sqlite specific bits */
    sqlite3_stmt *stmt;
    /*
    char **results;
    char **coldata;
    */
    int retval;
    int nrow;
    AV *params;
    AV *col_types;
    const char *unprepared_statements;
};

#define dbd_init                sqlite_init
#define dbd_discon_all          sqlite_discon_all
#define dbd_db_login6           sqlite_db_login6
#define dbd_db_commit           sqlite_db_commit
#define dbd_db_rollback         sqlite_db_rollback
#define dbd_db_disconnect       sqlite_db_disconnect
#define dbd_db_destroy          sqlite_db_destroy
#define dbd_db_STORE_attrib     sqlite_db_STORE_attrib
#define dbd_db_FETCH_attrib     sqlite_db_FETCH_attrib
#define dbd_db_last_insert_id   sqlite_db_last_insert_id
#define dbd_st_prepare          sqlite_st_prepare
#define dbd_st_rows             sqlite_st_rows
#define dbd_st_execute          sqlite_st_execute
#define dbd_st_fetch            sqlite_st_fetch
#define dbd_st_finish3          sqlite_st_finish3
#define dbd_st_finish           sqlite_st_finish
#define dbd_st_destroy          sqlite_st_destroy
#define dbd_st_blob_read        sqlite_st_blob_read
#define dbd_st_STORE_attrib     sqlite_st_STORE_attrib
#define dbd_st_FETCH_attrib     sqlite_st_FETCH_attrib
#define dbd_bind_ph             sqlite_bind_ph
#define dbd_st_bind_col         sqlite_bind_col

typedef struct aggrInfo aggrInfo;
struct aggrInfo {
  SV *aggr_inst;
  SV *err;
  int inited;
};


int sqlite_db_create_function(pTHX_ SV *dbh, const char *name, int argc, SV *func);

#ifndef SQLITE_OMIT_LOAD_EXTENSION
int sqlite_db_enable_load_extension(pTHX_ SV *dbh, int onoff);
int sqlite_db_load_extension(pTHX_ SV *dbh, const char *file, const char *proc);
#endif

int sqlite_db_create_aggregate(pTHX_ SV *dbh, const char *name, int argc, SV *aggr );
int sqlite_db_create_collation(pTHX_ SV *dbh, const char *name, SV *func);
int sqlite_db_progress_handler(pTHX_ SV *dbh, int n_opcodes, SV *handler);
int sqlite_bind_col( SV *sth, imp_sth_t *imp_sth, SV *col, SV *ref, IV sql_type, SV *attribs );
int sqlite_db_busy_timeout (pTHX_ SV *dbh, int timeout );
int sqlite_db_backup_from_file(pTHX_ SV *dbh, char *filename);
int sqlite_db_backup_to_file(pTHX_ SV *dbh, char *filename);
void sqlite_db_collation_needed(pTHX_ SV *dbh, SV *callback );
SV* sqlite_db_commit_hook( pTHX_ SV *dbh, SV *hook );
SV* sqlite_db_rollback_hook( pTHX_ SV *dbh, SV *hook );
SV* sqlite_db_update_hook( pTHX_ SV *dbh, SV *hook );
int sqlite_db_set_authorizer( pTHX_ SV *dbh, SV *authorizer );
AV* sqlite_compile_options();
int sqlite_db_trace(pTHX_ SV *dbh, SV *func);
int sqlite_db_profile(pTHX_ SV *dbh, SV *func);
HV* sqlite_db_table_column_metadata(pTHX_ SV *dbh, SV *dbname, SV *tablename, SV *columnname);
HV* _sqlite_db_status(pTHX_ SV *dbh, int reset);
SV* sqlite_db_filename(pTHX_ SV *dbh);

int sqlite_db_register_fts3_perl_tokenizer(pTHX_ SV *dbh);
HV* _sqlite_status(int reset);
HV* _sqlite_st_status(pTHX_ SV *sth, int reset);

#ifdef SvUTF8_on

static SV *
newUTF8SVpv(char *s, STRLEN len) {
  dTHX;
  register SV *sv;

  sv = newSVpv(s, len);
  SvUTF8_on(sv);
  return sv;
}

static SV *
newUTF8SVpvn(char *s, STRLEN len) {
  dTHX;
  register SV *sv;

  sv = newSV(0);
  sv_setpvn(sv, s, len);
  SvUTF8_on(sv);
  return sv;
}

#else  /* #ifdef SvUTF8_on */

#define newUTF8SVpv newSVpv
#define newUTF8SVpvn newSVpvn
#define SvUTF8_on(a) (a)
#define SvUTF8_off(a) (a)
#define sv_utf8_upgrade(a) (a)

#endif /* #ifdef SvUTF8_on */

#ifdef _MSC_VER
#  define atoll _atoi64
#endif

#endif /* #ifndef _DBDIMP_H */
