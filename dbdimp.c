#define PERL_NO_GET_CONTEXT

#include "SQLiteXS.h"

DBISTATE_DECLARE;

#define SvPV_nolen_undef_ok(x) (SvOK(x) ? SvPV_nolen(x) : "undef")

#define sqlite_error(h,xxh,rc,what) _sqlite_error(aTHX_ __FILE__, __LINE__, h, xxh, rc, what)

/* XXX: is there any good way to use pTHX_/aTHX_ here like above? */
#if defined(__GNUC__) && (__GNUC__ > 2)
#  define sqlite_trace(h,xxh,level,fmt...) _sqlite_tracef(__FILE__, __LINE__, h, xxh, level, fmt)
#else
#  define sqlite_trace _sqlite_tracef_noline
#endif

void
sqlite_init(dbistate_t *dbistate)
{
    dTHX;
    DBISTATE_INIT; /* Initialize the DBI macros  */
}

static void
_sqlite_error(pTHX_ char *file, int line, SV *h, imp_xxh_t *imp_xxh, int rc, char *what)
{
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

static void
_sqlite_tracef(char *file, int line, SV *h, imp_xxh_t *imp_xxh, int level, const char *fmt, ...)
{
    dTHX;

    if ( DBIc_TRACE_LEVEL(imp_xxh) >= level ) {
        va_list ap;
        const char* format = form("sqlite trace: %s at %s line %d\n", fmt, file, line);
        va_start(ap, fmt);
        PerlIO_vprintf(DBIc_LOGPIO(imp_xxh), format, ap);
        va_end(ap);
    }
}

static void
_sqlite_tracef_noline(SV *h, imp_xxh_t *imp_xxh, int level, const char *fmt, ...)
{
    dTHX;

    if ( DBIc_TRACE_LEVEL(imp_xxh) >= level ) {
        va_list ap;
        const char* format = form("sqlite trace: %s\n", fmt);
        va_start(ap, fmt);
        PerlIO_vprintf(DBIc_LOGPIO(imp_xxh), format, ap);
        va_end(ap);
    }
}

int
sqlite_db_login(SV *dbh, imp_dbh_t *imp_dbh, char *dbname, char *user, char *pass)
{
    dTHX;
    int retval;
    char *errmsg = NULL;

    if ( DBIc_TRACE_LEVEL(imp_dbh) >= 3 ) {
        PerlIO_printf(DBILOGFP, "    login '%s' (version %s)\n",
            dbname, sqlite3_version);
    }

    if ((retval = sqlite3_open(dbname, &(imp_dbh->db))) != SQLITE_OK ) {
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, retval, (char*)sqlite3_errmsg(imp_dbh->db));
        return FALSE; /* -> undef in lib/DBD/SQLite.pm */
    }
    DBIc_IMPSET_on(imp_dbh);

    imp_dbh->in_tran             = FALSE;
    imp_dbh->unicode             = FALSE;
    imp_dbh->functions           = newAV();
    imp_dbh->aggregates          = newAV();
    imp_dbh->timeout             = SQL_TIMEOUT;
    imp_dbh->handle_binary_nulls = FALSE;

    sqlite3_busy_timeout(imp_dbh->db, SQL_TIMEOUT);

    if ((retval = sqlite3_exec(imp_dbh->db, "PRAGMA empty_result_callbacks = ON",
        NULL, NULL, &errmsg))
        != SQLITE_OK)
    {
        /*  warn("failed to set pragma: %s\n", errmsg); */
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, retval, errmsg);
        return FALSE; /* -> undef in lib/DBD/SQLite.pm */
    }

    if ((retval = sqlite3_exec(imp_dbh->db, "PRAGMA show_datatypes = ON",
        NULL, NULL, &errmsg))
        != SQLITE_OK)
    {
        /*  warn("failed to set pragma: %s\n", errmsg); */
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, retval, errmsg);
        return FALSE; /* -> undef in lib/DBD/SQLite.pm */
    }

    DBIc_ACTIVE_on(imp_dbh);

/*
    if ( DBIc_WARN(imp_dbh) ) {
        warn("DBIc_WARN is on");
    }
    else {
        warn("DBIc_WARN if off");
    }
    if ( DBIc_is(imp_dbh, DBIcf_PrintWarn) ) {
        warn("DBIcf_PrintWarn is on");
    }
*/

    return TRUE;
}

int
sqlite3_db_busy_timeout (pTHX_ SV *dbh, int timeout )
{
  D_imp_dbh(dbh);
  if (timeout) {
    imp_dbh->timeout = timeout;
    sqlite3_busy_timeout(imp_dbh->db, timeout);
  }
  return imp_dbh->timeout;
}

int
sqlite_db_disconnect (SV *dbh, imp_dbh_t *imp_dbh)
{
    dTHX;
    sqlite3_stmt *pStmt;
    DBIc_ACTIVE_off(imp_dbh);

    if (DBIc_is(imp_dbh, DBIcf_AutoCommit) == FALSE) {
        sqlite_db_rollback(dbh, imp_dbh);
    }

    while ( (pStmt = sqlite3_next_stmt(imp_dbh->db, 0))!=0 ) {
        sqlite3_finalize(pStmt);
    }

    if (sqlite3_close(imp_dbh->db) == SQLITE_BUSY) {
        /* active statements! */
        warn("closing dbh with active statement handles");
    }
    imp_dbh->db = NULL;

    av_undef(imp_dbh->functions);
    SvREFCNT_dec(imp_dbh->functions);
    imp_dbh->functions = (AV *)NULL;

    av_undef(imp_dbh->aggregates);
    SvREFCNT_dec(imp_dbh->aggregates);
    imp_dbh->aggregates = (AV *)NULL;

    return TRUE;
}

void
sqlite_db_destroy (SV *dbh, imp_dbh_t *imp_dbh)
{
    dTHX;
    if (DBIc_ACTIVE(imp_dbh)) {
        /* warn("DBIc_ACTIVE is on"); */
        sqlite_db_disconnect(dbh, imp_dbh);
/*
    } else {
        warn("DBIc_ACTIVE is off");
*/
    }
    DBIc_IMPSET_off(imp_dbh);
}

int
sqlite_db_rollback(SV *dbh, imp_dbh_t *imp_dbh)
{
    dTHX;
    int retval;
    char *errmsg;

    if (imp_dbh->in_tran) {
        sqlite_trace(dbh, (imp_xxh_t*)imp_dbh, 2, "ROLLBACK TRAN");
        if ((retval = sqlite3_exec(imp_dbh->db, "ROLLBACK TRANSACTION",
            NULL, NULL, &errmsg))
            != SQLITE_OK)
        {
            sqlite_error(dbh, (imp_xxh_t*)imp_dbh, retval, errmsg);
            return FALSE; /* -> &sv_no in SQLite.xsi */
        }
        imp_dbh->in_tran = FALSE;
    }

    return TRUE;
}

int
sqlite_db_commit(SV *dbh, imp_dbh_t *imp_dbh)
{
    dTHX;
    int retval;
    char *errmsg;

    if (DBIc_is(imp_dbh, DBIcf_AutoCommit)) {
	/* We don't need to warn, because the DBI layer will do it for us */
        return TRUE;
    }

    if (imp_dbh->in_tran) {
        sqlite_trace(dbh, (imp_xxh_t*)imp_dbh, 2, "COMMIT TRAN");
        if ((retval = sqlite3_exec(imp_dbh->db, "COMMIT TRANSACTION",
            NULL, NULL, &errmsg))
            != SQLITE_OK)
        {
            sqlite_error(dbh, (imp_xxh_t*)imp_dbh, retval, errmsg);
            return FALSE; /* -> &sv_no in SQLite.xsi */
        }
        imp_dbh->in_tran = FALSE;
    }
    return TRUE;
}

int
sqlite_discon_all(SV *drh, imp_drh_t *imp_drh)
{
    dTHX;
    return FALSE; /* no way to do this */
}

SV *
sqlite_db_last_insert_id(SV *dbh, imp_dbh_t *imp_dbh, SV *catalog, SV *schema, SV *table, SV *field, SV *attr)
{
    dTHX;
    return newSViv(sqlite3_last_insert_rowid(imp_dbh->db));
}

int
sqlite_st_prepare (SV *sth, imp_sth_t *imp_sth,
                char *statement, SV *attribs)
{
    dTHX;
    D_imp_dbh_from_sth;
    const char *extra;
    int retval = 0;

    if (!DBIc_ACTIVE(imp_dbh)) {
      sqlite_error(sth, (imp_xxh_t*)imp_sth, -2, "attempt to prepare on inactive database handle");
      return FALSE; /* -> undef in lib/DBD/SQLite.pm */
    }

    if (*statement == '\0') {
      sqlite_error(sth, (imp_xxh_t*)imp_sth, -2, "attempt to prepare empty statement");
      return FALSE; /* -> undef in lib/DBD/SQLite.pm */
    }

    sqlite_trace(sth, (imp_xxh_t*)imp_sth, 2, "prepare statement: %s", statement);
    imp_sth->nrow      = -1;
    imp_sth->retval    = SQLITE_OK;
    imp_sth->params    = newAV();
    imp_sth->col_types = newAV();

    if ((retval = sqlite3_prepare_v2(imp_dbh->db, statement, -1, &(imp_sth->stmt), &extra))
        != SQLITE_OK)
    {
        if (imp_sth->stmt) {
            sqlite3_finalize(imp_sth->stmt);
        }
        sqlite_error(sth, (imp_xxh_t*)imp_sth, retval, (char*)sqlite3_errmsg(imp_dbh->db));
        return FALSE; /* -> undef in lib/DBD/SQLite.pm */
    }

    /* store the query for later re-use if required */
    /* but only when the query is properly prepared */
    imp_sth->statement = savepv(statement);

    DBIc_NUM_PARAMS(imp_sth) = sqlite3_bind_parameter_count(imp_sth->stmt);
    DBIc_NUM_FIELDS(imp_sth) = sqlite3_column_count(imp_sth->stmt);
    DBIc_IMPSET_on(imp_sth);

    return TRUE;
}

void
sqlite_st_reset (pTHX_ SV *sth)
{
    D_imp_sth(sth);
    if (DBIc_IMPSET(imp_sth))
        sqlite3_reset(imp_sth->stmt);
}

int
sqlite_st_execute (SV *sth, imp_sth_t *imp_sth)
{
    dTHX;
    D_imp_dbh_from_sth;
    char *errmsg;
    int num_params = DBIc_NUM_PARAMS(imp_sth);
    int i;
    int retval = 0;

    sqlite_trace(sth, (imp_xxh_t*)imp_sth, 3, "execute");

    /* warn("execute\n"); */

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(sth, (imp_xxh_t*)imp_sth, -2, "attempt to execute on inactive database handle");
        return -2; /* -> undef in SQLite.xsi */
    }

    if (DBIc_ACTIVE(imp_sth)) {
         sqlite_trace(sth, (imp_xxh_t*)imp_sth, 3, "execute still active, reset");
         if ((imp_sth->retval = sqlite3_reset(imp_sth->stmt)) != SQLITE_OK) {
             char *errmsg = (char*)sqlite3_errmsg(imp_dbh->db);
             sqlite_error(sth, (imp_xxh_t*)imp_sth, imp_sth->retval, errmsg);
             return -2; /* -> undef in SQLite.xsi */
         }
    }

    for (i = 0; i < num_params; i++) {
        SV *value = av_shift(imp_sth->params);
        SV *sql_type_sv = av_shift(imp_sth->params);
        int sql_type = SvIV(sql_type_sv);

        sqlite_trace(sth, (imp_xxh_t*)imp_sth, 4, "params left in 0x%p: %d", imp_sth->params, 1+av_len(imp_sth->params));
        sqlite_trace(sth, (imp_xxh_t*)imp_sth, 4, "bind %d type %d as %s", i, sql_type, SvPV_nolen_undef_ok(value));
        
        if (!SvOK(value)) {
            sqlite_trace(sth, (imp_xxh_t*)imp_sth, 5, "binding null");
            retval = sqlite3_bind_null(imp_sth->stmt, i+1);
        }
        else if (sql_type >= SQL_NUMERIC && sql_type <= SQL_SMALLINT) {
#if defined(USE_64_BIT_INT)
            retval = sqlite3_bind_int64(imp_sth->stmt, i+1, SvIV(value));
#else
            retval = sqlite3_bind_int(imp_sth->stmt, i+1, SvIV(value));
#endif
        }
        else if (sql_type >= SQL_FLOAT && sql_type <= SQL_DOUBLE) {
            retval = sqlite3_bind_double(imp_sth->stmt, i+1, SvNV(value));
        }
        else if (sql_type == SQL_BLOB) {
            STRLEN len;
            char * data = SvPV(value, len);
            retval = sqlite3_bind_blob(imp_sth->stmt, i+1, data, len, SQLITE_TRANSIENT);
        }
        else {
#if 0
            /* stop guessing until we figure out better way to do this */
            const int numtype = looks_like_number(value);
            if ((numtype & (IS_NUMBER_IN_UV|IS_NUMBER_NOT_INT)) == IS_NUMBER_IN_UV) {
#if defined(USE_64_BIT_INT)
                retval = sqlite3_bind_int64(imp_sth->stmt, i+1, SvIV(value));
#else
                retval = sqlite3_bind_int(imp_sth->stmt, i+1, SvIV(value));
#endif
            }
            else if ((numtype & (IS_NUMBER_NOT_INT|IS_NUMBER_INFINITY|IS_NUMBER_NAN)) == IS_NUMBER_NOT_INT) {
                retval = sqlite3_bind_double(imp_sth->stmt, i+1, SvNV(value));
            }
            else {
#endif
                STRLEN len;
                char *data;
                if (imp_dbh->unicode) {
                    sv_utf8_upgrade(value);
                }
                data = SvPV(value, len);
                retval = sqlite3_bind_text(imp_sth->stmt, i+1, data, len, SQLITE_TRANSIENT);
#if 0
            }
#endif
        }

        if (value) {
            SvREFCNT_dec(value);
        }
        SvREFCNT_dec(sql_type_sv);
        if (retval != SQLITE_OK) {
            sqlite_error(sth, (imp_xxh_t*)imp_sth, retval, (char*)sqlite3_errmsg(imp_dbh->db));
            return -4; /* -> undef in SQLite.xsi */
        }
    }

    if ( (!DBIc_is(imp_dbh, DBIcf_AutoCommit)) && (!imp_dbh->in_tran) ) {
        sqlite_trace(sth, (imp_xxh_t*)imp_sth, 2, "BEGIN TRAN");
        if ((retval = sqlite3_exec(imp_dbh->db, "BEGIN TRANSACTION",
            NULL, NULL, &errmsg))
            != SQLITE_OK)
        {
            sqlite_error(sth, (imp_xxh_t*)imp_sth, retval, errmsg);
            return -2; /* -> undef in SQLite.xsi */
        }
        imp_dbh->in_tran = TRUE;
    }

    imp_sth->nrow = 0;

    sqlite_trace(sth, (imp_xxh_t*)imp_sth, 3, "Execute returned %d cols\n", DBIc_NUM_FIELDS(imp_sth));
    if (DBIc_NUM_FIELDS(imp_sth) == 0) {
        while ((imp_sth->retval = sqlite3_step(imp_sth->stmt)) != SQLITE_DONE) {
            if (imp_sth->retval == SQLITE_ROW) {
                continue;
            }
            sqlite3_reset(imp_sth->stmt);
            sqlite_error(sth, (imp_xxh_t*)imp_sth, imp_sth->retval, (char*)sqlite3_errmsg(imp_dbh->db));
            return -5; /* -> undef in SQLite.xsi */
        }
        /* warn("Finalize\n"); */
        sqlite3_reset(imp_sth->stmt);
        imp_sth->nrow = sqlite3_changes(imp_dbh->db);
        /* DBIc_ACTIVE_on(imp_sth); */
        /* warn("Total changes: %d\n", sqlite3_total_changes(imp_dbh->db)); */
        /* warn("Nrow: %d\n", imp_sth->nrow); */
        return imp_sth->nrow;
    }

    imp_sth->retval = sqlite3_step(imp_sth->stmt);
    switch (imp_sth->retval) {
        case SQLITE_ROW:
        case SQLITE_DONE: DBIc_ACTIVE_on(imp_sth);
                          sqlite_trace(sth, (imp_xxh_t*)imp_sth, 5, "exec ok - %d rows, %d cols\n", imp_sth->nrow, DBIc_NUM_FIELDS(imp_sth));
                          return 0; /* -> '0E0' in SQLite.xsi */
        default:          sqlite3_reset(imp_sth->stmt);
                          imp_sth->stmt = NULL;
                          sqlite_error(sth, (imp_xxh_t*)imp_sth, imp_sth->retval, (char*)sqlite3_errmsg(imp_dbh->db));
                          return -6; /* -> undef in SQLite.xsi */
    }
}

int
sqlite_st_rows (SV *sth, imp_sth_t *imp_sth)
{
    return imp_sth->nrow;
}

/* bind parameter
 * NB: We store the params instead of bind immediately because
 *     we might need to re-create the imp_sth->stmt (see top of execute() function)
 *     and so we can't lose these params
 */
int
sqlite_bind_ph (SV *sth, imp_sth_t *imp_sth,
                SV *param, SV *value, IV sql_type, SV *attribs,
                                int is_inout, IV maxlen)
{
    dTHX;
    int pos;
    if (!looks_like_number(param)) {
        STRLEN len;
        char *paramstring;
        paramstring = SvPV(param, len);
        if(paramstring[len] == 0 && strlen(paramstring) == len) {
            pos = sqlite3_bind_parameter_index(imp_sth->stmt, paramstring);
            if (pos==0) {
                char* const errmsg = form("Unknown named parameter: %s", paramstring);
                sqlite_error(sth, (imp_xxh_t*)imp_sth, -2, errmsg);
                return FALSE; /* -> &sv_no in SQLite.xsi */
            }
            pos = 2 * (pos - 1);
        }
        else {
            sqlite_error(sth, (imp_xxh_t*)imp_sth, -2, "<param> could not be coerced to a C string");
            return FALSE; /* -> &sv_no in SQLite.xsi */
        }
    }
    else {
        if (is_inout) {
            sqlite_error(sth, (imp_xxh_t*)imp_sth, -2, "InOut bind params not implemented");
            return FALSE; /* -> &sv_no in SQLite.xsi */
        }
    }
    pos = 2 * (SvIV(param) - 1);
    sqlite_trace(sth, (imp_xxh_t*)imp_sth, 3, "bind into 0x%p: %d => %s (%d) pos %d\n",
      imp_sth->params, SvIV(param), SvPV_nolen_undef_ok(value), sql_type, pos);
    av_store(imp_sth->params, pos, SvREFCNT_inc(value));
    av_store(imp_sth->params, pos+1, newSViv(sql_type));

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

AV *
sqlite_st_fetch (SV *sth, imp_sth_t *imp_sth)
{
    dTHX;

    AV *av;
    D_imp_dbh_from_sth;
    int numFields = DBIc_NUM_FIELDS(imp_sth);
    int chopBlanks = DBIc_is(imp_sth, DBIcf_ChopBlanks);
    int i;

    sqlite_trace(sth, (imp_xxh_t*)imp_sth, 6, "numFields == %d, nrow == %d\n", numFields, imp_sth->nrow);

    if (!DBIc_ACTIVE(imp_sth)) {
        return Nullav;
    }

    if (imp_sth->retval == SQLITE_DONE) {
        sqlite_st_finish(sth, imp_sth);
        return Nullav;
    }

    if (imp_sth->retval != SQLITE_ROW) {
        /* error */
        sqlite_st_finish(sth, imp_sth);
        sqlite_error(sth, (imp_xxh_t*)imp_sth, imp_sth->retval, (char*)sqlite3_errmsg(imp_dbh->db));
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
                col_type = SvIV(*sql_type);
            }
        }
        switch(col_type) {
            case SQLITE_INTEGER:
#if defined(USE_64_BIT_INT)
                sv_setiv(AvARRAY(av)[i], sqlite3_column_int64(imp_sth->stmt, i));
#else
                sv_setnv(AvARRAY(av)[i], (double)sqlite3_column_int64(imp_sth->stmt, i));
#endif
                break;
            case SQLITE_FLOAT:
                sv_setnv(AvARRAY(av)[i], sqlite3_column_double(imp_sth->stmt, i));
                break;
            case SQLITE_TEXT:
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
                len = sqlite3_column_bytes(imp_sth->stmt, i);
                sv_setpvn(AvARRAY(av)[i], sqlite3_column_blob(imp_sth->stmt, i), len);
                SvUTF8_off(AvARRAY(av)[i]);
                break;
            default:
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
sqlite_st_finish (SV *sth, imp_sth_t *imp_sth)
{
    return sqlite_st_finish3(sth, imp_sth, 0);
}

int
sqlite_st_finish3 (SV *sth, imp_sth_t *imp_sth, int is_destroy)
{
    dTHX;

    D_imp_dbh_from_sth;

    /* warn("finish statement\n"); */
    if (!DBIc_ACTIVE(imp_sth))
        return 1;

    DBIc_ACTIVE_off(imp_sth);

    av_clear(imp_sth->col_types);

    if (!DBIc_ACTIVE(imp_dbh))  /* no longer connected  */
        return 1;

    if (is_destroy) {
        return TRUE;
    }

    if ((imp_sth->retval = sqlite3_reset(imp_sth->stmt)) != SQLITE_OK) {
        char *errmsg = (char*)sqlite3_errmsg(imp_dbh->db);
        /* warn("finalize failed! %s\n", errmsg); */
        sqlite_error(sth, (imp_xxh_t*)imp_sth, imp_sth->retval, errmsg);
        return FALSE; /* -> &sv_no (or void) in SQLite.xsi */
    }
    
    return TRUE;
}

void
sqlite_st_destroy (SV *sth, imp_sth_t *imp_sth)
{
    dTHX;

    D_imp_dbh_from_sth;
    /* warn("destroy statement: %s\n", imp_sth->statement); */
    DBIc_ACTIVE_off(imp_sth);
    if (DBIc_ACTIVE(imp_dbh)) {
        /* finalize sth when active connection */
        sqlite3_finalize(imp_sth->stmt);
    }
    Safefree(imp_sth->statement);
    SvREFCNT_dec((SV*)imp_sth->params);
    SvREFCNT_dec((SV*)imp_sth->col_types);
    DBIc_IMPSET_off(imp_sth);
}

int
sqlite_st_blob_read (SV *sth, imp_sth_t *imp_sth,
                int field, long offset, long len, SV *destrv, long destoffset)
{
    return 0;
}

int
sqlite_db_STORE_attrib (SV *dbh, imp_dbh_t *imp_dbh, SV *keysv, SV *valuesv)
{
    dTHX;
    char *key = SvPV_nolen(keysv);
    char *errmsg;
    int retval;

    if (strEQ(key, "AutoCommit")) {
        if (SvTRUE(valuesv)) {
            /* commit tran? */
            if ( (!DBIc_is(imp_dbh, DBIcf_AutoCommit)) && (imp_dbh->in_tran) ) {
                sqlite_trace(dbh, (imp_xxh_t*)imp_dbh, 2, "COMMIT TRAN");
                if ((retval = sqlite3_exec(imp_dbh->db, "COMMIT TRANSACTION",
                    NULL, NULL, &errmsg))
                    != SQLITE_OK)
                {
                    sqlite_error(dbh, (imp_xxh_t*)imp_dbh, retval, errmsg);
                    return TRUE; /* XXX: is this correct? */
                }
                imp_dbh->in_tran = FALSE;
            }
        }
        DBIc_set(imp_dbh, DBIcf_AutoCommit, SvTRUE(valuesv));
        return TRUE;
    }
    if (strEQ(key, "unicode")) {
#if (PERL_REVISION <= 5) && ((PERL_VERSION < 8) || (PERL_VERSION == 8 && PERL_SUBVERSION < 5))
      sqlite_trace(dbh, (imp_xxh_t*)imp_dbh, 2, "Unicode support is disabled for this version of perl.");
      imp_dbh->unicode = 0;
#else
      imp_dbh->unicode = !(! SvTRUE(valuesv));
#endif
      return TRUE;
    }
    return FALSE;
}

SV *
sqlite_db_FETCH_attrib (SV *dbh, imp_dbh_t *imp_dbh, SV *keysv)
{
    dTHX;
    char *key = SvPV_nolen(keysv);

    if (strEQ(key, "sqlite_version")) {
        return newSVpv(sqlite3_version,0);
    }
   if (strEQ(key, "unicode")) {
#if (PERL_REVISION <= 5) && ((PERL_VERSION < 8) || (PERL_VERSION == 8 && PERL_SUBVERSION < 5))
      sqlite_trace(dbh, (imp_xxh_t*)imp_dbh, 2, "Unicode support is disabled for this version of perl.");
     return newSViv(0);
#else
     return newSViv(imp_dbh->unicode ? 1 : 0);
#endif
   }

    return NULL;
}

int
sqlite_st_STORE_attrib (SV *sth, imp_sth_t *imp_sth, SV *keysv, SV *valuesv)
{
    dTHX;
    /* char *key = SvPV_nolen(keysv); */
    return FALSE;
}

static int
type_to_odbc_type (int type)
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

SV *
sqlite_st_FETCH_attrib (SV *sth, imp_sth_t *imp_sth, SV *keysv)
{
    dTHX;
    D_imp_dbh_from_sth;
    char *key = SvPV_nolen(keysv);
    SV *retsv = NULL;
    int i,n;

    if (!DBIc_ACTIVE(imp_sth)) {
        return NULL;
    }
    
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
                av_store(av, n, newSVpv(fieldname, 0));
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
            type = type_to_odbc_type(type);
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
            int retval = sqlite3_table_column_metadata(imp_dbh->db, database, tablename, fieldname, &datatype, &collseq, &notnull, &primary, &autoinc);
            if (retval != SQLITE_OK) {
                char *errmsg = (char*)sqlite3_errmsg(imp_dbh->db);
                sqlite_error(sth, (imp_xxh_t*)imp_sth, retval, errmsg);
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

    return retsv;
}

static void
sqlite_db_set_result(pTHX_ sqlite3_context *context, SV *result, int is_error )
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
        s = SvPV(result, len);
        sqlite3_result_text( context, s, len, SQLITE_TRANSIENT );
    }
    else if ( SvIOK(result) ) {
        sqlite3_result_int( context, SvIV(result));
    } else if ( !is_error && SvIOK(result) ) {
        sqlite3_result_double( context, SvNV(result));
    } else {
        s = SvPV(result, len);
        sqlite3_result_text( context, s, len, SQLITE_TRANSIENT );
    }
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

        /* warn("func dispatch type: %d, value: %s\n", type, sqlite3_value_text(value[i])); */
        switch(type) {
            case SQLITE_INTEGER:
                arg = sv_2mortal(newSViv(sqlite3_value_int(value[i])));
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
        sqlite_db_set_result(aTHX_ context, ERRSV, 1);
        POPs;
    } else if ( count != 1 ) {
        SV *err = sv_2mortal(newSVpvf( "function should return 1 argument, got %d",
                                       count ));

        sqlite_db_set_result(aTHX_ context, err, 1);
        /* Clear the stack */
        for ( i=0; i < count; i++ ) {
            POPs;
        }
    } else {
        sqlite_db_set_result(aTHX_ context, POPs, 0 );
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
sqlite3_db_create_function(pTHX_ SV *dbh, const char *name, int argc, SV *func )
{
    D_imp_dbh(dbh);
    int retval;

    /* Copy the function reference */
    SV *func_sv = newSVsv(func);
    av_push( imp_dbh->functions, func_sv );

    /* warn("create_function %s with %d args\n", name, argc); */
    retval = sqlite3_create_function( imp_dbh->db, name, argc, SQLITE_UTF8,
                                  func_sv,
                                  imp_dbh->unicode ? sqlite_db_func_dispatcher_unicode
                                                   : sqlite_db_func_dispatcher_no_unicode, 
                                  NULL, NULL );
    if ( retval != SQLITE_OK )
    {
        char* const errmsg = form("sqlite_create_function failed with error %s", sqlite3_errmsg(imp_dbh->db));
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, retval, errmsg);
        return FALSE;
    }
    return TRUE;
}

int
sqlite3_db_enable_load_extension(pTHX_ SV *dbh, int onoff )
{
    D_imp_dbh(dbh);
    int retval;
    
    retval = sqlite3_enable_load_extension( imp_dbh->db, onoff );
    if ( retval != SQLITE_OK )
    {
        char* const errmsg = form("sqlite_enable_load_extension failed with error %s", sqlite3_errmsg(imp_dbh->db));
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, retval, errmsg);
        return FALSE;
    }
    return TRUE;
}

static void
sqlite_db_aggr_new_dispatcher(pTHX_ sqlite3_context *context, aggrInfo *aggr_info )
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
        aggr_info->err =  newSVpvf ("error during aggregator's new(): %s",
                                    SvPV_nolen (ERRSV));
        POPs;
    } else if ( count != 1 ) {
        int i;
        
        aggr_info->err = newSVpvf( "new() should return one value, got %d", 
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
sqlite_db_aggr_step_dispatcher (sqlite3_context *context,
                                int argc, sqlite3_value **value)
{
    dTHX;
    dSP;
    int i;
    aggrInfo *aggr;

    aggr = sqlite3_aggregate_context (context, sizeof (aggrInfo));
    if ( !aggr )
        return;

    ENTER;
    SAVETMPS;

    /* initialize on first step */
    if ( !aggr->inited ) {
        sqlite_db_aggr_new_dispatcher(aTHX_ context, aggr );
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
      aggr->err = newSVpvf( "error during aggregator's step(): %s",
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

    aggr = sqlite3_aggregate_context (context, sizeof (aggrInfo));

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
            aggr->err = newSVpvf ("error during aggregator's finalize(): %s",
                                  SvPV_nolen(ERRSV) ) ;
            POPs;
        } else if ( count != 1 ) {
            int i;
            aggr->err = newSVpvf( "finalize() should return 1 value, got %d",
                                  count );
            /* Clear the stack */
            for ( i=0; i<count; i++ ) {
                POPs;
            }
        } else {
            sqlite_db_set_result(aTHX_ context, POPs, 0 );
        }
        PUTBACK;
    }
    
    if ( aggr->err ) {
        warn( "DBD::SQLite: error in aggregator cannot be reported to SQLite: %s",
            SvPV_nolen( aggr->err ) );

        /* sqlite_db_set_result(aTHX_ context, aggr->err, 1 ); */
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
sqlite3_db_create_aggregate(pTHX_ SV *dbh, const char *name, int argc, SV *aggr_pkg )
{
    D_imp_dbh(dbh);
    int retval;

    /* Copy the aggregate reference */
    SV *aggr_pkg_copy = newSVsv(aggr_pkg);
    av_push( imp_dbh->aggregates, aggr_pkg_copy );

    retval = sqlite3_create_function( imp_dbh->db, name, argc, SQLITE_UTF8,
                                  aggr_pkg_copy,
                                  NULL,
                                  sqlite_db_aggr_step_dispatcher, 
                                  sqlite_db_aggr_finalize_dispatcher
                                );

    if ( retval != SQLITE_OK )
    {
        char* const errmsg = form("sqlite_create_aggregate failed with error %s", sqlite3_errmsg(imp_dbh->db));
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, retval, errmsg);
        return FALSE;
    }
    return TRUE;
}


int
sqlite_db_collation_dispatcher(
  void *func, int len1, const void *string1,
              int len2, const void *string2)
{
    dTHX;
    dSP;
    int cmp = 0;
    int n_retval, i;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal ( newSVpvn( string1, len1) ) );
    XPUSHs( sv_2mortal ( newSVpvn( string2, len2) ) );
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
sqlite_db_collation_dispatcher_utf8(
  void *func, int len1, const void *string1,
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
    sv1 = newSVpvn( string1, len1);
    SvUTF8_on(sv1);
    sv2 = newSVpvn( string2, len2);
    SvUTF8_on(sv2);
    XPUSHs( sv_2mortal ( sv1 ) );
    XPUSHs( sv_2mortal ( sv2 ) );
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
sqlite3_db_create_collation(pTHX_ SV *dbh, const char *name, SV *func )
{
    D_imp_dbh(dbh);
    int rv, rv2;
    void *aa = "aa";
    void *zz = "zz";

    SV *func_sv = newSVsv(func);

    /* Check that this is a proper collation function */
    rv = sqlite_db_collation_dispatcher(func_sv, 2, aa, 2, aa);
    if (rv != 0) {
        sqlite_trace(dbh, (imp_xxh_t*)imp_dbh, 2, "improper collation function: %s(aa, aa) returns %d!", name, rv);
    }
    rv  = sqlite_db_collation_dispatcher(func_sv, 2, aa, 2, zz);
    rv2 = sqlite_db_collation_dispatcher(func_sv, 2, zz, 2, aa);
    if (rv2 != (rv * -1)) {
        sqlite_trace(dbh, (imp_xxh_t*)imp_dbh, 2, "improper collation function: '%s' is not symmetric", name);
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

    if ( rv != SQLITE_OK )
    {
        char* const errmsg = form("sqlite_create_collation failed with error %s", sqlite3_errmsg(imp_dbh->db));
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, rv, errmsg);
        return FALSE;
    }
    return TRUE;
}


void
sqlite3_db_collation_needed_dispatcher (
    void *info,
    sqlite3* db, /* unused, because we need the Perl dbh */
    int eTextRep,
    const char* collation_name
)
{
    dTHX;
    dSP;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal ( newSVsv( ((collationNeededInfo*)info)->dbh ) ) );
    XPUSHs( sv_2mortal ( newSVpv( collation_name, 0) ) );
    PUTBACK;

    call_sv( ((collationNeededInfo*)info)->callback, G_VOID );
    SPAGAIN;

    PUTBACK;
    FREETMPS;
    LEAVE;
}
                                           



void
sqlite3_db_collation_needed(pTHX_ SV *dbh, SV *callback )
{
    D_imp_dbh(dbh);

    SV *callback_sv = newSVsv(callback);
    collationNeededInfo* info = sqlite3_malloc(sizeof(collationNeededInfo));
    /* TODO: this struct should probably be freed at some point, not sure
       how and when */
      
    /* Copy the handler ref so that it can be deallocated at disconnect */
    av_push( imp_dbh->functions, callback_sv );

    /* the dispatcher will need both the callback and dbh, so build a struct */
    info->callback = callback_sv;
    info->dbh      = dbh;

    /* Register the func within sqlite3 */
    (void) sqlite3_collation_needed( imp_dbh->db, 
                                     (void*) info,
                                     sqlite3_db_collation_needed_dispatcher );

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
sqlite3_db_progress_handler(pTHX_ SV *dbh, int n_opcodes, SV *handler )
{
    D_imp_dbh(dbh);

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
sqlite3_db_commit_hook( pTHX_ SV *dbh, SV *hook )
{
    D_imp_dbh(dbh);
    void *retval;

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
sqlite3_db_rollback_hook( pTHX_ SV *dbh, SV *hook )
{
    D_imp_dbh(dbh);
    void *retval;

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

    XPUSHs( sv_2mortal ( newSViv ( op          ) ) );
    XPUSHs( sv_2mortal ( newSVpv ( database, 0 ) ) );
    XPUSHs( sv_2mortal ( newSVpv ( table,    0 ) ) );
    XPUSHs( sv_2mortal ( newSViv ( rowid       ) ) );
    PUTBACK;

    call_sv( callback, G_VOID );
    SPAGAIN;

    PUTBACK;
    FREETMPS;
    LEAVE;
}


SV*
sqlite3_db_update_hook( pTHX_ SV *dbh, SV *hook )
{
    D_imp_dbh(dbh);
    void *retval;

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
    XPUSHs( sv_2mortal ( newSVpv ( details_1, 0 ) ) );
    XPUSHs( sv_2mortal ( newSVpv ( details_2, 0 ) ) );
    XPUSHs( sv_2mortal ( newSVpv ( details_3, 0 ) ) );
    XPUSHs( sv_2mortal ( newSVpv ( details_4, 0 ) ) );
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
sqlite3_db_set_authorizer( pTHX_ SV *dbh, SV *authorizer )
{
    D_imp_dbh(dbh);
    int retval;

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





/* Accesses the SQLite Online Backup API, and fills the currently loaded
 * database from the passed filename.
 * Usual usage of this would be when you're operating on the :memory:
 * special database connection and want to copy it in from a real db.
 */
int
sqlite_db_backup_from_file(pTHX_ SV *dbh, char *filename)
{
    int rc;
    sqlite3 *pFrom;
    sqlite3_backup *pBackup;

    D_imp_dbh(dbh);

    rc = sqlite3_open(filename, &pFrom);
    if ( rc != SQLITE_OK )
    {
        char* const errmsg = form("sqlite_backup_from_file failed with error %s", sqlite3_errmsg(imp_dbh->db));
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, rc, errmsg);
        return FALSE;
    }

    pBackup = sqlite3_backup_init(imp_dbh->db, "main", pFrom, "main");
    if (pBackup) {
        (void)sqlite3_backup_step(pBackup, -1);
        (void)sqlite3_backup_finish(pBackup);
    }
    rc = sqlite3_errcode(imp_dbh->db);
    (void)sqlite3_close(pFrom);

    if ( rc != SQLITE_OK )
    {
        char* const errmsg = form("sqlite_backup_from_file failed with error %s", sqlite3_errmsg(imp_dbh->db));
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, rc, errmsg);
        return FALSE;
    }

    return TRUE;
}

/* Accesses the SQLite Online Backup API, and copies the currently loaded
 * database into the passed filename.
 * Usual usage of this would be when you're operating on the :memory:
 * special database connection, and want to back it up to an on-disk file.
 */
int
sqlite_db_backup_to_file(pTHX_ SV *dbh, char *filename)
{
    int rc;
    sqlite3 *pTo;
    sqlite3_backup *pBackup;

    D_imp_dbh(dbh);

    rc = sqlite3_open(filename, &pTo);
    if ( rc != SQLITE_OK )
    {
        char* const errmsg = form("sqlite_backup_to_file failed with error %s", sqlite3_errmsg(imp_dbh->db));
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, rc, errmsg);
        return FALSE;
    }

    pBackup = sqlite3_backup_init(pTo, "main", imp_dbh->db, "main");
    if (pBackup) {
        (void)sqlite3_backup_step(pBackup, -1);
        (void)sqlite3_backup_finish(pBackup);
    }
    rc = sqlite3_errcode(pTo);
    (void)sqlite3_close(pTo);

    if ( rc != SQLITE_OK )
    {
        char* const errmsg = form("sqlite_backup_to_file failed with error %s", sqlite3_errmsg(imp_dbh->db));
        sqlite_error(dbh, (imp_xxh_t*)imp_dbh, rc, errmsg);
        return FALSE;
    }

    return TRUE;
}

/* end */
