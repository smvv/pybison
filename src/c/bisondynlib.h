//@+leo-ver=4
//@+node:@file src/c/bisondynlib.h
//@@language c
/*
 * common interface to dynamic library routines
 */

#include <stdio.h>
#include "Python.h"

void *bisondynlib_open(char *filename);
int bisondynlib_close(void *handle);
char *bisondynlib_err(void);

PyObject *(*bisondynlib_lookup_parser(void *handle))(PyObject *, void *, void *, int);

char *bisondynlib_lookup_hash(void *handle);

PyObject *bisondynlib_run(void *handle, PyObject *parser, void *cb, void *in, int debug);

/*
int bisondynlib_build(char *libName, char *pyincdir);
*/
//@-node:@file src/c/bisondynlib.h
//@-leo
