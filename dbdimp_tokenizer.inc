typedef struct perl_fts3_tokenizer {
    sqlite3_tokenizer base;
    SV *coderef;                 /* the perl tokenizer is a coderef that takes
                                    a string and returns a cursor coderef */
} perl_fts3_tokenizer;

typedef struct perl_fts3_tokenizer_cursor {
    sqlite3_tokenizer_cursor base;
    SV *coderef;                 /* ref to the closure that returns terms */
    char *pToken;                /* storage for a copy of the last token */
    int nTokenAllocated;         /* space allocated to pToken buffer */

    /* members below are only used if the input string is in utf8 */
    const char *pInput;          /* input we are tokenizing */
    const char *currentByte;     /* pointer into pInput */
    int         currentChar;     /* char position corresponding to currentByte */
} perl_fts3_tokenizer_cursor;

typedef struct perl_Fts5Tokenizer {
    Fts5Tokenizer base;
    SV *coderef;                 /* the perl tokenizer is a coderef that takes
                                 ** a string and and some parameters and
                                 ** in turn calls the xToken() function
                                 ** passed to it
                                 */
} perl_Fts5Tokenizer;

/*
** Create a new tokenizer instance.
** Will be called whenever a FTS3 table is created with
**   CREATE .. USING fts3( ... , tokenize=perl qualified::function::name)
** where qualified::function::name is a fully qualified perl function
*/
static int perl_fts3_tokenizer_Create(
    int argc, const char * const *argv,
    sqlite3_tokenizer **ppTokenizer
){
    dTHX;
    dSP;
    int n_retval;
    SV *retval;
    perl_fts3_tokenizer *t;

    if (!argc) {
        return SQLITE_ERROR;
    }

    t = (perl_fts3_tokenizer *) sqlite3_malloc(sizeof(*t));
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
static int perl_fts3_tokenizer_Destroy(sqlite3_tokenizer *pTokenizer){
    dTHX;
    perl_fts3_tokenizer *t = (perl_fts3_tokenizer *) pTokenizer;
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
static int perl_fts3_tokenizer_Open(
    sqlite3_tokenizer *pTokenizer,       /* Tokenizer object */
    const char *pInput, int nBytes,      /* Input buffer */
    sqlite3_tokenizer_cursor **ppCursor  /* OUT: Created tokenizer cursor */
){
    dTHX;
    dSP;
    dMY_CXT;
    U32 flags;
    SV *perl_string;
    int n_retval;

    /* build a Perl copy of the input string */
    if (nBytes < 0) { /* we get -1 from fts3. Don't know why ! */
        nBytes = strlen(pInput);
    }

    /* SVs_TEMP will call sv_2mortal */
    perl_string = newSVpvn_flags(pInput, nBytes, SVs_TEMP);

    switch (MY_CXT.last_dbh_string_mode) {
        DBD_SQLITE_STRING_MODE_UNICODE_NAIVE:
            DBD_SQLITE_UTF8_DECODE_NAIVE(perl_string);
            break;

        DBD_SQLITE_STRING_MODE_UNICODE_FALLBACK:
        DBD_SQLITE_STRING_MODE_UNICODE_STRICT:
            DBD_SQLITE_UTF8_DECODE_WITH_FALLBACK(perl_string);
            break;

        default:
            break;
    }

    DBD_SQLITE_UTF8_DECODE_IF_NEEDED(perl_string, MY_CXT.last_dbh_string_mode);

    perl_fts3_tokenizer *t = (perl_fts3_tokenizer *)pTokenizer;

    /* allocate and initialize the cursor struct */
    perl_fts3_tokenizer_cursor *c;
    c = (perl_fts3_tokenizer_cursor *) sqlite3_malloc(sizeof(*c));
    memset(c, 0, sizeof(*c));
    *ppCursor = &c->base;

    /* special handling if working with utf8 strings */
    if (MY_CXT.last_dbh_string_mode & DBD_SQLITE_STRING_MODE_UNICODE_ANY) {

        /* data to keep track of byte positions */
        c->currentByte = c->pInput = pInput;
        c->currentChar = 0;
    }

    ENTER;
    SAVETMPS;

    /* call the tokenizer coderef */
    PUSHMARK(SP);
    XPUSHs(perl_string);
    PUTBACK;
    n_retval = call_sv(t->coderef, G_SCALAR);
    SPAGAIN;

    /* store the cursor coderef returned by the tokenizer */
    if (n_retval != 1) {
        warn("tokenizer returned %d arguments, expected 1", n_retval);
    }
    c->coderef = newSVsv(POPs);

    PUTBACK;
    FREETMPS;
    LEAVE;
    return SQLITE_OK;
}

/*
** Close a tokenization cursor previously opened by a call to
** perl_fts3_tokenizer_Open() above.
*/
static int perl_fts3_tokenizer_Close(sqlite3_tokenizer_cursor *pCursor){
    perl_fts3_tokenizer_cursor *c = (perl_fts3_tokenizer_cursor *) pCursor;

    dTHX;
    sv_free(c->coderef);
    if (c->pToken) sqlite3_free(c->pToken);
    sqlite3_free(c);
    return SQLITE_OK;
}

/*
** Extract the next token from a tokenization cursor.  The cursor must
** have been opened by a prior call to perl_fts3_tokenizer_Open().
*/
static int perl_fts3_tokenizer_Next(
    sqlite3_tokenizer_cursor *pCursor,  /* Cursor returned by perl_tokenizer_Open */
    const char **ppToken,               /* OUT: Normalized text for token */
    int *pnBytes,                       /* OUT: Number of bytes in normalized text */
    int *piStartOffset,                 /* Starting offset of token. IN : char offset; OUT : byte offset */
    int *piEndOffset,                   /* Ending offset of token.   IN : char offset; OUT : byte offset */
    int *piPosition                     /* OUT: Number of tokens returned before this one */
){
    perl_fts3_tokenizer_cursor *c = (perl_fts3_tokenizer_cursor *) pCursor;
    int result;
    int n_retval;
    char *token;
    char *nextByte;
    STRLEN n_a; /* this is required for older perls < 5.8.8 */
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
            warn("tokenizer cursor returned %d arguments, expected 5", n_retval);
        }
        *piPosition    = POPi;
        *piEndOffset   = POPi;
        *piStartOffset = POPi;
        *pnBytes       = POPi;
        token          = POPpx;

        if (c->pInput) { /* if working with utf8 data */
            /* compute first hop : nb of chars from last position to the start of the token */
            hop               = *piStartOffset - c->currentChar;

            /* hop: advance to the first byte in token */
            nextByte          = (char*)utf8_hop((U8*)c->currentByte, hop);

            /* compute 2nd hop : nb of chars from start of the token to end of token */
            hop               = *piEndOffset - *piStartOffset;

            /* now recompute the start offset in bytes, not in chars */
            *piStartOffset    = nextByte - c->pInput;

            /* 2nd hop: advance past to the last byte in token */
            nextByte          = (char*)utf8_hop((U8*)nextByte, hop);

            /* remember current position (useful for the next invocation) */
            c->currentChar    = *piEndOffset;
            c->currentByte    = nextByte;

            /* now recompute the end offset in bytes, not in chars */
            *piEndOffset      = nextByte - c->pInput;

            /* compute the size of the normalized token in bytes, not in chars */
            *pnBytes          = strlen(token);
        }

        /* make sure we have enough storage for copying the token */
        if (*pnBytes > c->nTokenAllocated ){
            char *pNew;
            c->nTokenAllocated = *pnBytes + 20;
            pNew = sqlite3_realloc(c->pToken, c->nTokenAllocated);
            if( !pNew ) return SQLITE_NOMEM;
            c->pToken = pNew;
        }

        /* need to copy the token into the C cursor before perl frees that memory */
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
sqlite3_tokenizer_module perl_fts3_tokenizer_Module = {
    0,
    perl_fts3_tokenizer_Create,
    perl_fts3_tokenizer_Destroy,
    perl_fts3_tokenizer_Open,
    perl_fts3_tokenizer_Close,
    perl_fts3_tokenizer_Next
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
    sqlite3_tokenizer_module *p = &perl_fts3_tokenizer_Module;

    if (!DBIc_ACTIVE(imp_dbh)) {
        sqlite_error(dbh, -2, "attempt to register fts3 tokenizer on inactive database handle");
        return FALSE;
    }

#if SQLITE_VERSION_NUMBER >= 3012000
    rc = sqlite3_db_config(imp_dbh->db, SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER, 1, 0);
    if( rc!=SQLITE_OK ){
        return rc;
    }
#endif

    rc = sqlite3_prepare_v2(imp_dbh->db, zSql, -1, &pStmt, 0);
    if( rc!=SQLITE_OK ){
        return rc;
    }

    sqlite3_bind_text(pStmt, 1, "perl", -1, SQLITE_STATIC);
    sqlite3_bind_blob(pStmt, 2, &p, sizeof(p), SQLITE_STATIC);
    sqlite3_step(pStmt);

    return sqlite3_finalize(pStmt);
}

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
        warn("tokenizer_Create returned %d arguments", n_retval);
    }
    retval = POPs;
    t->coderef   = newSVsv(retval);
    *ppOut = &t->base;

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
    int result;
    int n_retval;
    char *token;
    char *byteOffset;
    STRLEN n_a; /* this is required for older perls < 5.8.8 */
    I32 hop;

    dTHX;
    dSP;

    ENTER;
    SAVETMPS;

    /* call the Perl tokenizer, and pass it our token callback */
    PUSHMARK(SP);
    PUTBACK;

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

    n_retval = call_sv(c->coderef, G_ARRAY);
    SPAGAIN;


    PUTBACK;
    FREETMPS;
    LEAVE;

    return result;
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

    // pFts5Api->xCreateTokenizer(pFts5Api,...);


    return 0;
}
