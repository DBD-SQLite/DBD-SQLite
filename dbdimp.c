#define PERL_NO_GET_CONTEXT

#define NEED_newSVpvn_flags
#define NEED_sv_2pvbyte

#include "SQLiteXS.h"

DBISTATE_DECLARE;

#define SvPV_nolen_undef_ok(x) (SvOK(x) ? SvPV_nolen(x) : "undef")

/*-----------------------------------------------------*
 * Debug Macros
 *-----------------------------------------------------*/

#undef DBD_SQLITE_CROAK_DEBUG

#ifdef DBD_SQLITE_CROAK_DEBUG
  #define croak_if_db_is_null()   if (!imp_dbh->db)   croak("imp_dbh->db is NULL at line %d in %s", __LINE__, __FILE__)
  #define croak_if_stmt_is_null() if (!imp_sth->stmt) croak("imp_sth->stmt is NULL at line %d in %s", __LINE__, __FILE__)
#else
  #define croak_if_db_is_null()
  #define croak_if_stmt_is_null()
#endif


/*-----------------------------------------------------*
 * Globals
 *-----------------------------------------------------*/
imp_dbh_t *last_executed_dbh; /* needed by perl_tokenizer
                                 to know if unicode is on/off */


/*-----------------------------------------------------*
 * Helper Methods
 *-----------------------------------------------------*/

#define sqlite_error(h,rc,what) _sqlite_error(aTHX_ __FILE__, __LINE__, h, rc, what)
#define sqlite_trace(h,xxh,level,what) if ( DBIc_TRACE_LEVEL((imp_xxh_t*)xxh) >= level ) _sqlite_trace(aTHX_ __FILE__, __LINE__, h, (imp_xxh_t*)xxh, what)
#define sqlite_exec(h,sql) _sqlite_exec(aTHX_ h, imp_dbh->db, sql)
#define sqlite_open(dbname,db) _sqlite_open(aTHX_ dbh, dbname, db, 0)
#define sqlite_open2(dbname,db,flags) _sqlite_open(aTHX_ dbh, dbname, db, flags)
#define _isspace(c) (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\v' || c == '\f')

static void
_sqlite_trace(pTHX_ char *file, int line, SV *h, imp_xxh_t *imp_xxh, const char *what)
{
    PerlIO_printf(
        DBIc_LOGPIO(imp_xxh),
        "sqlite trace: %s at %s line %d\n", what, file, line
    );
}

static void
_sqlite_error(pTHX_ char *file, int line, SV *h, int rc, const char *what)
{
    D_imp_xxh(h);

    DBIh_SET_ERR_CHAR(h, imp_xxh, Nullch, rc, what, Nullch, Nullch);

    /* #7753: DBD::SQLite error shouldn't include extraneous info */
    /* sv_catpvf(errstr, "(%d) at %s line %d", rc, file, line); */
    if ( DBIc_TRACE_LEVEL(imp_xxh) >= 3 ) {
        PerlIO_printf(
            DBIc_LOGPIO(imp_xxh),
            "sqlite error %d recorded: %s at %s line %d\n",
            rc, what, file, line
        );
    }
}

int
_sqlite_exec(pTHX_ SV *h, sqlite3 *db, const char *sql)
{
    int rc;
    char *errmsg;

    rc = sqlite3_exec(db, sql, NULL, NULL, &errmsg);
    if ( rc != SQLITE_OK ) {
        sqlite_error(h, rc, errmsg);
        if (errmsg) sqlite3_free(errmsg);
    }
    return rc;
}

int
_sqlite_open(pTHX_ SV *dbh, const char *dbname, sqlite3 **db, int flags)
{
    int rc;
    if (flags) {
        rc = sqlite3_open_v2(dbname, db, flags, NULL);
    } else {
        rc = sqlite3_open(dbname, db);
    }
    if ( rc != SQLITE_OK ) {
        sqlite_error(dbh, rc, sqlite3_errmsg(*db));
        if (*db) sqlite3_close(*db);
    }
    return rc;
}

static int
sqlite_type_to_odbc_type(int type)
{
    switch(type) {
        case SQLITE_INTEGER: return SQL_INTEGER;
        case SQLITE_FLOAT:   return SQL_DOUBLE;
        case SQLITE_TEXT:    return SQL_VARCHAR;
        case SQLITE_BLOB:    return SQL_BLOB;
        case SQLITE_NULL:    return SQL_UNKNOWN_TYPE;
        default:             return SQL_UNKNOWN_TYPE;
    }
}

static int
sqlite_type_from_odbc_type(int type)
{
    switch(type) {
        case SQL_UNKNOWN_TYPE:
            return SQLITE_NULL;
        case SQL_INTEGER:
        case SQL_SMALLINT:
        case SQL_TINYINT:
        case SQL_BIGINT:
            return SQLITE_INTEGER;
        case SQL_FLOAT:
        case SQL_REAL:
        case SQL_DOUBLE:
            return SQLITE_FLOAT;
        case SQL_BLOB:
            return SQLITE_BLOB;
        default:
            return SQLITE_TEXT;
    }
}

static void
sqlite_set_result(pTHX_ sqlite3_context *context, SV *result, int is_error)
{
    STRLEN len;
    char *s;

    if ( is_error ) {
        s = SvPV(result, len);
        sqlite3_result_error( context, s, len );
        return;
    }

    /* warn("result: %s\n", SvPV_nolen(result)); */
    if ( !SvOK(result) ) {
        sqlite3_result_null( context );
    } else if( SvIOK_UV(result) ) {
        if ((UV)(sqlite3_int64)UV_MAX == UV_MAX)
            sqlite3_result_int64( context, (sqlite3_int64)SvUV(result));
        else {
            s = SvPV(result, len);
            sqlite3_result_text( context, s, len, SQLITE_TRANSIENT );
        }
    }
    else if ( SvIOK(result) ) {
#if defined(USE_64_BIT_INT)
        sqlite3_result_int64( context, SvIV(result));
#else
        sqlite3_result_int( context, SvIV(result));
#endif
    } else if ( SvNOK(result) && ( sizeof(NV) == sizeof(double) || SvNVX(result) == (double) SvNVX(result) ) ) {
        sqlite3_result_double( context, SvNV(result));
    } else {
        s = SvPV(result, len);
        sqlite3_result_text( context, s, len, SQLITE_TRANSIENT );
    }
}

/*
 * see also sqlite3IsNumber, sqlite3_int64 type definition,
 * applyNumericAffinity, sqlite3Atoi64, etc from sqlite3.c
 */
static int
sqlite_is_number(pTHX_ const char *v, int sql_type)
{
    const char *z = v;
    const char *d = v;
    int neg;
    int digit = 0;
    int precision = 0;
    bool has_plus = FALSE;
    bool maybe_int = TRUE;
    char format[10];

    if (sql_type != SQLITE_NULL) {
        while (*z == ' ') { z++; v++; d++; }
    }

    if      (*z == '-') { neg = 1; z++; d++; }
    else if (*z == '+') { neg = 0; z++; d++; has_plus = TRUE; }
    else                { neg = 0; }
    if (!isdigit(*z)) return 0;
    while (isdigit(*z)) { digit++; z++; }
#if defined(USE_64_BIT_INT)
    if (digit > 19) maybe_int = FALSE; /* too large for i64 */
    if (digit == 19) {
        int c;
        char tmp[22];
        strncpy(tmp, d, z - d + 1);
        c = memcmp(tmp, "922337203685477580", 18);
        if (c == 0) {
            c = tmp[18] - '7' - neg;
        }
        if (c > 0) maybe_int = FALSE;
    }
#else
    if (digit > 10) maybe_int = FALSE; /* too large for i32 */
    if (digit == 10) {
        int c;
        char tmp[14];
        strncpy(tmp, d, z - d + 1);
        c = memcmp(tmp, "214748364", 9);
        if (c == 0) {
            c = tmp[9] - '7' - neg;
        }
        if (c > 0) maybe_int = FALSE;
    }
#endif
    if (*z == '.') {
        maybe_int = FALSE;
        z++;
        if (!isdigit(*z)) return 0;
        while (isdigit(*z)) { precision++; z++; }
    }
    if (*z == 'e' || *z == 'E') {
        maybe_int = FALSE;
        z++;
        if (*z == '+' || *z == '-') { z++; }
        if (!isdigit(*z)) return 0;
        while (isdigit(*z)) { z++; }
    }
    if (*z && !isdigit(*z)) return 0;

    if (maybe_int || sql_type == SQLITE_INTEGER) {
#if defined(USE_64_BIT_INT)
    #if defined(HAS_ATOLL)
        if (strEQ(form((has_plus ? "+%lli" : "%lli"), atoll(v)), v)) return 1;
    #else
        if (strEQ(form((has_plus ? "+%li" : "%li"), atol(v)), v)) return 1;
    #endif
#else
        if (strEQ(form((has_plus ? "+%i" : "%i"), atoi(v)), v)) return 1;
#endif
    }
    if (sql_type != SQLITE_INTEGER) {
        sprintf(format, (has_plus ? "+%%.%df" : "%%.%df"), precision);
        if (strEQ(form(format, atof(v)), v)) return 2;
    }
    return 0;
}

/*-----------------------------------------------------*
 * DBD Methods
 *-----------------------------------------------------*/

void
sqlite_init(dbistate_t *dbistate)
{
    dTHX;
    DBISTATE_INIT; /* Initialize the DBI macros  */
}

int
sqlite_discon_all(SV *drh, imp_drh_t *imp_drh)
{
    dTHX;
    return FALSE; /* no way to do this */
}

int
sqlite_db_login6(SV *dbh, imp_dbh_t *imp_dbh, char *dbname, char *user, char *pass, SV *attr)
{
    dTHX;
    int rc;

    sqlite_trace(dbh, imp_dbh, 3, form("login '%s' (version %s)", dbname, sqlite3_version));

    if (SvROK(attr) && hv_exists((HV*)SvRV(attr), "sqlite_open_flags", 17)) {
        rc = sqlite_open2(dbname, &(imp_dbh->db), SvIV(*hv_fetch((HV*)SvRV(attr), "sqlite_open_flags", 17, NULL)));
    } else {
        rc = sqlite_open(dbname, &(imp_dbh->db));
    }
    if ( rc != SQLITE_OK ) {
        return FALSE; /* -> undef in lib/DBD/SQLite.pm */
    }
    DBIc_IMPSET_on(imp_dbh);

    imp_dbh->unicode                   = FALSE;
    imp_dbh->functions                 = newAV();
    imp_dbh->aggregates                = newAV();
    imp_dbh->collation_needed_callback = newSVsv( &PL_sv_undef );
    imp_dbh->timeout                   = SQL_TIMEOUT;
    imp_dbh->handle_binary_nulls       = FALSE;
    imp_dbh->allow_multiple_statements = FALSE;
    imp_dbh->use_immediate_transaction = TRUE;
    imp_dbh->see_if_its_a_number       = FALSE;

    sqlite3_busy_timeout(imp_dbh->db, SQL_TIMEOUT);

#if 0
    /*
    ** As of 1.26_06 foreign keys support was enabled by default,
    ** but with further discussion, we agreed to follow what
    ** sqlite team does, i.e. wait until the team think it
    ** reasonable to enable the support by default, as they have
    ** larger users and will allocate enough time for people to
    ** get used to the foreign keys. However, we should say it loud
    ** that sometime in the (near?) future, this feature may break
    ** your applications (and it actually broke applications).
    ** Let everyone be prepared.
    */
    sqlite_exec(dbh, "PRAGMA foreign_keys = ON");
#endif

#if 0
    /*
    ** Enable this to see if you (wrongly) expect an implicit order
    ** of return values from a SELECT statement without ORDER BY.
    */
    sqlite_exec(dbh, "PRAGMA reverse_unordered_selects = ON");
#endif

    DBIc_ACTIVE_on(imp_dbh);

    return TRUE;
}

int
sqlite_db_commit(SV *dbh, imp_dbh_t *imp_dbh)
{
    dTHX;
    int rc;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to commit on inactive database handle");
        return FALSE;
    }

    if (DBIc_is(imp_dbh, DBIcf_AutoCommit)) {
        /* We don't need to warn, because the DBI layer will do it for us */
        return TRUE;
    }

    if (DBIc_is(imp_dbh, DBIcf_BegunWork)) {
        DBIc_off(imp_dbh, DBIcf_BegunWork);
        DBIc_on(imp_dbh,  DBIcf_AutoCommit);
    }

    croak_if_db_is_null();

    if (!sqlite3_get_autocommit(imp_dbh->db)) {
        sqlite_trace(dbh, imp_dbh, 3, "COMMIT TRAN");

        rc = sqlite_exec(dbh, "COMMIT TRANSACTION");
        if (rc != SQLITE_OK) {
            return FALSE; /* -> &sv_no in SQLite.xsi */
        }
    }

    return TRUE;
}

int
sqlite_db_rollback(SV *dbh, imp_dbh_t *imp_dbh)
{
    dTHX;
    int rc;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to rollback on inactive database handle");
        return FALSE;
    }

    if (DBIc_is(imp_dbh, DBIcf_BegunWork)) {
        DBIc_off(imp_dbh, DBIcf_BegunWork);
        DBIc_on(imp_dbh,  DBIcf_AutoCommit);
    }

    croak_if_db_is_null();

    if (!sqlite3_get_autocommit(imp_dbh->db)) {

        sqlite_trace(dbh, imp_dbh, 3, "ROLLBACK TRAN");

        rc = sqlite_exec(dbh, "ROLLBACK TRANSACTION");
        if (rc != SQLITE_OK) {
            return FALSE; /* -> &sv_no in SQLite.xsi */
        }
    }

    return TRUE;
}

int
sqlite_db_disconnect(SV *dbh, imp_dbh_t *imp_dbh)
{
    dTHX;
    int rc;
    sqlite3_stmt *pStmt;

    if (DBIc_is(imp_dbh, DBIcf_AutoCommit) == FALSE) {
        sqlite_db_rollback(dbh, imp_dbh);
    }
    DBIc_ACTIVE_off(imp_dbh);

#if 0
    /*
    ** This cause segfaults when we have virtual tables, as sqlite3
    ** seems to try to finalize the statements for the tables (freed
    ** here) while closing. So we need to find other ways to do the
    ** right thing.
    */
    /* COMPAT: sqlite3_next_stmt is only available for 3006000 or newer */
    while ( (pStmt = sqlite3_next_stmt(imp_dbh->db, 0)) != NULL ) {
        sqlite3_finalize(pStmt);
    }
#endif

    croak_if_db_is_null();

    rc = sqlite3_close(imp_dbh->db);
    if (rc != SQLITE_OK) {
        /*
        ** Most probably we still have unfinalized statements.
        ** Let's try to close them.
        */
        /* COMPAT: sqlite3_next_stmt is only available for 3006000 or newer */
        while ( (pStmt = sqlite3_next_stmt(imp_dbh->db, 0)) != NULL ) {
            sqlite3_finalize(pStmt);
        }

        rc = sqlite3_close(imp_dbh->db);
        if (rc != SQLITE_OK) {
            /*
            ** We still have problems. probably a backup operation
            ** is not finished. We may need to wait for a while if
            ** we get SQLITE_BUSY...
            */
            sqlite_error(dbh, rc, sqlite3_errmsg(imp_dbh->db));
        }
    }

    av_undef(imp_dbh->functions);
    SvREFCNT_dec(imp_dbh->functions);
    imp_dbh->functions = (AV *)NULL;

    av_undef(imp_dbh->aggregates);
    SvREFCNT_dec(imp_dbh->aggregates);
    imp_dbh->aggregates = (AV *)NULL;

    sv_setsv(imp_dbh->collation_needed_callback, &PL_sv_undef);
    SvREFCNT_dec(imp_dbh->collation_needed_callback);
    imp_dbh->collation_needed_callback = (SV *)NULL;

    return TRUE;
}

void
sqlite_db_destroy(SV *dbh, imp_dbh_t *imp_dbh)
{
    dTHX;
    if (DBIc_ACTIVE(imp_dbh)) {
        sqlite_db_disconnect(dbh, imp_dbh);
    }
    imp_dbh->db = NULL;

    DBIc_IMPSET_off(imp_dbh);
}

int
sqlite_db_STORE_attrib(SV *dbh, imp_dbh_t *imp_dbh, SV *keysv, SV *valuesv)
{
    dTHX;
    char *key = SvPV_nolen(keysv);
    int rc;

    croak_if_db_is_null();

    if (strEQ(key, "AutoCommit")) {
        if (SvTRUE(valuesv)) {
            /* commit tran? */
            if ( DBIc_ACTIVE(imp_dbh) && (!DBIc_is(imp_dbh, DBIcf_AutoCommit)) && (!sqlite3_get_autocommit(imp_dbh->db)) ) {
                sqlite_trace(dbh, imp_dbh, 3, "COMMIT TRAN");
                rc = sqlite_exec(dbh, "COMMIT TRANSACTION");
                if (rc != SQLITE_OK) {
                    return TRUE; /* XXX: is this correct? */
                }
            }
        }
        DBIc_set(imp_dbh, DBIcf_AutoCommit, SvTRUE(valuesv));
        return TRUE;
    }
    if (strEQ(key, "sqlite_allow_multiple_statements")) {
        imp_dbh->allow_multiple_statements = !(! SvTRUE(valuesv));
        return TRUE;
    }
    if (strEQ(key, "sqlite_use_immediate_transaction")) {
        imp_dbh->use_immediate_transaction = !(! SvTRUE(valuesv));
        return TRUE;
    }
    if (strEQ(key, "sqlite_see_if_its_a_number")) {
        imp_dbh->see_if_its_a_number = !(! SvTRUE(valuesv));
        return TRUE;
    }
    if (strEQ(key, "sqlite_unicode")) {
#if PERL_UNICODE_DOES_NOT_WORK_WELL
        sqlite_trace(dbh, imp_dbh, 3, form("Unicode support is disabled for this version of perl."));
        imp_dbh->unicode = 0;
#else
        imp_dbh->unicode = !(! SvTRUE(valuesv));
#endif
        return TRUE;
    }
    if (strEQ(key, "unicode")) {
        if (DBIc_has(imp_dbh, DBIcf_WARN))
            warn("\"unicode\" attribute will be deprecated. Use \"sqlite_unicode\" instead.");
#if PERL_UNICODE_DOES_NOT_WORK_WELL
        sqlite_trace(dbh, imp_dbh, 3, form("Unicode support is disabled for this version of perl."));
        imp_dbh->unicode = 0;
#else
        imp_dbh->unicode = !(! SvTRUE(valuesv));
#endif
        return TRUE;
    }
    return FALSE;
}

SV *
sqlite_db_FETCH_attrib(SV *dbh, imp_dbh_t *imp_dbh, SV *keysv)
{
    dTHX;
    char *key = SvPV_nolen(keysv);

    if (strEQ(key, "sqlite_version")) {
        return sv_2mortal(newSVpv(sqlite3_version, 0));
    }
    if (strEQ(key, "sqlite_allow_multiple_statements")) {
        return sv_2mortal(newSViv(imp_dbh->allow_multiple_statements ? 1 : 0));
    }
   if (strEQ(key, "sqlite_use_immediate_transaction")) {
       return sv_2mortal(newSViv(imp_dbh->use_immediate_transaction ? 1 : 0));
   }
   if (strEQ(key, "sqlite_see_if_its_a_number")) {
       return sv_2mortal(newSViv(imp_dbh->see_if_its_a_number ? 1 : 0));
   }
   if (strEQ(key, "sqlite_unicode")) {
#if PERL_UNICODE_DOES_NOT_WORK_WELL
       sqlite_trace(dbh, imp_dbh, 3, "Unicode support is disabled for this version of perl.");
       return sv_2mortal(newSViv(0));
#else
       return sv_2mortal(newSViv(imp_dbh->unicode ? 1 : 0));
#endif
   }
   if (strEQ(key, "unicode")) {
        if (DBIc_has(imp_dbh, DBIcf_WARN))
            warn("\"unicode\" attribute will be deprecated. Use \"sqlite_unicode\" instead.");
#if PERL_UNICODE_DOES_NOT_WORK_WELL
       sqlite_trace(dbh, imp_dbh, 3, "Unicode support is disabled for this version of perl.");
       return sv_2mortal(newSViv(0));
#else
       return sv_2mortal(newSViv(imp_dbh->unicode ? 1 : 0));
#endif
   }

    return NULL;
}

SV *
sqlite_db_last_insert_id(SV *dbh, imp_dbh_t *imp_dbh, SV *catalog, SV *schema, SV *table, SV *field, SV *attr)
{
    dTHX;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to get last inserted id on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();

    return sv_2mortal(newSViv((IV)sqlite3_last_insert_rowid(imp_dbh->db)));
}

int
sqlite_st_prepare(SV *sth, imp_sth_t *imp_sth, char *statement, SV *attribs)
{
    dTHX;
    int rc = 0;
    const char *extra;
    D_imp_dbh_from_sth;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(sth, -2, "attempt to prepare on inactive database handle");
        return FALSE; /* -> undef in lib/DBD/SQLite.pm */
    }

#if 0
    if (*statement == '\0') {
        sqlite_error(sth, -2, "attempt to prepare empty statement");
        return FALSE; /* -> undef in lib/DBD/SQLite.pm */
    }
#endif

    sqlite_trace(sth, imp_sth, 3, form("prepare statement: %s", statement));
    imp_sth->nrow      = -1;
    imp_sth->retval    = SQLITE_OK;
    imp_sth->params    = newAV();
    imp_sth->col_types = newAV();

    croak_if_db_is_null();

    /* COMPAT: sqlite3_prepare_v2 is only available for 3003009 or newer */
    rc = sqlite3_prepare_v2(imp_dbh->db, statement, -1, &(imp_sth->stmt), &extra);
    if (rc != SQLITE_OK) {
        sqlite_error(sth, rc, sqlite3_errmsg(imp_dbh->db));
        if (imp_sth->stmt) {
            rc = sqlite3_finalize(imp_sth->stmt);
            imp_sth->stmt = NULL;
            if (rc != SQLITE_OK) {
                sqlite_error(sth, rc, sqlite3_errmsg(imp_dbh->db));
            }
        }
        return FALSE; /* -> undef in lib/DBD/SQLite.pm */
    }
    if (&extra) {
        imp_sth->unprepared_statements = extra;
    }
    else {
        imp_sth->unprepared_statements = NULL;
    }

    DBIc_NUM_PARAMS(imp_sth) = sqlite3_bind_parameter_count(imp_sth->stmt);
    DBIc_NUM_FIELDS(imp_sth) = sqlite3_column_count(imp_sth->stmt);
    DBIc_IMPSET_on(imp_sth);

    return TRUE;
}

int
sqlite_st_rows(SV *sth, imp_sth_t *imp_sth)
{
    return imp_sth->nrow;
}

int
sqlite_st_execute(SV *sth, imp_sth_t *imp_sth)
{
    dTHX;
    D_imp_dbh_from_sth;
    int rc = 0;
    int num_params = DBIc_NUM_PARAMS(imp_sth);
    int i;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(sth, -2, "attempt to execute on inactive database handle");
        return -2; /* -> undef in SQLite.xsi */
    }

    if (!imp_sth->stmt) return 0;

    croak_if_db_is_null();
    croak_if_stmt_is_null();

    last_executed_dbh = imp_dbh;

    /* COMPAT: sqlite3_sql is only available for 3006000 or newer */
    sqlite_trace(sth, imp_sth, 3, form("executing %s", sqlite3_sql(imp_sth->stmt)));

    if (DBIc_ACTIVE(imp_sth)) {
         sqlite_trace(sth, imp_sth, 3, "execute still active, reset");
         imp_sth->retval = sqlite3_reset(imp_sth->stmt);
         if (imp_sth->retval != SQLITE_OK) {
             sqlite_error(sth, imp_sth->retval, sqlite3_errmsg(imp_dbh->db));
             return -2; /* -> undef in SQLite.xsi */
         }
    }

    for (i = 0; i < num_params; i++) {
        SV **pvalue      = av_fetch(imp_sth->params, 2*i,   0);
        SV **sql_type_sv = av_fetch(imp_sth->params, 2*i+1, 0);
        SV *value        = pvalue ? *pvalue : &PL_sv_undef;
        int sql_type     = sqlite_type_from_odbc_type(sql_type_sv ? SvIV(*sql_type_sv) : SQL_UNKNOWN_TYPE);

        sqlite_trace(sth, imp_sth, 4, form("bind %d type %d as %s", i, sql_type, SvPV_nolen_undef_ok(value)));

        if (!SvOK(value)) {
            sqlite_trace(sth, imp_sth, 5, "binding null");
            rc = sqlite3_bind_null(imp_sth->stmt, i+1);
        }
        else if (sql_type == SQLITE_BLOB) {
            STRLEN len;
            char * data = SvPVbyte(value, len);
            rc = sqlite3_bind_blob(imp_sth->stmt, i+1, data, len, SQLITE_TRANSIENT);
        }
        else {
            STRLEN len;
            const char *data;
            int numtype = 0;

            if (imp_dbh->unicode) {
                sv_utf8_upgrade(value);
            }
            data = SvPV(value, len);

            /*
             *  XXX: For backward compatibility, it'd be better to
             *  accept a value like " 4" as an integer for an integer
             *  type column (see t/19_bindparam.t), at least when
             *  we explicitly specify its type. However, we should
             *  keep spaces when we just guess.
             *  
             *  see_if_its_a_number should be ignored if an explicit
             *  SQL type is set via bind_param().
             */
            if (sql_type == SQLITE_NULL && imp_dbh->see_if_its_a_number) {
                numtype = sqlite_is_number(aTHX_ data, SQLITE_NULL);
            }
            else if (sql_type == SQLITE_INTEGER || sql_type == SQLITE_FLOAT) {
                numtype = sqlite_is_number(aTHX_ data, sql_type);
            }

            if (numtype == 1) {
#if defined(USE_64_BIT_INT)
    #if defined(HAS_ATOLL)
                rc = sqlite3_bind_int64(imp_sth->stmt, i+1, atoll(data));
    #else
                rc = sqlite3_bind_int64(imp_sth->stmt, i+1, atol(data));
    #endif
#else
                rc = sqlite3_bind_int(imp_sth->stmt, i+1, atoi(data));
#endif
            }
            else if (numtype == 2 && sql_type != SQLITE_INTEGER) {
                rc = sqlite3_bind_double(imp_sth->stmt, i+1, atof(data));
            }
            else {
                if (sql_type == SQLITE_INTEGER || sql_type == SQLITE_FLOAT) {
                    /*
                     * die on datatype mismatch did more harm than good
                     * especially when DBIC heavily depends on this
                     * explicit type specification
                     */
                    if (DBIc_has(imp_dbh, DBIcf_PrintWarn))
                        warn(
                            "datatype mismatch: bind param (%d) %s as %s",
                            i, SvPV_nolen_undef_ok(value),
                            (sql_type == SQLITE_INTEGER ? "integer" : "float")
                        );
                }
                rc = sqlite3_bind_text(imp_sth->stmt, i+1, data, len, SQLITE_TRANSIENT);
            }
        }

        if (rc != SQLITE_OK) {
            sqlite_error(sth, rc, sqlite3_errmsg(imp_dbh->db));
            return -4; /* -> undef in SQLite.xsi */
        }
    }

    if (sqlite3_get_autocommit(imp_dbh->db)) {
        /* COMPAT: sqlite3_sql is only available for 3006000 or newer */
        const char *sql = sqlite3_sql(imp_sth->stmt);
        while ( _isspace(sql[0]) || (sql[0] == '-' && sql[1] == '-')) {
          if ( _isspace(sql[0]) ) {
            while ( _isspace(sql[0]) ) sql++;
            continue;
          }
          else if (sql[0] == '-') {
            while ( sql[0] != 0 && sql[0] != '\n' ) sql++;
            continue;
          }
        }
        if ((sql[0] == 'B' || sql[0] == 'b') &&
            (sql[1] == 'E' || sql[1] == 'e') &&
            (sql[2] == 'G' || sql[2] == 'g') &&
            (sql[3] == 'I' || sql[3] == 'i') &&
            (sql[4] == 'N' || sql[4] == 'n')) {
            if (DBIc_is(imp_dbh,  DBIcf_AutoCommit)) {
                DBIc_on(imp_dbh,  DBIcf_BegunWork);
                DBIc_off(imp_dbh, DBIcf_AutoCommit);
            }
        }
        else if (!DBIc_is(imp_dbh, DBIcf_AutoCommit)) {
            sqlite_trace(sth, imp_sth, 3, "BEGIN TRAN");
            if (imp_dbh->use_immediate_transaction) {
                rc = sqlite_exec(sth, "BEGIN IMMEDIATE TRANSACTION");
            } else {
                rc = sqlite_exec(sth, "BEGIN TRANSACTION");
            }
            if (rc != SQLITE_OK) {
                return -2; /* -> undef in SQLite.xsi */
            }
        }
    }
    else if (DBIc_is(imp_dbh, DBIcf_BegunWork)) {
        /* COMPAT: sqlite3_sql is only available for 3006000 or newer */
        const char *sql = sqlite3_sql(imp_sth->stmt);
        while ( _isspace(sql[0]) || (sql[0] == '-' && sql[1] == '-')) {
          if ( _isspace(sql[0]) ) {
            while ( _isspace(sql[0]) ) sql++;
            continue;
          }
          else if (sql[0] == '-') {
            while ( sql[0] != 0 && sql[0] != '\n' ) sql++;
            continue;
          }
        }
        if (((sql[0] == 'C' || sql[0] == 'c') &&
             (sql[1] == 'O' || sql[1] == 'o') &&
             (sql[2] == 'M' || sql[2] == 'm') &&
             (sql[3] == 'M' || sql[3] == 'm') &&
             (sql[4] == 'I' || sql[4] == 'i') &&
             (sql[5] == 'T' || sql[5] == 't')) ||
            ((sql[0] == 'E' || sql[0] == 'e') &&
             (sql[1] == 'N' || sql[1] == 'n') &&
             (sql[2] == 'D' || sql[2] == 'd'))) {
            DBIc_off(imp_dbh, DBIcf_BegunWork);
            DBIc_on(imp_dbh,  DBIcf_AutoCommit);
        }
        else if (
            ((sql[0] == 'R' || sql[0] == 'r') &&
             (sql[1] == 'O' || sql[1] == 'o') &&
             (sql[2] == 'L' || sql[2] == 'l') &&
             (sql[3] == 'L' || sql[3] == 'l') &&
             (sql[4] == 'B' || sql[4] == 'b') &&
             (sql[5] == 'A' || sql[5] == 'a') &&
             (sql[6] == 'C' || sql[6] == 'c') &&
             (sql[7] == 'K' || sql[7] == 'k'))) {
            int l = strlen(sql);
            bool is_savepoint = FALSE;
            for(i = 8; i < l; i++) {
                if (_isspace(sql[i])) continue;
                if (sql[i] == '-' && sql[i+1] == '-') {
                    while (sql[i] != 0 && sql[i] != '\n') i++;
                    continue;
                }
                if (sql[i] == 'T' || sql[i] == 't') {
                    if ((sql[i+0]  == 'T' || sql[i+0]  == 't') &&
                        (sql[i+1]  == 'R' || sql[i+1]  == 'r') &&
                        (sql[i+2]  == 'A' || sql[i+2]  == 'a') &&
                        (sql[i+3]  == 'N' || sql[i+3]  == 'n') &&
                        (sql[i+4]  == 'S' || sql[i+4]  == 's') &&
                        (sql[i+5]  == 'A' || sql[i+5]  == 'a') &&
                        (sql[i+6]  == 'C' || sql[i+6]  == 'c') &&
                        (sql[i+7]  == 'T' || sql[i+7]  == 't') &&
                        (sql[i+8]  == 'I' || sql[i+8]  == 'i') &&
                        (sql[i+9]  == 'O' || sql[i+9]  == 'o') &&
                        (sql[i+10] == 'N' || sql[i+10] == 'n')) {
                        i += 10; continue;
                    }
                    else if (
                        (sql[i+0] == 'T' || sql[i+0] == 't') &&
                        (sql[i+1] == 'O' || sql[i+1] == 'o') &&
                        (sql[i+2] == ' ' || sql[i+2] == '\t')) {
                      /* rolling back to a savepoint should not
                         change AutoCommit status */
                        is_savepoint = TRUE;
                    }
                }
                break;
            }
            if (!is_savepoint) {
                DBIc_off(imp_dbh, DBIcf_BegunWork);
                DBIc_on(imp_dbh,  DBIcf_AutoCommit);
            }
        }
    }

    imp_sth->nrow = 0;

    sqlite_trace(sth, imp_sth, 3, form("Execute returned %d cols", DBIc_NUM_FIELDS(imp_sth)));
    if (DBIc_NUM_FIELDS(imp_sth) == 0) {
        while ((imp_sth->retval = sqlite3_step(imp_sth->stmt)) != SQLITE_DONE) {
            if (imp_sth->retval == SQLITE_ROW) {
                continue;
            }
            sqlite_error(sth, imp_sth->retval, sqlite3_errmsg(imp_dbh->db));
            if (sqlite3_reset(imp_sth->stmt) != SQLITE_OK) {
                sqlite_error(sth, imp_sth->retval, sqlite3_errmsg(imp_dbh->db));
            }
            return -5; /* -> undef in SQLite.xsi */
        }
        /* warn("Finalize\n"); */
        sqlite3_reset(imp_sth->stmt);
        imp_sth->nrow = sqlite3_changes(imp_dbh->db);
        /* warn("Total changes: %d\n", sqlite3_total_changes(imp_dbh->db)); */
        /* warn("Nrow: %d\n", imp_sth->nrow); */
        return imp_sth->nrow;
    }

    imp_sth->retval = sqlite3_step(imp_sth->stmt);
    switch (imp_sth->retval) {
        case SQLITE_ROW:
        case SQLITE_DONE:
            DBIc_ACTIVE_on(imp_sth);
            sqlite_trace(sth, imp_sth, 5, form("exec ok - %d rows, %d cols", imp_sth->nrow, DBIc_NUM_FIELDS(imp_sth)));
            if (DBIc_is(imp_dbh, DBIcf_AutoCommit) && !sqlite3_get_autocommit(imp_dbh->db)) {
                DBIc_on(imp_dbh,  DBIcf_BegunWork);
                DBIc_off(imp_dbh, DBIcf_AutoCommit);
            }
            return 0; /* -> '0E0' in SQLite.xsi */
        default:
            sqlite_error(sth, imp_sth->retval, sqlite3_errmsg(imp_dbh->db));
            if (sqlite3_reset(imp_sth->stmt) != SQLITE_OK) {
                sqlite_error(sth, imp_sth->retval, sqlite3_errmsg(imp_dbh->db));
            }
            return -6; /* -> undef in SQLite.xsi */
    }
}

AV *
sqlite_st_fetch(SV *sth, imp_sth_t *imp_sth)
{
    dTHX;

    AV *av;
    D_imp_dbh_from_sth;
    int numFields = DBIc_NUM_FIELDS(imp_sth);
    int chopBlanks = DBIc_is(imp_sth, DBIcf_ChopBlanks);
    int i;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(sth, -2, "attempt to fetch on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();
    croak_if_stmt_is_null();

    sqlite_trace(sth, imp_sth, 6, form("numFields == %d, nrow == %d", numFields, imp_sth->nrow));

    if (!DBIc_ACTIVE(imp_sth)) {
        return Nullav;
    }

    if (imp_sth->retval == SQLITE_DONE) {
        sqlite_st_finish(sth, imp_sth);
        return Nullav;
    }

    if (imp_sth->retval != SQLITE_ROW) {
        /* error */
        sqlite_error(sth, imp_sth->retval, sqlite3_errmsg(imp_dbh->db));
        sqlite_st_finish(sth, imp_sth);
        return Nullav; /* -> undef in SQLite.xsi */
    }

    imp_sth->nrow++;

    av = DBIc_DBISTATE((imp_xxh_t *)imp_sth)->get_fbav(imp_sth);
    for (i = 0; i < numFields; i++) {
        int len;
        char * val;
        int col_type = sqlite3_column_type(imp_sth->stmt, i);
        SV **sql_type = av_fetch(imp_sth->col_types, i, 0);
        if (sql_type && SvOK(*sql_type)) {
            if (SvIV(*sql_type)) {
                col_type = sqlite_type_from_odbc_type(SvIV(*sql_type));
            }
        }
        switch(col_type) {
            case SQLITE_INTEGER:
                sqlite_trace(sth, imp_sth, 5, form("fetch column %d as integer", i));
#if defined(USE_64_BIT_INT)
                sv_setiv(AvARRAY(av)[i], sqlite3_column_int64(imp_sth->stmt, i));
#else
                val = (char*)sqlite3_column_text(imp_sth->stmt, i);
                if (sqlite_is_number(aTHX_ val, SQLITE_NULL) == 1) {
                    sv_setiv(AvARRAY(av)[i], atoi(val));
                } else {
                    sv_setpv(AvARRAY(av)[i], val);
                    SvUTF8_off(AvARRAY(av)[i]);
                }
#endif
                break;
            case SQLITE_FLOAT:
                /* fetching as float may lose precision info in the perl world */
                sqlite_trace(sth, imp_sth, 5, form("fetch column %d as float", i));
                sv_setnv(AvARRAY(av)[i], sqlite3_column_double(imp_sth->stmt, i));
                break;
            case SQLITE_TEXT:
                sqlite_trace(sth, imp_sth, 5, form("fetch column %d as text", i));
                val = (char*)sqlite3_column_text(imp_sth->stmt, i);

                len = sqlite3_column_bytes(imp_sth->stmt, i);
                if (chopBlanks) {
                    while((len > 0) && (val[len-1] == ' ')) {
                        len--;
                    }
                }
                sv_setpvn(AvARRAY(av)[i], val, len);
                if (imp_dbh->unicode) {
                    SvUTF8_on(AvARRAY(av)[i]);
                } else {
                    SvUTF8_off(AvARRAY(av)[i]);
                }
                break;
            case SQLITE_BLOB:
                sqlite_trace(sth, imp_sth, 5, form("fetch column %d as blob", i));
                len = sqlite3_column_bytes(imp_sth->stmt, i);
                sv_setpvn(AvARRAY(av)[i], sqlite3_column_blob(imp_sth->stmt, i), len);
                SvUTF8_off(AvARRAY(av)[i]);
                break;
            default:
                sqlite_trace(sth, imp_sth, 5, form("fetch column %d as default", i));
                sv_setsv(AvARRAY(av)[i], &PL_sv_undef);
                SvUTF8_off(AvARRAY(av)[i]);
                break;
        }
        SvSETMAGIC(AvARRAY(av)[i]);
    }

    imp_sth->retval = sqlite3_step(imp_sth->stmt);

    return av;
}

int
sqlite_st_finish3(SV *sth, imp_sth_t *imp_sth, int is_destroy)
{
    dTHX;

    D_imp_dbh_from_sth;

    croak_if_db_is_null();
    croak_if_stmt_is_null();

    /* warn("finish statement\n"); */
    if (!DBIc_ACTIVE(imp_sth))
        return TRUE;

    DBIc_ACTIVE_off(imp_sth);

    av_clear(imp_sth->col_types);

    if (!DBIc_ACTIVE(imp_dbh))  /* no longer connected  */
        return TRUE;

    if (is_destroy) {
        return TRUE;
    }

    if ((imp_sth->retval = sqlite3_reset(imp_sth->stmt)) != SQLITE_OK) {
        sqlite_error(sth, imp_sth->retval, sqlite3_errmsg(imp_dbh->db));
        return FALSE; /* -> &sv_no (or void) in SQLite.xsi */
    }

    return TRUE;
}

int
sqlite_st_finish(SV *sth, imp_sth_t *imp_sth)
{
    return sqlite_st_finish3(sth, imp_sth, 0);
}

void
sqlite_st_destroy(SV *sth, imp_sth_t *imp_sth)
{
    dTHX;
    int rc;

    D_imp_dbh_from_sth;

    DBIc_ACTIVE_off(imp_sth);
    if (DBIc_ACTIVE(imp_dbh)) {
        if (imp_sth->stmt) {
            /* COMPAT: sqlite3_sql is only available for 3006000 or newer */
            sqlite_trace(sth, imp_sth, 4, form("destroy statement: %s", sqlite3_sql(imp_sth->stmt)));

            croak_if_db_is_null();
            croak_if_stmt_is_null();

            /* finalize sth when active connection */
            rc = sqlite3_finalize(imp_sth->stmt);
            imp_sth->stmt = NULL;
            if (rc != SQLITE_OK) {
                sqlite_error(sth, rc, sqlite3_errmsg(imp_dbh->db));
            }
        }
    }
    SvREFCNT_dec((SV*)imp_sth->params);
    SvREFCNT_dec((SV*)imp_sth->col_types);
    DBIc_IMPSET_off(imp_sth);
}

int
sqlite_st_blob_read(SV *sth, imp_sth_t *imp_sth,
                    int field, long offset, long len, SV *destrv, long destoffset)
{
    return 0;
}

int
sqlite_st_STORE_attrib(SV *sth, imp_sth_t *imp_sth, SV *keysv, SV *valuesv)
{
    dTHX;
    /* char *key = SvPV_nolen(keysv); */
    return FALSE;
}

SV *
sqlite_st_FETCH_attrib(SV *sth, imp_sth_t *imp_sth, SV *keysv)
{
    dTHX;
    D_imp_dbh_from_sth;
    char *key = SvPV_nolen(keysv);
    SV *retsv = NULL;
    int i,n;

    croak_if_db_is_null();
    croak_if_stmt_is_null();

    if (strEQ(key, "sqlite_unprepared_statements")) {
        return sv_2mortal(newSVpv(imp_sth->unprepared_statements, 0));
    }
/*
    if (!DBIc_ACTIVE(imp_sth)) {
        return NULL;
    }
*/
    /* warn("fetch: %s\n", key); */

    i = DBIc_NUM_FIELDS(imp_sth);

    if (strEQ(key, "NAME")) {
        AV *av = newAV();
        /* warn("Fetch NAME fields: %d\n", i); */
        av_extend(av, i);
        retsv = sv_2mortal(newRV_noinc((SV*)av));
        for (n = 0; n < i; n++) {
            /* warn("Fetch col name %d\n", n); */
            const char *fieldname = sqlite3_column_name(imp_sth->stmt, n);
            if (fieldname) {
                /* warn("Name [%d]: %s\n", n, fieldname); */
                /* char *dot = instr(fieldname, ".");     */
                /* if (dot)  drop table name from field name */
                /*    fieldname = ++dot;     */
                SV *sv_fieldname = newSVpv(fieldname, 0);
                if (imp_dbh->unicode)
                    SvUTF8_on(sv_fieldname);
                av_store(av, n, sv_fieldname);
            }
        }
    }
    else if (strEQ(key, "PRECISION")) {
        AV *av = newAV();
        retsv = sv_2mortal(newRV_noinc((SV*)av));
    }
    else if (strEQ(key, "TYPE")) {
        AV *av = newAV();
        av_extend(av, i);
        retsv = sv_2mortal(newRV_noinc((SV*)av));
        for (n = 0; n < i; n++) {
            const char *fieldtype = sqlite3_column_decltype(imp_sth->stmt, n);
            int type = sqlite3_column_type(imp_sth->stmt, n);
            /* warn("got type: %d = %s\n", type, fieldtype); */
            type = sqlite_type_to_odbc_type(type);
            /* av_store(av, n, newSViv(type)); */
            if (fieldtype)
                av_store(av, n, newSVpv(fieldtype, 0));
            else
                av_store(av, n, newSVpv("VARCHAR", 0));
        }
    }
    else if (strEQ(key, "NULLABLE")) {
        AV *av = newAV();
        av_extend(av, i);
        retsv = sv_2mortal(newRV_noinc((SV*)av));
#if defined(SQLITE_ENABLE_COLUMN_METADATA)
        for (n = 0; n < i; n++) {
            const char *database  = sqlite3_column_database_name(imp_sth->stmt, n);
            const char *tablename = sqlite3_column_table_name(imp_sth->stmt, n);
            const char *fieldname = sqlite3_column_name(imp_sth->stmt, n);
            const char *datatype, *collseq;
            int notnull, primary, autoinc;
            int rc = sqlite3_table_column_metadata(imp_dbh->db, database, tablename, fieldname, &datatype, &collseq, &notnull, &primary, &autoinc);
            if (rc != SQLITE_OK) {
                sqlite_error(sth, rc, sqlite3_errmsg(imp_dbh->db));
                av_store(av, n, newSViv(2)); /* SQL_NULLABLE_UNKNOWN */
            }
            else {
                av_store(av, n, newSViv(!notnull));
            }
        }
#endif
    }
    else if (strEQ(key, "SCALE")) {
        AV *av = newAV();
        retsv = sv_2mortal(newRV_noinc((SV*)av));
    }
    else if (strEQ(key, "NUM_OF_FIELDS")) {
        retsv = sv_2mortal(newSViv(i));
    }
    else if (strEQ(key, "NUM_OF_PARAMS")) {
        retsv = sv_2mortal(newSViv(sqlite3_bind_parameter_count(imp_sth->stmt)));
    }

    return retsv;
}

/* bind parameter
 * NB: We store the params instead of bind immediately because
 *     we might need to re-create the imp_sth->stmt (see top of execute() function)
 *     and so we can't lose these params
 */
int
sqlite_bind_ph(SV *sth, imp_sth_t *imp_sth,
               SV *param, SV *value, IV sql_type, SV *attribs,
               int is_inout, IV maxlen)
{
    dTHX;
    int pos;

    croak_if_stmt_is_null();

    if (is_inout) {
        sqlite_error(sth, -2, "InOut bind params not implemented");
        return FALSE; /* -> &sv_no in SQLite.xsi */
    }

    if (!looks_like_number(param)) {
        STRLEN len;
        char *paramstring;
        paramstring = SvPV(param, len);
        if(paramstring[len] == 0 && strlen(paramstring) == len) {
            pos = sqlite3_bind_parameter_index(imp_sth->stmt, paramstring);
            if (pos == 0) {
                sqlite_error(sth, -2, form("Unknown named parameter: %s", paramstring));
                return FALSE; /* -> &sv_no in SQLite.xsi */
            }
            pos = 2 * (pos - 1);
        }
        else {
            sqlite_error(sth, -2, "<param> could not be coerced to a C string");
            return FALSE; /* -> &sv_no in SQLite.xsi */
        }
    }
    else {
        pos = 2 * (SvIV(param) - 1);
    }
    sqlite_trace(sth, imp_sth, 3, form("bind into 0x%p: %"IVdf" => %s (%"IVdf") pos %d", imp_sth->params, SvIV(param), SvPV_nolen_undef_ok(value), sql_type, pos));
    av_store(imp_sth->params, pos, newSVsv(value));
    if (sql_type) {
        av_store(imp_sth->params, pos+1, newSViv(sql_type));
    }

    return TRUE;
}

int
sqlite_bind_col(SV *sth, imp_sth_t *imp_sth, SV *col, SV *ref, IV sql_type, SV *attribs)
{
    dTHX;

    /* store the type */
    av_store(imp_sth->col_types, SvIV(col)-1, newSViv(sql_type));

    /* Allow default implementation to continue */
    return 1;
}

/*-----------------------------------------------------*
 * Driver Private Methods
 *-----------------------------------------------------*/

AV *
sqlite_compile_options()
{
    dTHX;
    int i = 0;
    const char *option;
    AV *av = newAV();

#if SQLITE_VERSION_NUMBER >= 3006023
#ifndef SQLITE_OMIT_COMPILEOPTION_DIAGS
    while((option = sqlite3_compileoption_get(i++))) {
        av_push(av, newSVpv(option, 0));
    }
#endif
#endif

    return (AV*)sv_2mortal((SV*)av);
}

#define _stores_status(op, key) \
    if (sqlite3_status(op, &cur, &hi, reset) == SQLITE_OK) { \
        anon = newHV(); \
        hv_stores(anon, "current", newSViv(cur)); \
        hv_stores(anon, "highwater", newSViv(hi)); \
        hv_stores(hv, key, newRV_noinc((SV*)anon)); \
    }

#define _stores_dbstatus(op, key) \
    if (sqlite3_db_status(imp_dbh->db, op, &cur, &hi, reset) == SQLITE_OK) { \
        anon = newHV(); \
        hv_stores(anon, "current", newSViv(cur)); \
        hv_stores(anon, "highwater", newSViv(hi)); \
        hv_stores(hv, key, newRV_noinc((SV*)anon)); \
    }

#define _stores_ststatus(op, key) \
    hv_stores(hv, key, newSViv(sqlite3_stmt_status(imp_sth->stmt, op, reset)))

HV *
_sqlite_status(int reset)
{
    dTHX;
    int cur, hi;
    HV *hv = newHV();
    HV *anon;

    _stores_status(SQLITE_STATUS_MEMORY_USED, "memory_used");
    _stores_status(SQLITE_STATUS_PAGECACHE_USED, "pagecache_used");
    _stores_status(SQLITE_STATUS_PAGECACHE_OVERFLOW, "pagecache_overflow");
    _stores_status(SQLITE_STATUS_SCRATCH_USED, "scratch_used");

    _stores_status(SQLITE_STATUS_SCRATCH_OVERFLOW, "scratch_overflow");

    _stores_status(SQLITE_STATUS_MALLOC_SIZE, "malloc_size");
    _stores_status(SQLITE_STATUS_PARSER_STACK, "parser_stack");
    _stores_status(SQLITE_STATUS_PAGECACHE_SIZE, "pagecache_size");
    _stores_status(SQLITE_STATUS_SCRATCH_SIZE, "scratch_size");
    _stores_status(SQLITE_STATUS_MALLOC_COUNT, "malloc_count");
    _stores_status(SQLITE_STATUS_SCRATCH_OVERFLOW, "scratch_overflow");

    return hv;
}

HV *
_sqlite_db_status(pTHX_ SV* dbh, int reset)
{
    D_imp_dbh(dbh);
    int cur, hi;
    HV *hv = newHV();
    HV *anon;

    _stores_dbstatus(SQLITE_DBSTATUS_LOOKASIDE_USED, "lookaside_used");
    _stores_dbstatus(SQLITE_DBSTATUS_CACHE_USED, "cache_used");
    _stores_dbstatus(SQLITE_DBSTATUS_SCHEMA_USED, "schema_used");
    _stores_dbstatus(SQLITE_DBSTATUS_STMT_USED, "stmt_used");
    _stores_dbstatus(SQLITE_DBSTATUS_LOOKASIDE_HIT, "lookaside_hit");
    _stores_dbstatus(SQLITE_DBSTATUS_LOOKASIDE_MISS_SIZE, "lookaside_miss_size");
    _stores_dbstatus(SQLITE_DBSTATUS_LOOKASIDE_MISS_FULL, "lookaside_miss_full");
    _stores_dbstatus(SQLITE_DBSTATUS_CACHE_HIT, "cache_hit");
    _stores_dbstatus(SQLITE_DBSTATUS_CACHE_MISS, "cache_miss");
    _stores_dbstatus(SQLITE_DBSTATUS_CACHE_WRITE, "cache_write");

    return hv;
}

HV *
_sqlite_st_status(pTHX_ SV* sth, int reset)
{
    D_imp_sth(sth);
    HV *hv = newHV();

    _stores_ststatus(SQLITE_STMTSTATUS_FULLSCAN_STEP, "fullscan_step");
    _stores_ststatus(SQLITE_STMTSTATUS_SORT, "sort");
    _stores_ststatus(SQLITE_STMTSTATUS_AUTOINDEX, "autoindex");

    return hv;
}

SV *
sqlite_db_filename(pTHX_ SV *dbh)
{
    D_imp_dbh(dbh);
    const char *filename;

    croak_if_db_is_null();

    filename = sqlite3_db_filename(imp_dbh->db, "main");
    return filename ? newSVpv(filename, 0) : &PL_sv_undef;
}

int
sqlite_db_busy_timeout(pTHX_ SV *dbh, int timeout )
{
    D_imp_dbh(dbh);

    croak_if_db_is_null();

    if (timeout) {
        imp_dbh->timeout = timeout;
        if (!DBIc_ACTIVE(imp_dbh)) {
            sqlite_error(dbh, -2, "attempt to set busy timeout on inactive database handle");
            return -2;
        }
        sqlite3_busy_timeout(imp_dbh->db, timeout);
    }
    return imp_dbh->timeout;
}

static void
sqlite_db_func_dispatcher(int is_unicode, sqlite3_context *context, int argc, sqlite3_value **value)
{
    dTHX;
    dSP;
    int count;
    int i;
    SV *func;

    func      = sqlite3_user_data(context);

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    for ( i=0; i < argc; i++ ) {
        SV *arg;
        STRLEN len;
        int type = sqlite3_value_type(value[i]);
        sqlite_int64 iv;

        /* warn("func dispatch type: %d, value: %s\n", type, sqlite3_value_text(value[i])); */
        switch(type) {
            case SQLITE_INTEGER:
                iv = sqlite3_value_int64(value[i]);
                if ( iv >= IV_MIN && iv <= IV_MAX ) {
                    /* ^^^ compile-time constant (= true) when IV == int64 */
                    arg = sv_2mortal(newSViv((IV)iv));
                }
                else if ( iv >= 0 && iv <= UV_MAX ) {
                    /* warn("integer overflow, cast to UV"); */
                    arg = sv_2mortal(newSVuv((UV)iv));
                }
                else {
                    /* warn("integer overflow, cast to NV"); */
                    arg = sv_2mortal(newSVnv((NV)iv));
                }
                break;
            case SQLITE_FLOAT:
                arg = sv_2mortal(newSVnv(sqlite3_value_double(value[i])));
                break;
            case SQLITE_TEXT:
                len = sqlite3_value_bytes(value[i]);
                arg = newSVpvn((const char *)sqlite3_value_text(value[i]), len);
                if (is_unicode) {
                  SvUTF8_on(arg);
                }
                arg = sv_2mortal(arg);
                break;
            case SQLITE_BLOB:
                len = sqlite3_value_bytes(value[i]);
                arg = sv_2mortal(newSVpvn(sqlite3_value_blob(value[i]), len));
                break;
            default:
                arg = &PL_sv_undef;
        }

        XPUSHs(arg);
    }
    PUTBACK;

    count = call_sv(func, G_SCALAR|G_EVAL);

    SPAGAIN;

    /* Check for an error */
    if (SvTRUE(ERRSV) ) {
        sqlite_set_result(aTHX_ context, ERRSV, 1);
        POPs;
    } else if ( count != 1 ) {
        SV *err = sv_2mortal(newSVpvf( "function should return 1 argument, got %d",
                                       count ));

        sqlite_set_result(aTHX_ context, err, 1);
        /* Clear the stack */
        for ( i=0; i < count; i++ ) {
            POPs;
        }
    } else {
        sqlite_set_result(aTHX_ context, POPs, 0 );
    }

    PUTBACK;

    FREETMPS;
    LEAVE;
}

static void
sqlite_db_func_dispatcher_unicode(sqlite3_context *context, int argc, sqlite3_value **value)
{
    sqlite_db_func_dispatcher(1, context, argc, value);
}

static void
sqlite_db_func_dispatcher_no_unicode(sqlite3_context *context, int argc, sqlite3_value **value)
{
    sqlite_db_func_dispatcher(0, context, argc, value);
}

int
sqlite_db_create_function(pTHX_ SV *dbh, const char *name, int argc, SV *func)
{
    D_imp_dbh(dbh);
    int rc;
    SV *func_sv;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to create function on inactive database handle");
        return FALSE;
    }

    /* Copy the function reference */
    func_sv = newSVsv(func);
    av_push( imp_dbh->functions, func_sv );

    croak_if_db_is_null();

    /* warn("create_function %s with %d args\n", name, argc); */
    rc = sqlite3_create_function( imp_dbh->db, name, argc, SQLITE_UTF8,
                                  func_sv,
                                  imp_dbh->unicode ? sqlite_db_func_dispatcher_unicode
                                                   : sqlite_db_func_dispatcher_no_unicode,
                                  NULL, NULL );
    if ( rc != SQLITE_OK ) {
        sqlite_error(dbh, rc, form("sqlite_create_function failed with error %s", sqlite3_errmsg(imp_dbh->db)));
        return FALSE;
    }
    return TRUE;
}

#ifndef SQLITE_OMIT_LOAD_EXTENSION

int
sqlite_db_enable_load_extension(pTHX_ SV *dbh, int onoff)
{
    D_imp_dbh(dbh);
    int rc;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to enable load extension on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();

    /* COMPAT: sqlite3_enable_load_extension is only available for 3003006 or newer */
    rc = sqlite3_enable_load_extension( imp_dbh->db, onoff );
    if ( rc != SQLITE_OK ) {
        sqlite_error(dbh, rc, form("sqlite_enable_load_extension failed with error %s", sqlite3_errmsg(imp_dbh->db)));
        return FALSE;
    }
    return TRUE;
}

int
sqlite_db_load_extension(pTHX_ SV *dbh, const char *file, const char *proc)
{
    D_imp_dbh(dbh);
    int rc;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to load extension on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();

    /* COMPAT: sqlite3_load_extension is only available for 3003006 or newer */
    rc = sqlite3_load_extension( imp_dbh->db, file, proc, NULL );
    if ( rc != SQLITE_OK ) {
        sqlite_error(dbh, rc, form("sqlite_load_extension failed with error %s", sqlite3_errmsg(imp_dbh->db)));
        return FALSE;
    }
    return TRUE;
}

#endif

HV*
sqlite_db_table_column_metadata(pTHX_ SV *dbh, SV *dbname, SV *tablename, SV *columnname)
{
    D_imp_dbh(dbh);
    const char *datatype, *collseq;
    int notnull, primary, autoinc;
    int rc;
    HV *metadata = newHV();

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to fetch table column metadata on inactive database handle");
        return metadata;
    }

    croak_if_db_is_null();

    /* dbname may be NULL but (table|column)name may not be NULL */ 
    if (!tablename || !SvPOK(tablename)) {
        sqlite_error(dbh, -2, "table_column_metadata requires a table name");
        return metadata;
    }
    if (!columnname || !SvPOK(columnname)) {
        sqlite_error(dbh, -2, "table_column_metadata requires a column name");
        return metadata;
    }

#ifdef SQLITE_ENABLE_COLUMN_METADATA
    rc = sqlite3_table_column_metadata(
       imp_dbh->db,
       (dbname && SvPOK(dbname)) ? SvPV_nolen(dbname) : NULL,
       SvPV_nolen(tablename),
       SvPV_nolen(columnname),
       &datatype, &collseq, &notnull, &primary, &autoinc);
#endif

    if (rc == SQLITE_OK) {
        hv_stores(metadata, "data_type", datatype ? newSVpv(datatype, 0) : newSV(0));
        hv_stores(metadata, "collation_name", collseq ? newSVpv(collseq, 0) : newSV(0));
        hv_stores(metadata, "not_null", newSViv(notnull));
        hv_stores(metadata, "primary", newSViv(primary));
        hv_stores(metadata, "auto_increment", newSViv(autoinc));
    }

    return metadata;
}

static void
sqlite_db_aggr_new_dispatcher(pTHX_ sqlite3_context *context, aggrInfo *aggr_info)
{
    dSP;
    SV *pkg = NULL;
    int count = 0;

    aggr_info->err = NULL;
    aggr_info->aggr_inst = NULL;

    pkg = sqlite3_user_data(context);
    if ( !pkg )
        return;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs( sv_2mortal( newSVsv(pkg) ) );
    PUTBACK;

    count = call_method ("new", G_EVAL|G_SCALAR);
    SPAGAIN;

    aggr_info->inited = 1;

    if ( SvTRUE( ERRSV ) ) {
        aggr_info->err =  newSVpvf("error during aggregator's new(): %s",
                                    SvPV_nolen (ERRSV));
        POPs;
    } else if ( count != 1 ) {
        int i;

        aggr_info->err = newSVpvf("new() should return one value, got %d",
                                   count );
        /* Clear the stack */
        for ( i=0; i < count; i++ ) {
            POPs;
        }
    } else {
        SV *aggr = POPs;
        if ( SvROK(aggr) ) {
            aggr_info->aggr_inst = newSVsv(aggr);
        } else{
            aggr_info->err = newSVpvf( "new() should return a blessed reference" );
        }
    }

    PUTBACK;

    FREETMPS;
    LEAVE;

    return;
}

static void
sqlite_db_aggr_step_dispatcher(sqlite3_context *context,
                               int argc, sqlite3_value **value)
{
    dTHX;
    dSP;
    int i;
    aggrInfo *aggr;

    aggr = sqlite3_aggregate_context(context, sizeof (aggrInfo));
    if ( !aggr )
        return;

    ENTER;
    SAVETMPS;

    /* initialize on first step */
    if ( !aggr->inited ) {
        sqlite_db_aggr_new_dispatcher(aTHX_ context, aggr);
    }

    if ( aggr->err || !aggr->aggr_inst )
        goto cleanup;

    PUSHMARK(SP);
    XPUSHs( sv_2mortal( newSVsv( aggr->aggr_inst ) ));
    for ( i=0; i < argc; i++ ) {
        SV *arg;
        int len = sqlite3_value_bytes(value[i]);
        int type = sqlite3_value_type(value[i]);

        switch(type) {
            case SQLITE_INTEGER:
                arg = sv_2mortal(newSViv(sqlite3_value_int(value[i])));
                break;
            case SQLITE_FLOAT:
                arg = sv_2mortal(newSVnv(sqlite3_value_double(value[i])));
                break;
            case SQLITE_TEXT:
                arg = sv_2mortal(newSVpvn((const char *)sqlite3_value_text(value[i]), len));
                break;
            case SQLITE_BLOB:
                arg = sv_2mortal(newSVpvn(sqlite3_value_blob(value[i]), len));
                break;
            default:
                arg = &PL_sv_undef;
        }

        XPUSHs(arg);
    }
    PUTBACK;

    call_method ("step", G_SCALAR|G_EVAL|G_DISCARD);

    /* Check for an error */
    if (SvTRUE(ERRSV) ) {
      aggr->err = newSVpvf("error during aggregator's step(): %s",
                            SvPV_nolen(ERRSV));
      POPs;
    }

 cleanup:
    FREETMPS;
    LEAVE;
}

static void
sqlite_db_aggr_finalize_dispatcher( sqlite3_context *context )
{
    dTHX;
    dSP;
    aggrInfo *aggr, myAggr;
    int count = 0;

    aggr = sqlite3_aggregate_context(context, 0);

    ENTER;
    SAVETMPS;

    if ( !aggr ) {
        /* SQLite seems to refuse to create a context structure
           from finalize() */
        aggr = &myAggr;
        aggr->aggr_inst = NULL;
        aggr->err = NULL;
        sqlite_db_aggr_new_dispatcher(aTHX_ context, aggr);
    }

    if  ( ! aggr->err && aggr->aggr_inst ) {
        PUSHMARK(SP);
        XPUSHs( sv_2mortal( newSVsv( aggr->aggr_inst )) );
        PUTBACK;

        count = call_method( "finalize", G_SCALAR|G_EVAL );
        SPAGAIN;

        if ( SvTRUE(ERRSV) ) {
            aggr->err = newSVpvf("error during aggregator's finalize(): %s",
                                  SvPV_nolen(ERRSV) ) ;
            POPs;
        } else if ( count != 1 ) {
            int i;
            aggr->err = newSVpvf("finalize() should return 1 value, got %d",
                                  count );
            /* Clear the stack */
            for ( i=0; i<count; i++ ) {
                POPs;
            }
        } else {
            sqlite_set_result(aTHX_ context, POPs, 0);
        }
        PUTBACK;
    }

    if ( aggr->err ) {
        warn( "DBD::SQLite: error in aggregator cannot be reported to SQLite: %s",
            SvPV_nolen( aggr->err ) );

        /* sqlite_set_result(aTHX_ context, aggr->err, 1); */
        SvREFCNT_dec( aggr->err );
        aggr->err = NULL;
    }

    if ( aggr->aggr_inst ) {
         SvREFCNT_dec( aggr->aggr_inst );
         aggr->aggr_inst = NULL;
    }

    FREETMPS;
    LEAVE;
}

int
sqlite_db_create_aggregate(pTHX_ SV *dbh, const char *name, int argc, SV *aggr_pkg)
{
    D_imp_dbh(dbh);
    int rc;
    SV *aggr_pkg_copy;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to create aggregate on inactive database handle");
        return FALSE;
    }

    /* Copy the aggregate reference */
    aggr_pkg_copy = newSVsv(aggr_pkg);
    av_push( imp_dbh->aggregates, aggr_pkg_copy );

    croak_if_db_is_null();

    rc = sqlite3_create_function( imp_dbh->db, name, argc, SQLITE_UTF8,
                                  aggr_pkg_copy,
                                  NULL,
                                  sqlite_db_aggr_step_dispatcher,
                                  sqlite_db_aggr_finalize_dispatcher
                                );

    if ( rc != SQLITE_OK ) {
        sqlite_error(dbh, rc, form("sqlite_create_aggregate failed with error %s", sqlite3_errmsg(imp_dbh->db)));
        return FALSE;
    }
    return TRUE;
}

int
sqlite_db_collation_dispatcher(void *func, int len1, const void *string1,
                                           int len2, const void *string2)
{
    dTHX;
    dSP;
    int cmp = 0;
    int n_retval, i;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal( newSVpvn( string1, len1) ) );
    XPUSHs( sv_2mortal( newSVpvn( string2, len2) ) );
    PUTBACK;
    n_retval = call_sv(func, G_SCALAR);
    SPAGAIN;
    if (n_retval != 1) {
        warn("collation function returned %d arguments", n_retval);
    }
    for(i = 0; i < n_retval; i++) {
        cmp = POPi;
    }
    PUTBACK;
    FREETMPS;
    LEAVE;

    return cmp;
}

int
sqlite_db_collation_dispatcher_utf8(void *func, int len1, const void *string1,
                                                int len2, const void *string2)
{
    dTHX;
    dSP;
    int cmp = 0;
    int n_retval, i;
    SV *sv1, *sv2;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    sv1 = newSVpvn(string1, len1);
    SvUTF8_on(sv1);
    sv2 = newSVpvn(string2, len2);
    SvUTF8_on(sv2);
    XPUSHs( sv_2mortal( sv1 ) );
    XPUSHs( sv_2mortal( sv2 ) );
    PUTBACK;
    n_retval = call_sv(func, G_SCALAR);
    SPAGAIN;
    if (n_retval != 1) {
        warn("collation function returned %d arguments", n_retval);
    }
    for(i = 0; i < n_retval; i++) {
        cmp = POPi;
    }
    PUTBACK;
    FREETMPS;
    LEAVE;

    return cmp;
}

int
sqlite_db_create_collation(pTHX_ SV *dbh, const char *name, SV *func)
{
    D_imp_dbh(dbh);
    int rv, rv2;
    void *aa = "aa";
    void *zz = "zz";

    SV *func_sv = newSVsv(func);

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to create collation on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();

    /* Check that this is a proper collation function */
    rv = sqlite_db_collation_dispatcher(func_sv, 2, aa, 2, aa);
    if (rv != 0) {
        sqlite_trace(dbh, imp_dbh, 3, form("improper collation function: %s(aa, aa) returns %d!", name, rv));
    }
    rv  = sqlite_db_collation_dispatcher(func_sv, 2, aa, 2, zz);
    rv2 = sqlite_db_collation_dispatcher(func_sv, 2, zz, 2, aa);
    if (rv2 != (rv * -1)) {
        sqlite_trace(dbh, imp_dbh, 3, form("improper collation function: '%s' is not symmetric", name));
    }

    /* Copy the func reference so that it can be deallocated at disconnect */
    av_push( imp_dbh->functions, func_sv );

    /* Register the func within sqlite3 */
    rv = sqlite3_create_collation(
        imp_dbh->db, name, SQLITE_UTF8,
        func_sv,
        imp_dbh->unicode ? sqlite_db_collation_dispatcher_utf8
                         : sqlite_db_collation_dispatcher
      );

    if ( rv != SQLITE_OK ) {
        sqlite_error(dbh, rv, form("sqlite_create_collation failed with error %s", sqlite3_errmsg(imp_dbh->db)));
        return FALSE;
    }
    return TRUE;
}

void
sqlite_db_collation_needed_dispatcher(
    void *dbh,
    sqlite3* db,               /* unused */
    int eTextRep,              /* unused */
    const char* collation_name
)
{
    dTHX;
    dSP;

    D_imp_dbh(dbh);

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( dbh );
    XPUSHs( sv_2mortal( newSVpv( collation_name, 0) ) );
    PUTBACK;

    call_sv( imp_dbh->collation_needed_callback, G_VOID );
    SPAGAIN;

    PUTBACK;
    FREETMPS;
    LEAVE;
}

void
sqlite_db_collation_needed(pTHX_ SV *dbh, SV *callback)
{
    D_imp_dbh(dbh);

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to see if collation is needed on inactive database handle");
        return;
    }

    croak_if_db_is_null();

    /* remember the callback within the dbh */
    sv_setsv(imp_dbh->collation_needed_callback, callback);

    /* Register the func within sqlite3 */
    (void) sqlite3_collation_needed( imp_dbh->db,
                                     (void*) (SvOK(callback) ? dbh : NULL),
                                     sqlite_db_collation_needed_dispatcher );
}

int
sqlite_db_generic_callback_dispatcher( void *callback )
{
    dTHX;
    dSP;
    int n_retval, i;
    int retval = 0;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    n_retval = call_sv( callback, G_SCALAR );
    SPAGAIN;
    if ( n_retval != 1 ) {
        warn( "callback returned %d arguments", n_retval );
    }
    for(i = 0; i < n_retval; i++) {
        retval = POPi;
    }
    PUTBACK;
    FREETMPS;
    LEAVE;

    return retval;
}

int
sqlite_db_progress_handler(pTHX_ SV *dbh, int n_opcodes, SV *handler)
{
    D_imp_dbh(dbh);

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to set progress handler on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();

    if (!SvOK(handler)) {
        /* remove previous handler */
        sqlite3_progress_handler( imp_dbh->db, 0, NULL, NULL);
    }
    else {
        SV *handler_sv = newSVsv(handler);

        /* Copy the handler ref so that it can be deallocated at disconnect */
        av_push( imp_dbh->functions, handler_sv );

        /* Register the func within sqlite3 */
        sqlite3_progress_handler( imp_dbh->db, n_opcodes,
                                  sqlite_db_generic_callback_dispatcher,
                                  handler_sv );
    }
    return TRUE;
}

SV*
sqlite_db_commit_hook(pTHX_ SV *dbh, SV *hook)
{
    D_imp_dbh(dbh);
    void *retval;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to set commit hook on inactive database handle");
        return &PL_sv_undef;
    }

    croak_if_db_is_null();

    if (!SvOK(hook)) {
        /* remove previous hook */
        retval = sqlite3_commit_hook( imp_dbh->db, NULL, NULL );
    }
    else {
        SV *hook_sv = newSVsv( hook );

        /* Copy the handler ref so that it can be deallocated at disconnect */
        av_push( imp_dbh->functions, hook_sv );

        /* Register the hook within sqlite3 */
        retval = sqlite3_commit_hook( imp_dbh->db,
                                      sqlite_db_generic_callback_dispatcher,
                                      hook_sv );
    }

    return retval ? newSVsv(retval) : &PL_sv_undef;
}

SV*
sqlite_db_rollback_hook(pTHX_ SV *dbh, SV *hook)
{
    D_imp_dbh(dbh);
    void *retval;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to set rollback hook on inactive database handle");
        return &PL_sv_undef;
    }

    croak_if_db_is_null();

    if (!SvOK(hook)) {
        /* remove previous hook */
        retval = sqlite3_rollback_hook( imp_dbh->db, NULL, NULL );
    }
    else {
        SV *hook_sv = newSVsv( hook );

        /* Copy the handler ref so that it can be deallocated at disconnect */
        av_push( imp_dbh->functions, hook_sv );

        /* Register the hook within sqlite3 */
        retval = sqlite3_rollback_hook( imp_dbh->db,
                                        (void(*)(void *))
                                        sqlite_db_generic_callback_dispatcher,
                                        hook_sv );
    }

    return retval ? newSVsv(retval) : &PL_sv_undef;
}

void
sqlite_db_update_dispatcher( void *callback, int op,
                             char const *database, char const *table,
                             sqlite3_int64 rowid )
{
    dTHX;
    dSP;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);

    XPUSHs( sv_2mortal( newSViv( op          ) ) );
    XPUSHs( sv_2mortal( newSVpv( database, 0 ) ) );
    XPUSHs( sv_2mortal( newSVpv( table,    0 ) ) );
    XPUSHs( sv_2mortal( newSViv( (IV)rowid   ) ) );
    PUTBACK;

    call_sv( callback, G_VOID );
    SPAGAIN;

    PUTBACK;
    FREETMPS;
    LEAVE;
}

SV*
sqlite_db_update_hook(pTHX_ SV *dbh, SV *hook)
{
    D_imp_dbh(dbh);
    void *retval;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to set update hook on inactive database handle");
        return &PL_sv_undef;
    }

    croak_if_db_is_null();

    if (!SvOK(hook)) {
        /* remove previous hook */
        retval = sqlite3_update_hook( imp_dbh->db, NULL, NULL );
    }
    else {
        SV *hook_sv = newSVsv( hook );

        /* Copy the handler ref so that it can be deallocated at disconnect */
        av_push( imp_dbh->functions, hook_sv );

        /* Register the hook within sqlite3 */
        retval = sqlite3_update_hook( imp_dbh->db,
                                      sqlite_db_update_dispatcher,
                                      hook_sv );
    }

    return retval ? newSVsv(retval) : &PL_sv_undef;
}

int
sqlite_db_authorizer_dispatcher (
    void *authorizer,
    int  action_code,
    const char *details_1,
    const char *details_2,
    const char *details_3,
    const char *details_4
)
{
    dTHX;
    dSP;
    int retval = 0;
    int n_retval, i;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);

    XPUSHs( sv_2mortal ( newSViv ( action_code ) ) );

    /* these ifs are ugly but without them, perl 5.8 segfaults */
    XPUSHs( sv_2mortal( details_1 ? newSVpv( details_1, 0 ) : &PL_sv_undef ) );
    XPUSHs( sv_2mortal( details_2 ? newSVpv( details_2, 0 ) : &PL_sv_undef ) );
    XPUSHs( sv_2mortal( details_3 ? newSVpv( details_3, 0 ) : &PL_sv_undef ) );
    XPUSHs( sv_2mortal( details_4 ? newSVpv( details_4, 0 ) : &PL_sv_undef ) );
    PUTBACK;

    n_retval = call_sv(authorizer, G_SCALAR);
    SPAGAIN;
    if ( n_retval != 1 ) {
        warn( "callback returned %d arguments", n_retval );
    }
    for(i = 0; i < n_retval; i++) {
        retval = POPi;
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return retval;
}

int
sqlite_db_set_authorizer(pTHX_ SV *dbh, SV *authorizer)
{
    D_imp_dbh(dbh);
    int retval;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to set authorizer on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();

    if (!SvOK(authorizer)) {
        /* remove previous hook */
        retval = sqlite3_set_authorizer( imp_dbh->db, NULL, NULL );
    }
    else {
        SV *authorizer_sv = newSVsv( authorizer );

        /* Copy the coderef so that it can be deallocated at disconnect */
        av_push( imp_dbh->functions, authorizer_sv );

        /* Register the hook within sqlite3 */
        retval = sqlite3_set_authorizer( imp_dbh->db,
                                         sqlite_db_authorizer_dispatcher,
                                         authorizer_sv );
    }

    return retval;
}

#ifndef SQLITE_OMIT_TRACE
void
sqlite_db_trace_dispatcher(void *callback, const char *sql)
{
    dTHX;
    dSP;
    int n_retval, i;
    int retval = 0;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal( newSVpv( sql, 0 ) ) );
    PUTBACK;

    n_retval = call_sv( callback, G_SCALAR );
    SPAGAIN;
    if ( n_retval != 1 ) {
        warn( "callback returned %d arguments", n_retval );
    }
    for(i = 0; i < n_retval; i++) {
        retval = POPi;
    }
    PUTBACK;
    FREETMPS;
    LEAVE;
}

int
sqlite_db_trace(pTHX_ SV *dbh, SV *func)
{
    D_imp_dbh(dbh);

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to set trace on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();

    if (!SvOK(func)) {
        /* remove previous callback */
        sqlite3_trace( imp_dbh->db, NULL, NULL );
    }
    else {
        SV *func_sv = newSVsv(func);

        /* Copy the func ref so that it can be deallocated at disconnect */
        av_push( imp_dbh->functions, func_sv );

        /* Register the func within sqlite3 */
        sqlite3_trace( imp_dbh->db,
                       sqlite_db_trace_dispatcher,
                       func_sv );
    }
    return TRUE;
}
#endif

void
sqlite_db_profile_dispatcher(void *callback, const char *sql, sqlite3_uint64 elapsed)
{
    dTHX;
    dSP;
    int n_retval, i;
    int retval = 0;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal( newSVpv( sql, 0 ) ) );
    /*
     * The profile callback time is in units of nanoseconds,
     * however the current implementation is only capable of
     * millisecond resolution so the six least significant digits
     * in the time are meaningless.
     * (http://sqlite.org/c3ref/profile.html)
     */
    XPUSHs( sv_2mortal( newSViv( elapsed / 1000000 ) ) );
    PUTBACK;

    n_retval = call_sv( callback, G_SCALAR );
    SPAGAIN;
    if ( n_retval != 1 ) {
        warn( "callback returned %d arguments", n_retval );
    }
    for(i = 0; i < n_retval; i++) {
        retval = POPi;
    }
    PUTBACK;
    FREETMPS;
    LEAVE;
}

int
sqlite_db_profile(pTHX_ SV *dbh, SV *func)
{
    D_imp_dbh(dbh);

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to profile on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();

    if (!SvOK(func)) {
        /* remove previous callback */
        sqlite3_profile( imp_dbh->db, NULL, NULL );
    }
    else {
        SV *func_sv = newSVsv(func);

        /* Copy the func ref so that it can be deallocated at disconnect */
        av_push( imp_dbh->functions, func_sv );

        /* Register the func within sqlite3 */
        sqlite3_profile( imp_dbh->db,
                         sqlite_db_profile_dispatcher,
                         func_sv );
    }
    return TRUE;
}

/* Accesses the SQLite Online Backup API, and fills the currently loaded
 * database from the passed filename.
 * Usual usage of this would be when you're operating on the :memory:
 * special database connection and want to copy it in from a real db.
 */
int
sqlite_db_backup_from_file(pTHX_ SV *dbh, char *filename)
{
    D_imp_dbh(dbh);

#if SQLITE_VERSION_NUMBER >= 3006011
    int rc;
    sqlite3 *pFrom;
    sqlite3_backup *pBackup;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to backup from file on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();

    rc = sqlite_open(filename, &pFrom);
    if ( rc != SQLITE_OK ) {
        return FALSE;
    }

    /* COMPAT: sqlite3_backup_* are only available for 3006011 or newer */
    pBackup = sqlite3_backup_init(imp_dbh->db, "main", pFrom, "main");
    if (pBackup) {
        (void)sqlite3_backup_step(pBackup, -1);
        (void)sqlite3_backup_finish(pBackup);
    }
    rc = sqlite3_errcode(imp_dbh->db);
    (void)sqlite3_close(pFrom);

    if ( rc != SQLITE_OK ) {
        sqlite_error(dbh, rc, form("sqlite_backup_from_file failed with error %s", sqlite3_errmsg(imp_dbh->db)));
        return FALSE;
    }

    return TRUE;
#else
    sqlite_error(dbh, SQLITE_ERROR, form("backup feature requires SQLite 3.6.11 and newer"));
    return FALSE;
#endif
}

/* Accesses the SQLite Online Backup API, and copies the currently loaded
 * database into the passed filename.
 * Usual usage of this would be when you're operating on the :memory:
 * special database connection, and want to back it up to an on-disk file.
 */
int
sqlite_db_backup_to_file(pTHX_ SV *dbh, char *filename)
{
    D_imp_dbh(dbh);

#if SQLITE_VERSION_NUMBER >= 3006011
    int rc;
    sqlite3 *pTo;
    sqlite3_backup *pBackup;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to backup to file on inactive database handle");
        return FALSE;
    }

    croak_if_db_is_null();

    rc = sqlite_open(filename, &pTo);
    if ( rc != SQLITE_OK ) {
        return FALSE;
    }

    /* COMPAT: sqlite3_backup_* are only available for 3006011 or newer */
    pBackup = sqlite3_backup_init(pTo, "main", imp_dbh->db, "main");
    if (pBackup) {
        (void)sqlite3_backup_step(pBackup, -1);
        (void)sqlite3_backup_finish(pBackup);
    }
    rc = sqlite3_errcode(pTo);
    (void)sqlite3_close(pTo);

    if ( rc != SQLITE_OK ) {
        sqlite_error(dbh, rc, form("sqlite_backup_to_file failed with error %s", sqlite3_errmsg(imp_dbh->db)));
        return FALSE;
    }

    return TRUE;
#else
    sqlite_error(dbh, SQLITE_ERROR, form("backup feature requires SQLite 3.6.11 and newer"));
    return FALSE;
#endif
}

typedef struct perl_tokenizer {
    sqlite3_tokenizer base;
    SV *coderef;                 /* the perl tokenizer is a coderef that takes
                                    a string and returns a cursor coderef */
} perl_tokenizer;

typedef struct perl_tokenizer_cursor {
    sqlite3_tokenizer_cursor base;
    SV *coderef;                 /* ref to the closure that returns terms */
    char *pToken;                /* storage for a copy of the last token */
    int nTokenAllocated;         /* space allocated to pToken buffer */

    /* members below are only used if the input string is in utf8 */
    const char *pInput;          /* input we are tokenizing */
    const char *lastByteOffset;  /* offset into pInput */
    int lastCharOffset;          /* char offset corresponding to lastByteOffset */
} perl_tokenizer_cursor;

/*
** Create a new tokenizer instance.
** Will be called whenever a FTS3 table is created with
**   CREATE .. USING fts3( ... , tokenize=perl qualified::function::name)
** where qualified::function::name is a fully qualified perl function
*/
static int perl_tokenizer_Create(
    int argc, const char * const *argv,
    sqlite3_tokenizer **ppTokenizer
){
    dTHX;
    dSP;
    int n_retval;
    SV *retval;
    perl_tokenizer *t;

    if (!argc) {
        return SQLITE_ERROR;
    }

    t = (perl_tokenizer *) sqlite3_malloc(sizeof(*t));
    if( t==NULL ) return SQLITE_NOMEM;
    memset(t, 0, sizeof(*t));

    ENTER;
    SAVETMPS;

    /* call the qualified::function::name */
    PUSHMARK(SP);
    PUTBACK;
    n_retval = call_pv(argv[0], G_SCALAR);
    SPAGAIN;

    /* store a copy of the returned coderef into the tokenizer structure */
    if (n_retval != 1) {
        warn("tokenizer_Create returned %d arguments", n_retval);
    }
    retval = POPs;
    t->coderef   = newSVsv(retval);
    *ppTokenizer = &t->base;

    PUTBACK;
    FREETMPS;
    LEAVE;

    return SQLITE_OK;
}

/*
** Destroy a tokenizer
*/
static int perl_tokenizer_Destroy(sqlite3_tokenizer *pTokenizer){
    dTHX;
    perl_tokenizer *t = (perl_tokenizer *) pTokenizer;
    sv_free(t->coderef);
    sqlite3_free(t);
    return SQLITE_OK;
}

/*
** Prepare to begin tokenizing a particular string.  The input
** string to be tokenized is supposed to be pInput[0..nBytes-1] ..
** except that nBytes passed by fts3 is -1 (don't know why) !
** This is passed to the tokenizer instance, which then returns a
** closure implementing the cursor (so the cursor is again a coderef).
*/
static int perl_tokenizer_Open(
    sqlite3_tokenizer *pTokenizer,       /* Tokenizer object */
    const char *pInput, int nBytes,      /* Input buffer */
    sqlite3_tokenizer_cursor **ppCursor  /* OUT: Created tokenizer cursor */
){
    dTHX;
    dSP;
    U32 flags;
    SV *perl_string;
    int n_retval;

    perl_tokenizer *t = (perl_tokenizer *)pTokenizer;

    /* allocate and initialize the cursor struct */
    perl_tokenizer_cursor *c;
    c = (perl_tokenizer_cursor *) sqlite3_malloc(sizeof(*c));
    memset(c, 0, sizeof(*c));
    *ppCursor = &c->base;

    /* flags for creating the Perl SV containing the input string */
    flags = SVs_TEMP; /* will call sv_2mortal */

    /* special handling if working with utf8 strings */
    if (last_executed_dbh->unicode) { /* global var ... no better way ! */

        /* data to keep track of byte offsets */
        c->lastByteOffset = c->pInput = pInput;
        c->lastCharOffset = 0;

        /* string passed to Perl needs to be flagged as utf8 */
        flags |= SVf_UTF8;
    }

    ENTER;
    SAVETMPS;

    /* build a Perl copy of the input string */
    if (nBytes < 0) { /* we get -1 from fts3. Don't know why ! */
        nBytes = strlen(pInput);
    }
    perl_string = newSVpvn_flags(pInput, nBytes, flags);

    /* call the tokenizer coderef */
    PUSHMARK(SP);
    XPUSHs(perl_string);
    PUTBACK;
    n_retval = call_sv(t->coderef, G_SCALAR);
    SPAGAIN;

    /* store the cursor coderef returned by the tokenizer */
    if (n_retval != 1) {
        warn("tokenizer returned %d arguments", n_retval);
    }
    c->coderef = newSVsv(POPs);

    PUTBACK;
    FREETMPS;
    LEAVE;
    return SQLITE_OK;
}

/*
** Close a tokenization cursor previously opened by a call to
** perl_tokenizer_Open() above.
*/
static int perl_tokenizer_Close(sqlite3_tokenizer_cursor *pCursor){
    perl_tokenizer_cursor *c = (perl_tokenizer_cursor *) pCursor;

    dTHX;
    sv_free(c->coderef);
    if (c->pToken) sqlite3_free(c->pToken);
    sqlite3_free(c);
    return SQLITE_OK;
}

/*
** Extract the next token from a tokenization cursor.  The cursor must
** have been opened by a prior call to perl_tokenizer_Open().
*/
static int perl_tokenizer_Next(
    sqlite3_tokenizer_cursor *pCursor,  /* Cursor returned by perl_tokenizer_Open */
    const char **ppToken,               /* OUT: *ppToken is the token text */
    int *pnBytes,                       /* OUT: Number of bytes in token */
    int *piStartOffset,                 /* OUT: Starting offset of token */
    int *piEndOffset,                   /* OUT: Ending offset of token */
    int *piPosition                     /* OUT: Position integer of token */
){
    perl_tokenizer_cursor *c = (perl_tokenizer_cursor *) pCursor;
    int result;
    int n_retval;
    STRLEN n_a;
    char *token;
    char *byteOffset;
    I32 hop;

    dTHX;
    dSP;

    ENTER;
    SAVETMPS;

    /* call the cursor */
    PUSHMARK(SP);
    PUTBACK;
    n_retval = call_sv(c->coderef, G_ARRAY);
    SPAGAIN;

    /* if we get back an empty list, there is no more token */
    if (n_retval == 0) {
        result = SQLITE_DONE;
    }
    /* otherwise, get token details from the return list */
    else {
        if (n_retval != 5) {
            warn("tokenizer cursor returned %d arguments", n_retval);
        }
        *piPosition    = POPi;
        *piEndOffset   = POPi;
        *piStartOffset = POPi;
        *pnBytes       = POPi;
        token          = POPpx;

        if (c->pInput) { /* if working with utf8 data */

            /* recompute *pnBytes in bytes, not in chars */
            *pnBytes = strlen(token);

            /* recompute start/end offsets in bytes, not in chars */
            hop            = *piStartOffset - c->lastCharOffset;
            byteOffset     = (char*)utf8_hop((U8*)c->lastByteOffset, hop);
            hop            = *piEndOffset - *piStartOffset;
            *piStartOffset = byteOffset - c->pInput;
            byteOffset     = (char*)utf8_hop((U8*)byteOffset, hop);
            *piEndOffset   = byteOffset - c->pInput;

            /* remember where we are for next round */
            c->lastCharOffset = *piEndOffset,
            c->lastByteOffset = byteOffset;
        }

        /* make sure we have enough storage for copying the token */
        if (*pnBytes > c->nTokenAllocated ){
            char *pNew;
            c->nTokenAllocated = *pnBytes + 20;
            pNew = sqlite3_realloc(c->pToken, c->nTokenAllocated);
            if( !pNew ) return SQLITE_NOMEM;
            c->pToken = pNew;
        }

        /* need to copy the token into the C cursor before perl frees that
           memory */
        memcpy(c->pToken, token, *pnBytes);
        *ppToken  = c->pToken;

        result = SQLITE_OK;
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return result;
}

/*
** The set of routines that implement the perl tokenizer
*/
sqlite3_tokenizer_module perl_tokenizer_Module = {
    0,
    perl_tokenizer_Create,
    perl_tokenizer_Destroy,
    perl_tokenizer_Open,
    perl_tokenizer_Close,
    perl_tokenizer_Next
};

/*
** Register the perl tokenizer with FTS3
*/
int sqlite_db_register_fts3_perl_tokenizer(pTHX_ SV *dbh)
{
    D_imp_dbh(dbh);

    int rc;
    sqlite3_stmt *pStmt;
    const char zSql[] = "SELECT fts3_tokenizer(?, ?)";
    sqlite3_tokenizer_module *p = &perl_tokenizer_Module;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to register fts3 tokenizer on inactive database handle");
        return FALSE;
    }

    rc = sqlite3_prepare_v2(imp_dbh->db, zSql, -1, &pStmt, 0);
    if( rc!=SQLITE_OK ){
        return rc;
    }

    sqlite3_bind_text(pStmt, 1, "perl", -1, SQLITE_STATIC);
    sqlite3_bind_blob(pStmt, 2, &p, sizeof(p), SQLITE_STATIC);
    sqlite3_step(pStmt);

    return sqlite3_finalize(pStmt);
}

/* end */
