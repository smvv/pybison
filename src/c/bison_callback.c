/*
 * Callback functions called by bison.
 *
 * The original py_callback function is removed from bison_.pyx because Cython
 * generated crappy code for that callback. Cython's generated code caused
 * segfaults when python triggered its garbage collection. Thus, something was
 * wrong with references. Debugging the generated code was hard and the
 * callbacks are part of PyBison's core, so implementing the callbacks in C
 * instead of generating them by Cython seems the right way to go.
 *
 * Written januari 2012 by Sander Mathijs van Veen <smvv@kompiler.org>
 * Copyright (c) 2012 by Sander Mathijs van Veen, all rights reserved.
 *
 * Released under the GNU General Public License, a copy of which should appear
 * in this distribution in the file called 'COPYING'. If this file is missing,
 * then you can obtain a copy of the GPL license document from the GNU website
 * at http://www.gnu.org.
 *
 * This software is released with no warranty whatsoever. Use it at your own
 * risk.
 *
 * If you wish to use this software in a commercial application, and wish to
 * depart from the GPL licensing requirements, please contact the author and
 * apply for a commercial license.
 */

#include "Python.h"
#include "stdarg.h"
#include <stdio.h>

#define likely(x)       __builtin_expect((x),1)
#define unlikely(x)     __builtin_expect((x),0)

static PyObject *py_callback_handle_name;
static PyObject *py_callback_hook_name;


/*
 * Callback function which is invoked by target handlers within the C yyparse()
 * function. This callback function will return parser._handle's python object
 * or, on failure, NULL is returned.
 */
PyObject* py_callback(PyObject *parser, char *target, int option, int nargs,
                      ...)
{
    va_list ap;
    int i;

    PyObject *res;

    PyObject *names = PyList_New(nargs),
        *values = PyList_New(nargs);

    va_start(ap, nargs);

    // Construct the names and values list from the variable argument list.
    for(i = 0; i < nargs; i++) {
        PyObject *name = PyString_FromString(va_arg(ap, char *));
        Py_INCREF(name);
        PyList_SetItem(names, i, name);

        PyObject *value = va_arg(ap, PyObject *);
        Py_INCREF(value);
        PyList_SetItem(values, i, value);
    }

    va_end(ap);

    // Construct attribute names (only the first time)
    if (unlikely(!py_callback_handle_name)) {
        py_callback_handle_name = PyString_FromString("_handle");
        // TODO: where do we Py_DECREF(handle_name) ??
    }

    if (unlikely(!py_callback_hook_name)) {
        py_callback_hook_name = PyString_FromString("hook_handler");
        // TODO: where do we Py_DECREF(hook_name) ??
    }

    // Call the handler with the arguments
    PyObject *handle = PyObject_GetAttr(parser, py_callback_handle_name);

    if (unlikely(!handle)) return res;

    PyObject *arglist = Py_BuildValue("(siOO)", target, option, names, values);
    if (unlikely(!arglist)) { Py_DECREF(handle); return res; }

    res = PyObject_CallObject(handle, arglist);

    Py_DECREF(handle);
    Py_DECREF(arglist);

    if (unlikely(!res)) return res;

    // Check if the "hook_handler" callback exists
    if (unlikely(!PyObject_HasAttr(parser, py_callback_hook_name)))
        return res;

    handle = PyObject_GetAttr(parser, py_callback_hook_name);

    if (unlikely(!handle)) {
        Py_DECREF(res);
        return NULL;
    }

    // Call the "hook_handler" callback
    arglist = Py_BuildValue("(siOOO)", target, option, names, values, res);
    if (unlikely(!arglist)) { Py_DECREF(handle); return res; }

    res = PyObject_CallObject(handle, arglist);

    Py_DECREF(handle);
    Py_DECREF(arglist);

    return res;
}
