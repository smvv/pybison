/*
 * Linux-specific dynamic library manipulation routines
 */

#include "bisondynlib.h"
#include <stdio.h>
#include <dlfcn.h>

void *bisondynlib_open(char *filename)
{
    void *handle;

    dlerror();
    handle = dlopen(filename, (RTLD_NOW|RTLD_GLOBAL));
    return handle;
}

int bisondynlib_close(void *handle)
{
    return dlclose(handle);
}

char *bisondynlib_err()
{
    return dlerror();
}

char *bisondynlib_lookup_hash(void *handle)
{
    char **hash;
    dlerror();
    hash = dlsym(handle, "rules_hash");
    /*
    printf("bisondynlib_lookup_hash: hash=%s\n", *hash);
    */
    return *hash;
}

PyObject *bisondynlib_run(void *handle, PyObject *parser, void *cb, void *in, int debug)
{
    PyObject *(*pparser)(PyObject *, void *, void *, int);
    //PyObject *result;

    //printf("bisondynlib_run: looking up parser\n");
    pparser = bisondynlib_lookup_parser(handle);
    //printf("bisondynlib_run: calling parser, py_input=0x%lx\n", in);
    if (!pparser) {
        PyErr_SetString(PyExc_RuntimeError,
                        "bisondynlib_lookup_parser() returned NULL");
        return NULL;
    }

    (*pparser)(parser, cb, in, debug);

    //printf("bisondynlib_run: back from parser\n");
    //return result;
    Py_INCREF(Py_None);
    return Py_None;

}

/*
 * function(void *) returns a pointer to a function(PyObject *, char *) returning PyObject*
 */
PyObject *(*bisondynlib_lookup_parser(void *handle))(PyObject *, void *, void *, int)
{
    dlerror();
    return dlsym(handle, "do_parse");
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
