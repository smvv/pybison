//@+leo-ver=4
//@+node:@file src/c/bisondynlib-win32.c
//@@language c
/*
 * Linux-specific dynamic library manipulation routines
 */

#include <stdio.h>
#include "bisondynlib.h"

#include "windows.h"

//#include "dlluser.h"

void * bisondynlib_open(char *filename)
{
    HINSTANCE hinstLib; 

    hinstLib = LoadLibrary(filename);

    return (void *)hinstLib;
}

int  bisondynlib_close(void *handle)
{
    return FreeLibrary((HINSTANCE)handle); 
}

char * bisondynlib_err()
{
    return NULL;
}


char * bisondynlib_lookup_hash(void *handle)
{
    char *hash;

    hash = (char *)GetProcAddress((HINSTANCE)handle, "rules_hash"); 
    printf("bisondynlib_lookup_hash: hash=%s\n", hash);
    return hash;
}

PyObject * bisondynlib_run(void *handle, PyObject *parser, char *filename, void *cb)
{
    PyObject *(*pparser)(PyObject *, char *, void *);

    //printf("bisondynlib_run: looking up parser\n");
    pparser = bisondynlib_lookup_parser(handle);
    //printf("bisondynlib_run: calling parser\n");

    (*pparser)(parser, filename, cb);

    //printf("bisondynlib_run: back from parser\n");
    //return result;
    Py_INCREF(Py_None);
    return Py_None;

}

/*
 * function(void *) returns a pointer to a function(PyObject *, char *) returning PyObject*
 */
PyObject *(*bisondynlib_lookup_parser(void *handle))(PyObject *, char *, void *)
{
    //void *pparser;
    PyObject *(*pparser)(PyObject *, char *, void *);
    
    pparser = (PyObject *(*)(PyObject *, char *, void *))GetProcAddress((HINSTANCE)handle, "do_parse");

    return pparser;
}

/*
 * Runs the compiler commands which build the parser/lexer into a shared lib
 */
 /*
int bisondynlib_build(char *libName, char *pyincdir)
{
    char buf[1024];
    sprintf(buf, "gcc -fPIC -shared -I%s tmp.bison.c tmp.lex.c -o %s", pyincdir, libName);
    printf("Running linux build command: %s\n", buf);
    system(buf);
    return 0;
}
*/

//@-node:@file src/c/bisondynlib-win32.c
//@-leo
