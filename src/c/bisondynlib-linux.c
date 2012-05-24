/*
 * Linux-specific dynamic library manipulation routines
 */

#include "bisondynlib.h"
#include <stdio.h>
#include <dlfcn.h>

void (*reset_flex_buffer)(void) = NULL;

void *bisondynlib_open(char *filename)
{
    void *handle;

    handle = dlopen(filename, (RTLD_NOW|RTLD_GLOBAL));

    dlerror();

    if (!handle)
        return NULL;

    reset_flex_buffer = dlsym(handle, "reset_flex_buffer");

    dlerror();

    return handle;
}

int bisondynlib_close(void *handle)
{
    return dlclose(handle);
}

void bisondynlib_reset(void)
{
    if (reset_flex_buffer)
        reset_flex_buffer();
}

char *bisondynlib_err()
{
    return dlerror();
}

char *bisondynlib_lookup_hash(void *handle)
{
    char **hash;

    hash = dlsym(handle, "rules_hash");

    dlerror();

    return hash ? *hash : NULL;
}

PyObject *bisondynlib_run(void *handle, PyObject *parser, void *cb, void *in, int debug)
{
    if(!handle)
        return NULL;

    PyObject *(*pparser)(PyObject *, void *, void *, int);

    pparser = bisondynlib_lookup_parser(handle);

    if (!pparser) {
        PyErr_SetString(PyExc_RuntimeError,
                        "bisondynlib_lookup_parser() returned NULL");
        return NULL;
    }

    (*pparser)(parser, cb, in, debug);

    // Do not ignore a raised exception, but pass the exception through.
    if (PyErr_Occurred())
        return NULL;

    Py_INCREF(Py_None);
    return Py_None;

}

/*
 * function(void *) returns a pointer to a function(PyObject *, char *)
 * returning PyObject*
 */
PyObject *(*bisondynlib_lookup_parser(void *handle))(PyObject *, void *, void *, int)
{
    PyObject *(*do_parse)(PyObject *, void *, void *, int) = dlsym(handle,
            "do_parse");

    dlerror();

    return do_parse;
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
