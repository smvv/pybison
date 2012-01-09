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

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#define likely(x)       __builtin_expect((x),1)
#define unlikely(x)     __builtin_expect((x),0)

static PyObject *py_callback_hook_handler_name;
static PyObject *py_callback_hook_read_after_name;
static PyObject *py_callback_hook_read_before_name;

static PyObject *py_callback_handle_name;
static PyObject *py_callback_read_name;

// Construct attribute names (only the first time)
// TODO: where do we Py_DECREF(handle_name) ??
#define INIT_ATTR(variable, name) \
    if (unlikely(!variable)) { \
        variable = PyString_FromString(name); \
    }

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

    INIT_ATTR(py_callback_handle_name, "_handle");
    INIT_ATTR(py_callback_hook_handler_name, "hook_handler");

    // Call the handler with the arguments
    PyObject *handle = PyObject_GetAttr(parser, py_callback_handle_name);

    if (unlikely(!handle)) return NULL;

    PyObject *arglist = Py_BuildValue("(siOO)", target, option, names, values);
    if (unlikely(!arglist)) { Py_DECREF(handle); return NULL; }

    res = PyObject_CallObject(handle, arglist);

    Py_DECREF(handle);
    Py_DECREF(arglist);

    if (unlikely(!res)) return res;

    // Check if the "hook_handler" callback exists
    if (unlikely(!PyObject_HasAttr(parser, py_callback_hook_handler_name)))
        return res;

    handle = PyObject_GetAttr(parser, py_callback_hook_handler_name);

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

void py_input(PyObject *parser, char *buf, int *result, int max_size)
{
    PyObject *handle, *arglist, *res;
    char *bufstr;

    INIT_ATTR(py_callback_hook_read_after_name, "hook_read_after");
    INIT_ATTR(py_callback_hook_read_before_name, "hook_read_before");
    INIT_ATTR(py_callback_read_name, "read");

    // Check if the "hook_READ_BEFORE" callback exists
    if (unlikely(!PyObject_HasAttr(parser, py_callback_hook_read_before_name)))
    {
        handle = PyObject_GetAttr(parser, py_callback_hook_read_before_name);
        if (unlikely(!handle)) return;

        // Call the "hook_READ_BEFORE" callback
        arglist = PyTuple_New(0);
        if (unlikely(!arglist)) { Py_DECREF(handle); return; }

        res = PyObject_CallObject(handle, arglist);

        Py_DECREF(handle);
        Py_DECREF(arglist);
    }

    // Read the input string and catch keyboard interrupt exceptions.
    handle = PyObject_GetAttr(parser, py_callback_read_name);
    if (unlikely(!handle)) {
        // TODO: set exception message for missing attribute error
        return;
    }

    arglist = Py_BuildValue("(i)", max_size);
    if (unlikely(!arglist)) { Py_DECREF(handle); return; }

    res = PyObject_CallObject(handle, arglist);

    Py_DECREF(handle);
    Py_DECREF(arglist);

    if (unlikely(!res)) { return; }

    // Check if the "hook_read_after" callback exists
    if (unlikely(!PyObject_HasAttr(parser, py_callback_hook_read_after_name)))
        goto finish_input;

    handle = PyObject_GetAttr(parser, py_callback_hook_read_after_name);
    if (unlikely(!handle)) return;

    // Call the "hook_READ_AFTER" callback
    arglist = Py_BuildValue("(O)", res);
    if (unlikely(!arglist)) { Py_DECREF(handle); return; }

    res = PyObject_CallObject(handle, arglist);

    Py_DECREF(handle);
    Py_DECREF(arglist);

    if (unlikely(!res)) return;

finish_input:

    // Copy the read python input string to the buffer
    bufstr = PyString_AsString(res);
    *result = strlen(bufstr);
    memcpy(buf, bufstr, *result);

    // TODO: translate the following code snippet to the Python C aPI
    //if buflen == 0 and parser.file:
    //    # Marks the Python file object as being closed from Python's point of
    //    # view. This does not close the associated C stream (which is not
    //    # necessary here, otherwise use "os.close(0)").
    //    parser.file.close()
}
