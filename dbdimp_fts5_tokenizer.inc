typedef struct perl_Fts5Tokenizer {
    /* Fts5Tokenizer base; */    /* this is an empty struct, so we omit  it entirely */
    SV *coderef;                 /* the perl tokenizer is a coderef that takes
                                 ** a string and and some parameters and
                                 ** in turn calls the xToken() function
                                 ** passed to it
                                 */
} perl_Fts5Tokenizer;

/*
** Create a new tokenizer instance.
** Will be called whenever a FTS5 table is created with
**   CREATE .. USING fts5( ... , tokenize=perl qualified::function::name)
** where qualified::function::name is a fully qualified perl function
*/
static int perl_fts5_tokenizer_Create(
    void* pCtx, const char **azArg, int nArg, Fts5Tokenizer **ppOut
){
    dTHX;
    dSP;
    int n_retval;
    SV *retval;
    perl_Fts5Tokenizer *t;
    if (!nArg) {
        return SQLITE_ERROR;
    }

    t = (perl_Fts5Tokenizer *) sqlite3_malloc(sizeof(*t));
    if( t==NULL ) return SQLITE_NOMEM;
    memset(t, 0, sizeof(*t));
    ENTER;
    SAVETMPS;

    /* call the qualified::function::name */
    PUSHMARK(SP);
    PUTBACK;
    n_retval = call_pv(azArg[0], G_SCALAR);
    SPAGAIN;

    /* store a copy of the returned coderef into the tokenizer structure */
    if (n_retval != 1) {
        warn("tokenizer_Create returned %d arguments, expected a single coderef", n_retval);
    }
    retval = POPs;
    t->coderef   = newSVsv(retval);
    /* *ppOut = &t->base; */ /* Fts5Tokenizer is empty and gcc complains about that */
    *ppOut = (Fts5Tokenizer *) t;

    PUTBACK;
    FREETMPS;
    LEAVE;

    return SQLITE_OK;
}

/*
** Destroy a tokenizer
*/
static void perl_fts5_tokenizer_Delete(Fts5Tokenizer *pTokenizer){
    dTHX;
    perl_Fts5Tokenizer *t = (perl_Fts5Tokenizer *) pTokenizer;
    sv_free(t->coderef);
    sqlite3_free(t);
    return;
}

/*
** This does a tokenizing run over the string. Found tokens (and synonyms)
** are stored by calling xToken()
*/
static int perl_fts5_tokenizer_Tokenize(
      Fts5Tokenizer* tokenizer,
      void *pCtx,
      int flags,            /* Mask of FTS5_TOKENIZE_* flags */
      const char *pText, int nText,
      int (*xToken)(
        void *pCtx,         /* Copy of 2nd argument to xTokenize() */
        int tflags,         /* Mask of FTS5_TOKEN_* flags */
        const char *pToken, /* Pointer to buffer containing token */
        int nToken,         /* Size of token in bytes */
        int iStart,         /* Byte offset of token within input text */
        int iEnd            /* Byte offset of end of token within input text */
      )
){
    perl_Fts5Tokenizer *c = (perl_Fts5Tokenizer *) tokenizer;
    char *token;
    char *byteOffset;
    dTHX;
    dSP;

    /* newSVpvn() will create a copy of this buffer, but ideally we would
     * directly write into the PV part of that copied buffer instead
     */
    perl_cb_ctx ctx;
    SV* ctxP;
    SV* text;

    STRLEN n_a; /* this is required for older perls < 5.8.8 */
    I32 hop;

    ENTER;
    SAVETMPS;

    /* call the Perl tokenizer, and pass it our token callback */
    PUSHMARK(SP);

    ctx.Ctx = pCtx;
    ctx.xToken = xToken;
    ctxP = newSVpvn((const char *const)&ctx, sizeof(ctx));

    text = newSVpvn(pText, nText);

    // We pass four arguments
    //EXTEND(SP, 2);
    XPUSHs(sv_2mortal(ctxP));
    XPUSHs(sv_2mortal(text));
    XPUSHs(sv_2mortal(newSViv(flags)));
    // We need to properly wrap this so it is callable from Perl...
    // ... without needing actual local storage or a global variable...

    // XXX Wrap the "found token" callback, and pass it to the user
    //     Then, restructure the data if it is UTF-8
    //     First, do all of this in Perl so it is easier to debug

    ///* if we get back an empty list, there is no more token */
    //if (n_retval == 0) {
    //    result = SQLITE_DONE;
    //}
    ///* otherwise, get token details from the return list */
    //else {
    //     if (n_retval != 5) {
    //        warn("tokenizer cursor returned %d arguments", n_retval);
    //    }
    //    *piPosition    = POPi;
    //    *piEndOffset   = POPi;
    //    *piStartOffset = POPi;
    //    *pnBytes       = POPi;
    //    token          = POPpx;
    //
    //    if (c->pInput) { /* if working with utf8 data */
    //
    //        /* recompute *pnBytes in bytes, not in chars */
    //        *pnBytes = strlen(token);
    //
    //        /* recompute start/end offsets in bytes, not in chars */
    //        hop            = *piStartOffset - c->lastCharOffset;
    //        byteOffset     = (char*)utf8_hop((U8*)c->lastByteOffset, hop);
    //        hop            = *piEndOffset - *piStartOffset;
    //        *piStartOffset = byteOffset - c->pInput;
    //        byteOffset     = (char*)utf8_hop((U8*)byteOffset, hop);
    //        *piEndOffset   = byteOffset - c->pInput;
    //
    //        /* remember where we are for next round */
    //        c->lastCharOffset = *piEndOffset,
    //        c->lastByteOffset = byteOffset;
    //    }
    //
    //    /* make sure we have enough storage for copying the token */
    //    if (*pnBytes > c->nTokenAllocated ){
    //        char *pNew;
    //        c->nTokenAllocated = *pnBytes + 20;
    //        pNew = sqlite3_realloc(c->pToken, c->nTokenAllocated);
    //        if( !pNew ) return SQLITE_NOMEM;
    //        c->pToken = pNew;
    //    }
    //
    //    /* need to copy the token into the C cursor before perl frees that
    //       memory */
    //    memcpy(c->pToken, token, *pnBytes);
    //    *ppToken  = c->pToken;
    //
    //    result = SQLITE_OK;
    //
    PUTBACK;
    call_sv(c->coderef, G_VOID);

    SPAGAIN;

    PUTBACK;
    FREETMPS;
    LEAVE;

    return SQLITE_OK;
}

int perl_fts5_xToken(pTHX_
        SV* pCtx,
        int tflags,         /* Mask of FTS5_TOKEN_* flags */
        SV* svToken,         /* Pointer to buffer containing token */
        int iStart,         /* Byte offset of token within input text */
        int iEnd            /* Byte offset of end of token within input text */
) {
    STRLEN nToken;
    const char* chrToken = SvPV(svToken, nToken);
    perl_cb_ctx * p = (perl_cb_ctx *)SvPV_nolen( pCtx );
    return p->xToken(p->Ctx,tflags,chrToken,nToken,iStart,iEnd);
}


/*
** The set of routines that implement the perl FTS5 tokenizer
*/
fts5_tokenizer perl_fts5_tokenizer_Module = {
    perl_fts5_tokenizer_Create,
    perl_fts5_tokenizer_Delete,
    perl_fts5_tokenizer_Tokenize
};

/*
** Fetch the FTS5 API pointers
*/

fts5_api* sqlite_fetch_fts5_api(pTHX_ SV *dbh)
{
    D_imp_dbh(dbh);

    int rc;
    sqlite3_stmt *pStmt;
    const char zSql[] = "SELECT fts5(?)";
    fts5_api *pFts5Api = 0;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to register fts5 tokenizer on inactive database handle");
        return FALSE;
    }

    rc = sqlite3_prepare_v2(imp_dbh->db, zSql, -1, &pStmt, 0);
    if( rc!=SQLITE_OK ){
        return 0;
    }

    sqlite3_bind_pointer(pStmt, 1, (void*)&pFts5Api, "fts5_api_ptr", NULL);
    sqlite3_step(pStmt);
    sqlite3_finalize(pStmt);

    return pFts5Api;
}

/*
** Register the perl tokenizer with FTS5
*/
int sqlite_db_register_fts5_perl_tokenizer(pTHX_ SV *dbh)
{
    D_imp_dbh(dbh);

    int rc;
    fts5_api *pFts5Api = sqlite_fetch_fts5_api(aTHX_ dbh);
    fts5_tokenizer *p = &perl_fts5_tokenizer_Module;

    rc = pFts5Api->xCreateTokenizer(pFts5Api, "perl", 0, p, 0);

    return rc;
}
