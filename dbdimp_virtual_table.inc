/*********************************************************************** 
** The set of routines that implement the perl "module" 
** (i.e support for virtual tables written in Perl)
************************************************************************/

typedef struct perl_vtab {
    sqlite3_vtab base;
    SV *perl_vtab_obj;
    HV *functions;
} perl_vtab;

typedef struct perl_vtab_cursor {
    sqlite3_vtab_cursor base;
    SV *perl_cursor_obj;
} perl_vtab_cursor;

typedef struct perl_vtab_init {
    SV *dbh;
    const char *perl_class;
} perl_vtab_init;



/* auxiliary routine for generalized method calls. Arg "i" may be unused */
static int _call_perl_vtab_method(sqlite3_vtab *pVTab, 
                                  const char *method, int i) {
    dTHX;
    dSP;
    int count;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(((perl_vtab *) pVTab)->perl_vtab_obj);
    XPUSHs(sv_2mortal(newSViv(i)));
    PUTBACK;
    count = call_method (method, G_VOID);
    SPAGAIN;
    SP -= count;

    PUTBACK;
    FREETMPS;
    LEAVE;

    return SQLITE_OK;
}



static int perl_vt_New(const char *method,
                       sqlite3 *db, void *pAux,
                       int argc, const char *const *argv,
                       sqlite3_vtab **ppVTab, char **pzErr){
    dTHX;
    dSP;
    perl_vtab *vt;
    perl_vtab_init *init_data = (perl_vtab_init *)pAux;
    int count, i;
    int rc = SQLITE_ERROR;
    SV *perl_vtab_obj;
    SV *sql;

    /* allocate a perl_vtab structure */
    vt = (perl_vtab *) sqlite3_malloc(sizeof(*vt));
    if( vt==NULL ) return SQLITE_NOMEM;
    memset(vt, 0, sizeof(*vt));
    vt->functions = newHV();

    ENTER;
    SAVETMPS;

    /* call the ->CREATE/CONNECT() method */
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv(init_data->perl_class, 0)));
    XPUSHs(init_data->dbh);
    for(i = 0; i < argc; i++) {
        XPUSHs(newSVpvn_flags(argv[i], strlen(argv[i]), SVs_TEMP|SVf_UTF8));
    }
    PUTBACK;
    count = call_method (method, G_SCALAR);
    SPAGAIN;

    /* check the return value */
    if ( count != 1 ) {
        *pzErr = sqlite3_mprintf("vtab->%s() should return one value, got %d",
                                 method, count );
        SP -= count; /* Clear the stack */
        goto cleanup;
    }

    /* get the VirtualTable instance */
    perl_vtab_obj = POPs;
    if ( !sv_isobject(perl_vtab_obj) ) {
        *pzErr = sqlite3_mprintf("vtab->%s() should return a blessed reference",
                                 method);
        goto cleanup;
    }

    /* call the ->VTAB_TO_DECLARE() method */
    PUSHMARK(SP);
    XPUSHs(perl_vtab_obj);
    PUTBACK;
    count = call_method ("VTAB_TO_DECLARE", G_SCALAR);
    SPAGAIN;

    /* check the return value */
    if (count != 1 ) {
        *pzErr = sqlite3_mprintf("vtab->VTAB_TO_DECLARE() should return one value, got %d",
                                 count );
        SP -= count; /* Clear the stack */
        goto cleanup;
    }

    /* call sqlite3_declare_vtab with the sql returned from
       method VTAB_TO_DECLARE(), converted to utf8 */
    sql = POPs;
    rc = sqlite3_declare_vtab(db, SvPVutf8_nolen(sql));

 cleanup:
    if (rc == SQLITE_OK) {
        /* record the VirtualTable perl instance within the vtab structure */
        vt->perl_vtab_obj = SvREFCNT_inc(perl_vtab_obj);
        *ppVTab = &vt->base;
    }
    else {
        sqlite3_free(vt);
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return rc;
}


static int perl_vt_Create(sqlite3 *db, void *pAux,
                          int argc, const char *const *argv,
                          sqlite3_vtab **ppVTab, char **pzErr){
    return perl_vt_New("CREATE", db, pAux, argc, argv, ppVTab, pzErr);
}

static int perl_vt_Connect(sqlite3 *db, void *pAux,
                           int argc, const char *const *argv,
                           sqlite3_vtab **ppVTab, char **pzErr){
    return perl_vt_New("CONNECT", db, pAux, argc, argv, ppVTab, pzErr);
}


static int _free_perl_vtab(perl_vtab *pVTab){
    dTHX;

    SvREFCNT_dec(pVTab->perl_vtab_obj);

    /* deallocate coderefs that were declared through FindFunction() */
    hv_undef(pVTab->functions);
    SvREFCNT_dec(pVTab->functions);

    sqlite3_free(pVTab);
    return SQLITE_OK;
}

static int perl_vt_Disconnect(sqlite3_vtab *pVTab){
    _call_perl_vtab_method(pVTab, "DISCONNECT", 0);
    return _free_perl_vtab((perl_vtab *)pVTab);
}

static int perl_vt_Drop(sqlite3_vtab *pVTab){
    _call_perl_vtab_method(pVTab, "DROP", 0);
    return _free_perl_vtab((perl_vtab *)pVTab);
}


static char *
_constraint_op_to_string(unsigned char op) {
    switch (op) {
    case SQLITE_INDEX_CONSTRAINT_EQ:
        return "=";
    case SQLITE_INDEX_CONSTRAINT_GT:
        return ">";
    case SQLITE_INDEX_CONSTRAINT_GE:
        return ">=";
    case SQLITE_INDEX_CONSTRAINT_LT:
        return "<";
    case SQLITE_INDEX_CONSTRAINT_LE:
        return "<=";
    case SQLITE_INDEX_CONSTRAINT_MATCH:
        return "MATCH";
#if SQLITE_VERSION_NUMBER >= 3010000
    case SQLITE_INDEX_CONSTRAINT_LIKE:
        return "LIKE";
    case SQLITE_INDEX_CONSTRAINT_GLOB:
        return "GLOB";
    case SQLITE_INDEX_CONSTRAINT_REGEXP:
        return "REGEXP";
#endif
#if SQLITE_VERSION_NUMBER >= 3021000
    case SQLITE_INDEX_CONSTRAINT_NE:
        return "NE";
    case SQLITE_INDEX_CONSTRAINT_ISNOT:
        return "ISNOT";
    case SQLITE_INDEX_CONSTRAINT_ISNOTNULL:
        return "ISNOTNULL";
    case SQLITE_INDEX_CONSTRAINT_ISNULL:
        return "ISNULL";
    case SQLITE_INDEX_CONSTRAINT_IS:
        return "IS";
#endif
    default:
        return "unknown";
    }
}


static int perl_vt_BestIndex(sqlite3_vtab *pVTab, sqlite3_index_info *pIdxInfo){
    dTHX;
    dSP;
    int i, count;
    int argvIndex;
    AV *constraints;
    AV *order_by;
    SV *hashref;
    SV **val;
    HV *hv;
    struct sqlite3_index_constraint_usage *pConsUsage;

    ENTER;
    SAVETMPS;

    /* build the "where_constraints" datastructure */
    constraints = newAV();
    for (i=0; i<pIdxInfo->nConstraint; i++){
        struct sqlite3_index_constraint const *pCons = &pIdxInfo->aConstraint[i];
        HV *constraint = newHV();
        char *op_str   = _constraint_op_to_string(pCons->op);
        hv_stores(constraint, "col",    newSViv(pCons->iColumn));
        hv_stores(constraint, "op",     newSVpv(op_str, 0));
        hv_stores(constraint, "usable", pCons->usable ? &PL_sv_yes : &PL_sv_no);
        av_push(constraints, newRV_noinc((SV*) constraint));
    }

    /* build the "order_by" datastructure */
    order_by = newAV();
    for (i=0; i<pIdxInfo->nOrderBy; i++){
        struct sqlite3_index_orderby const *pOrder = &pIdxInfo->aOrderBy[i];
        HV *order = newHV();
        hv_stores(order, "col",  newSViv(pOrder->iColumn));
        hv_stores(order, "desc", pOrder->desc ? &PL_sv_yes : &PL_sv_no);
        av_push( order_by, newRV_noinc((SV*) order));
    }

    /* call the ->BEST_INDEX() method */
    PUSHMARK(SP);
    XPUSHs( ((perl_vtab *) pVTab)->perl_vtab_obj);
    XPUSHs( sv_2mortal( newRV_noinc((SV*) constraints)));
    XPUSHs( sv_2mortal( newRV_noinc((SV*) order_by)));
    PUTBACK;
    count = call_method ("BEST_INDEX", G_SCALAR);
    SPAGAIN;

    /* get values back from the returned hashref */
    if (count != 1)
        croak("BEST_INDEX() method returned %d vals instead of 1", count);
    hashref = POPs;
    if (!(hashref && SvROK(hashref) && SvTYPE(SvRV(hashref)) == SVt_PVHV))
        croak("BEST_INDEX() method did not return a hashref");
    hv = (HV*)SvRV(hashref);
    val = hv_fetch(hv, "idxNum", 6, FALSE);
    pIdxInfo->idxNum = (val && SvOK(*val)) ? SvIV(*val) : 0;
    val = hv_fetch(hv, "idxStr", 6, FALSE);
    if (val && SvOK(*val)) {
        STRLEN len;
        char *str = SvPVutf8(*val, len);
        pIdxInfo->idxStr = sqlite3_malloc(len+1);
        memcpy(pIdxInfo->idxStr, str, len);
        pIdxInfo->idxStr[len] = 0;
        pIdxInfo->needToFreeIdxStr = 1;
    }
    val = hv_fetch(hv, "orderByConsumed", 15, FALSE);
    pIdxInfo->orderByConsumed = (val && SvTRUE(*val)) ? 1 : 0;
    val = hv_fetch(hv, "estimatedCost", 13, FALSE);
    pIdxInfo->estimatedCost = (val && SvOK(*val)) ? SvNV(*val) : 0;
#if SQLITE_VERSION_NUMBER >= 3008002
    val = hv_fetch(hv, "estimatedRows", 13, FALSE);
    pIdxInfo->estimatedRows = (val && SvOK(*val)) ? SvIV(*val) : 0;
#endif

    /* loop over constraints to get back the "argvIndex" and "omit" keys
       that shoud have been added by the best_index() method call */
    for (i=0; i<pIdxInfo->nConstraint; i++){
        SV **rv = av_fetch(constraints, i, FALSE);
        if (!(rv && SvROK(*rv) && SvTYPE(SvRV(*rv)) == SVt_PVHV))
            croak("the call to BEST_INDEX() has corrupted constraint data");
        hv = (HV*)SvRV(*rv);
        val = hv_fetch(hv, "argvIndex", 9, FALSE);
        argvIndex = (val && SvOK(*val)) ? SvIV(*val) + 1: 0;

        pConsUsage = &pIdxInfo->aConstraintUsage[i];
        pConsUsage->argvIndex = argvIndex;
        val = hv_fetch(hv, "omit", 4, FALSE);
        pConsUsage->omit = (val && SvTRUE(*val)) ? 1 : 0;
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return SQLITE_OK;
}



static int perl_vt_Open(sqlite3_vtab *pVTab, sqlite3_vtab_cursor **ppCursor){
    dTHX;
    dSP;
    int count;
    int rc = SQLITE_ERROR;
    SV *perl_cursor;
    perl_vtab_cursor *cursor;

    ENTER;
    SAVETMPS;

    /* allocate a perl_vtab_cursor structure */
    cursor = (perl_vtab_cursor *) sqlite3_malloc(sizeof(*cursor));
    if( cursor==NULL ) return SQLITE_NOMEM;
    memset(cursor, 0, sizeof(*cursor));

    /* call the ->OPEN() method */
    PUSHMARK(SP);
    XPUSHs( ((perl_vtab *) pVTab)->perl_vtab_obj);
    PUTBACK;
    count = call_method ("OPEN", G_SCALAR);
    SPAGAIN;
    if (count != 1) {
        warn("vtab->OPEN() method returned %d vals instead of 1", count);
        SP -= count;
        goto cleanup;

    }
    perl_cursor = POPs;
    if ( !sv_isobject(perl_cursor) ) {
        warn("vtab->OPEN() method did not return a blessed cursor");
        goto cleanup;
    }

    /* everything went OK */
    rc = SQLITE_OK;

 cleanup:

    if (rc == SQLITE_OK) {
        cursor->perl_cursor_obj = SvREFCNT_inc(perl_cursor);
        *ppCursor = &cursor->base;
    }
    else {
        sqlite3_free(cursor);
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return rc;
}

static int perl_vt_Close(sqlite3_vtab_cursor *pVtabCursor){
    dTHX;
    dSP;
    perl_vtab_cursor *perl_pVTabCursor;

    ENTER;
    SAVETMPS;

    /* Note : there is no explicit call to a CLOSE() method; if
       needed, the Perl class can implement a DESTROY() method */

    perl_pVTabCursor = (perl_vtab_cursor *) pVtabCursor;
    SvREFCNT_dec(perl_pVTabCursor->perl_cursor_obj);
    sqlite3_free(perl_pVTabCursor);

    PUTBACK;
    FREETMPS;
    LEAVE;

    return SQLITE_OK;
}

static int perl_vt_Filter( sqlite3_vtab_cursor *pVtabCursor,
                           int idxNum, const char *idxStr,
                           int argc, sqlite3_value **argv ){
    dTHX;
    dSP;
    dMY_CXT;
    int i, count;
    int is_unicode = MY_CXT.last_dbh_is_unicode;

    ENTER;
    SAVETMPS;

    /* call the FILTER() method with ($idxNum, $idxStr, @args) */
    PUSHMARK(SP);
    XPUSHs(((perl_vtab_cursor *) pVtabCursor)->perl_cursor_obj);
    XPUSHs(sv_2mortal(newSViv(idxNum)));
    XPUSHs(sv_2mortal(newSVpv(idxStr, 0)));
    for(i = 0; i < argc; i++) {
        XPUSHs(stacked_sv_from_sqlite3_value(aTHX_ argv[i], is_unicode));
    }
    PUTBACK;
    count = call_method("FILTER", G_VOID);
    SPAGAIN;
    SP -= count;

    PUTBACK;
    FREETMPS;
    LEAVE;

    return SQLITE_OK;
}


static int perl_vt_Next(sqlite3_vtab_cursor *pVtabCursor){
    dTHX;
    dSP;
    int count;

    ENTER;
    SAVETMPS;

    /* call the next() method */
    PUSHMARK(SP);
    XPUSHs(((perl_vtab_cursor *) pVtabCursor)->perl_cursor_obj);
    PUTBACK;
    count = call_method ("NEXT", G_VOID);
    SPAGAIN;
    SP -= count;

    PUTBACK;
    FREETMPS;
    LEAVE;

    return SQLITE_OK;
}

static int perl_vt_Eof(sqlite3_vtab_cursor *pVtabCursor){
    dTHX;
    dSP;
    int count, eof;

    ENTER;
    SAVETMPS;

    /* call the eof() method */
    PUSHMARK(SP);
    XPUSHs(((perl_vtab_cursor *) pVtabCursor)->perl_cursor_obj);
    PUTBACK;
    count = call_method ("EOF", G_SCALAR);
    SPAGAIN;
    if (count != 1) {
        warn("cursor->EOF() method returned %d vals instead of 1", count);
        SP -= count;
    }
    else {
        SV *sv = POPs;     /* need 2 lines, because this doesn't work :        */
        eof = SvTRUE(sv);  /* eof = SvTRUE(POPs); # I don't understand why :-( */
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return eof;
}


static int perl_vt_Column(sqlite3_vtab_cursor *pVtabCursor,
                          sqlite3_context* context,
                          int col){
    dTHX;
    dSP;
    int count;
    int rc = SQLITE_ERROR;

    ENTER;
    SAVETMPS;

    /* call the column() method */
    PUSHMARK(SP);
    XPUSHs(((perl_vtab_cursor *) pVtabCursor)->perl_cursor_obj);
    XPUSHs(sv_2mortal(newSViv(col)));
    PUTBACK;
    count = call_method ("COLUMN", G_SCALAR);
    SPAGAIN;
    if (count != 1) {
        warn("cursor->COLUMN() method returned %d vals instead of 1", count);
        SP -= count;
        sqlite3_result_error(context, "column error", 12);
    }
    else {
        SV *result = POPs;
        sqlite_set_result(aTHX_ context, result, 0 );
        rc = SQLITE_OK;
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return rc;
}

static int perl_vt_Rowid( sqlite3_vtab_cursor *pVtabCursor,
                          sqlite3_int64 *pRowid ){
    dTHX;
    dSP;
    int count;
    int rc = SQLITE_ERROR;

    ENTER;
    SAVETMPS;

    /* call the rowid() method */
    PUSHMARK(SP);
    XPUSHs(((perl_vtab_cursor *) pVtabCursor)->perl_cursor_obj);
    PUTBACK;
    count = call_method ("ROWID", G_SCALAR);
    SPAGAIN;
    if (count != 1) {
        warn("cursor->ROWID() returned %d vals instead of 1", count);
        SP -= count;
    }
    else {
        *pRowid =POPi;
        rc = SQLITE_OK;
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return rc;
}

static int perl_vt_Update( sqlite3_vtab *pVTab,
                           int argc, sqlite3_value **argv,
                           sqlite3_int64 *pRowid ){
    dTHX;
    dSP;
    dMY_CXT;
    int count, i;
    int is_unicode = MY_CXT.last_dbh_is_unicode;
    int rc = SQLITE_ERROR;
    SV *rowidsv;

    ENTER;
    SAVETMPS;

    /* call the _SQLITE_UPDATE() method */
    PUSHMARK(SP);
    XPUSHs(((perl_vtab *) pVTab)->perl_vtab_obj);
    for(i = 0; i < argc; i++) {
        XPUSHs(stacked_sv_from_sqlite3_value(aTHX_ argv[i], is_unicode));
    }
    PUTBACK;
    count = call_method ("_SQLITE_UPDATE", G_SCALAR);
    SPAGAIN;
    if (count != 1) {
        warn("cursor->_SQLITE_UPDATE() returned %d vals instead of 1", count);
        SP -= count;
    }
    else {
        if (argc > 1 && sqlite3_value_type(argv[0]) == SQLITE_NULL
                      && sqlite3_value_type(argv[1]) == SQLITE_NULL) {
            /* this was an insert without any given rowid, so the result of
               the method call must be passed in *pRowid*/
            rowidsv = POPs;
            if (!SvOK(rowidsv))
                *pRowid = 0;
            else if (SvUOK(rowidsv))
                *pRowid = SvUV(rowidsv);
            else if (SvIOK(rowidsv))
                *pRowid = SvIV(rowidsv);
            else
                *pRowid = (sqlite3_int64)SvNV(rowidsv);
        }
        rc = SQLITE_OK;
    }


    PUTBACK;
    FREETMPS;
    LEAVE;

    return rc;
}

static int perl_vt_Begin(sqlite3_vtab *pVTab){
  return _call_perl_vtab_method(pVTab, "BEGIN_TRANSACTION", 0);
}

static int perl_vt_Sync(sqlite3_vtab *pVTab){
  return _call_perl_vtab_method(pVTab, "SYNC_TRANSACTION", 0);
}

static int perl_vt_Commit(sqlite3_vtab *pVTab){
  return _call_perl_vtab_method(pVTab, "COMMIT_TRANSACTION", 0);
}

static int perl_vt_Rollback(sqlite3_vtab *pVTab){
  return _call_perl_vtab_method(pVTab, "ROLLBACK_TRANSACTION", 0);
}

static int perl_vt_FindFunction(sqlite3_vtab *pVTab,
                       int nArg, const char *zName,
                       void (**pxFunc)(sqlite3_context*,int,sqlite3_value**),
                       void **ppArg){
    dTHX;
    dSP;
    dMY_CXT;
    int count;
    int is_overloaded = 0;
    char *func_name   = sqlite3_mprintf("%s\t%d", zName, nArg);
    STRLEN len        = strlen(func_name);
    HV *functions     = ((perl_vtab *) pVTab)->functions;
    SV* coderef       = NULL;
    SV** val;
    SV *result;

    ENTER;
    SAVETMPS;

    /* check if that function was already in cache */
    if (hv_exists(functions, func_name, len)) {
        val = hv_fetch(functions, func_name, len, FALSE);
        if (val && SvOK(*val)) {
            coderef = *val;
        }
    }
    else {
        /* call the FIND_FUNCTION() method */
        PUSHMARK(SP);
        XPUSHs(((perl_vtab *) pVTab)->perl_vtab_obj);
        XPUSHs(sv_2mortal(newSViv(nArg)));
        XPUSHs(sv_2mortal(newSVpv(zName, 0)));
        PUTBACK;
        count = call_method ("FIND_FUNCTION", G_SCALAR);
        SPAGAIN;
        if (count != 1) {
            warn("vtab->FIND_FUNCTION() method returned %d vals instead of 1", count);
            SP -= count;
            goto cleanup;
        }
        result = POPs;
        if (SvTRUE(result)) {
            /* the coderef must be valid for the lifetime of pVTab, so
               make a copy */
            coderef = newSVsv(result);
        }

        /* store result in cache */
        hv_store(functions, func_name, len, coderef ? coderef : &PL_sv_undef, 0);
    }

    /* return function information for sqlite3 within *pxFunc and *ppArg */
    is_overloaded = coderef && SvTRUE(coderef);
    if (is_overloaded) {
        *pxFunc = MY_CXT.last_dbh_is_unicode ? sqlite_db_func_dispatcher_unicode
                                          : sqlite_db_func_dispatcher_no_unicode;
        *ppArg = coderef;
    }

 cleanup:
    PUTBACK;
    FREETMPS;
    LEAVE;
    sqlite3_free(func_name);
    return is_overloaded;
}


static int perl_vt_Rename(sqlite3_vtab *pVTab, const char *zNew){
    dTHX;
    dSP;
    int count;
    int rc = SQLITE_ERROR;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(((perl_vtab *) pVTab)->perl_vtab_obj);
    XPUSHs(sv_2mortal(newSVpv(zNew, 0)));
    PUTBACK;
    count = call_method("RENAME", G_SCALAR);
    SPAGAIN;
    if (count != 1) {
        warn("vtab->RENAME() returned %d args instead of 1", count);
        SP -= count;
    }
    else {
        rc = POPi;
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return rc;
}

static int perl_vt_Savepoint(sqlite3_vtab *pVTab, int point){
    return _call_perl_vtab_method(pVTab, "SAVEPOINT", point);
}

static int perl_vt_Release(sqlite3_vtab *pVTab, int point){
    return _call_perl_vtab_method(pVTab, "RELEASE", point);
}

static int perl_vt_RollbackTo(sqlite3_vtab *pVTab, int point){
    return _call_perl_vtab_method(pVTab, "ROLLBACK_TO", point);
}

static sqlite3_module perl_vt_Module = {
    1,                    /* iVersion */
    perl_vt_Create,       /* xCreate */
    perl_vt_Connect,      /* xConnect */
    perl_vt_BestIndex,    /* xBestIndex */
    perl_vt_Disconnect,   /* xDisconnect */
    perl_vt_Drop,         /* xDestroy */
    perl_vt_Open,         /* xOpen - open a cursor */
    perl_vt_Close,        /* xClose - close a cursor */
    perl_vt_Filter,       /* xFilter - configure scan constraints */
    perl_vt_Next,         /* xNext - advance a cursor */
    perl_vt_Eof,          /* xEof - check for end of scan */
    perl_vt_Column,       /* xColumn - read data */
    perl_vt_Rowid,        /* xRowid - read data */
    perl_vt_Update,       /* xUpdate (optional) */
    perl_vt_Begin,        /* xBegin (optional) */
    perl_vt_Sync,         /* xSync (optional) */
    perl_vt_Commit,       /* xCommit (optional) */
    perl_vt_Rollback,     /* xRollback (optional) */
    perl_vt_FindFunction, /* xFindFunction (optional) */
    perl_vt_Rename,       /* xRename */
#if SQLITE_VERSION_NUMBER >= 3007007
    perl_vt_Savepoint,    /* xSavepoint (optional) */
    perl_vt_Release,      /* xRelease (optional) */
    perl_vt_RollbackTo    /* xRollbackTo (optional) */
#endif
};


void
sqlite_db_destroy_module_data(void *pAux)
{
    dTHX;
    dSP;
    int count;
    int rc = SQLITE_ERROR;
    perl_vtab_init *init_data;

    ENTER;
    SAVETMPS;

    init_data = (perl_vtab_init *)pAux;

    /* call the DESTROY_MODULE() method */
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv(init_data->perl_class, 0)));
    PUTBACK;
    count = call_method("DESTROY_MODULE", G_VOID);
    SPAGAIN;
    SP -= count;

    /* free module memory */
    SvREFCNT_dec(init_data->dbh);
    sqlite3_free((char *)init_data->perl_class);

    PUTBACK;
    FREETMPS;
    LEAVE;
}



int
sqlite_db_create_module(pTHX_ SV *dbh, const char *name, const char *perl_class)
{
    dSP;
    D_imp_dbh(dbh);
    int count, rc, retval = TRUE;
    char *module_ISA;
    char *loading_code;
    perl_vtab_init *init_data;

    ENTER;
    SAVETMPS;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to create module on inactive database handle");
        return FALSE;
    }

    /* load the module if needed */
    module_ISA = sqlite3_mprintf("%s::ISA", perl_class);
    if (!get_av(module_ISA, 0)) {
        loading_code = sqlite3_mprintf("use %s", perl_class);
        eval_pv(loading_code, TRUE);
        sqlite3_free(loading_code);
    }
    sqlite3_free(module_ISA);

    /* build the init datastructure that will be passed to perl_vt_New() */
    init_data = sqlite3_malloc(sizeof(*init_data));
    init_data->dbh        = newRV(dbh);
    sv_rvweaken(init_data->dbh);
    init_data->perl_class = sqlite3_mprintf(perl_class);

    /* register within sqlite */
    rc = sqlite3_create_module_v2( imp_dbh->db,
                                   name,
                                   &perl_vt_Module,
                                   init_data,
                                   sqlite_db_destroy_module_data
                                   );
    if ( rc != SQLITE_OK ) {
        sqlite_error(dbh, rc, form("sqlite_create_module failed with error %s",
                                   sqlite3_errmsg(imp_dbh->db)));
        retval = FALSE;
    }


    /* call the CREATE_MODULE() method */
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpv(perl_class, 0)));
    XPUSHs(sv_2mortal(newSVpv(name, 0)));
    PUTBACK;
    count = call_method("CREATE_MODULE", G_VOID);
    SPAGAIN;
    SP -= count;

    PUTBACK;
    FREETMPS;
    LEAVE;

    return retval;
}
