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

static PyObject *py_attr_hook_handler_name;
static PyObject *py_attr_hook_read_after_name;
static PyObject *py_attr_hook_read_before_name;

static PyObject *py_attr_handle_name;
static PyObject *py_attr_read_name;
static PyObject *py_attr_file_name;
static PyObject *py_attr_close_name;

// Construct attribute names (only the first time)
// TODO: where do we Py_DECREF(handle_name) ??
#define INIT_ATTR(variable, name, failure) \
    if (unlikely(!variable)) { \
        variable = PyString_FromString(name); \
        if (!variable) failure; \
    }

#define debug_refcnt(variable, count) { \
        printf(#variable ": %d\n", Py_REFCNT(variable)); \
        assert(Py_REFCNT(variable) == count); \
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
        PyList_SetItem(names, i, name);

        PyObject *value = va_arg(ap, PyObject *);
        Py_INCREF(value);
        PyList_SetItem(values, i, value);
    }

    va_end(ap);

    INIT_ATTR(py_attr_handle_name, "_handle", return NULL);
    INIT_ATTR(py_attr_hook_handler_name, "hook_handler", return NULL);

    // Call the handler with the arguments
    PyObject *handle = PyObject_GetAttr(parser, py_attr_handle_name);

    if (unlikely(!handle)) return NULL;

    PyObject *arglist = Py_BuildValue("(siOO)", target, option, names, values);
    if (unlikely(!arglist)) { Py_DECREF(handle); return NULL; }

    res = PyObject_CallObject(handle, arglist);

    Py_DECREF(handle);
    Py_DECREF(arglist);

    if (unlikely(!res)) return res;

    // Check if the "hook_handler" callback exists
    handle = PyObject_GetAttr(parser, py_attr_hook_handler_name);

    if (!handle) {
        PyErr_Clear();
        return res;
    }

    // XXX: PyObject_GetAttr increases the refcnt of py_attr_hook_handler_name
    // by one.
    //debug_refcnt(py_attr_hook_handler_name, 1);

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

    INIT_ATTR(py_attr_hook_read_after_name, "hook_read_after", return);
    INIT_ATTR(py_attr_hook_read_before_name, "hook_read_before", return);
    INIT_ATTR(py_attr_read_name, "read", return);
    INIT_ATTR(py_attr_file_name, "file", return);
    INIT_ATTR(py_attr_close_name, "close", return);

    // Check if the "hook_READ_BEFORE" callback exists
    if (PyObject_HasAttr(parser, py_attr_hook_read_before_name))
    {
        handle = PyObject_GetAttr(parser, py_attr_hook_read_before_name);
        if (unlikely(!handle)) return;

        // Call the "hook_READ_BEFORE" callback
        arglist = PyTuple_New(0);
        if (unlikely(!arglist)) { Py_DECREF(handle); return; }

        res = PyObject_CallObject(handle, arglist);

        Py_DECREF(handle);
        Py_DECREF(arglist);

        if (unlikely(!res)) return;
    }

    // Read the input string and catch keyboard interrupt exceptions.
    handle = PyObject_GetAttr(parser, py_attr_read_name);
    if (unlikely(!handle)) return;

    arglist = Py_BuildValue("(i)", max_size);
    if (unlikely(!arglist)) { Py_DECREF(handle); return; }

    res = PyObject_CallObject(handle, arglist);

    Py_DECREF(handle);
    Py_DECREF(arglist);

    if (unlikely(!res)) {
        // Catch and reset KeyboardInterrupt exception
        PyObject *given = PyErr_Occurred();
        if (given && PyErr_GivenExceptionMatches(given,
                                                 PyExc_KeyboardInterrupt)) {

            PyErr_Clear();
        }

        return;
    }

    // Check if the "hook_read_after" callback exists
    if (unlikely(!PyObject_HasAttr(parser, py_attr_hook_read_after_name)))
        goto finish_input;

    handle = PyObject_GetAttr(parser, py_attr_hook_read_after_name);
    if (unlikely(!handle)) return;

    // Call the "hook_READ_AFTER" callback
    arglist = Py_BuildValue("(O)", res);
    if (unlikely(!arglist)) { Py_DECREF(handle); return; }

    res = PyObject_CallObject(handle, arglist);

    Py_XDECREF(res);
    Py_DECREF(handle);
    Py_DECREF(arglist);

    if (unlikely(!res)) return;

finish_input:

    // Copy the read python input string to the buffer
    bufstr = PyString_AsString(res);
    *result = strlen(bufstr);
    memcpy(buf, bufstr, *result);

    // Close the read buffer if nothing is read. Marks the Python file object
    // as being closed from Python's point of view. This does not close the
    // associated C stream (which is not necessary here, otherwise use
    // "os.close(0)").
    if (!*result && PyObject_HasAttr(parser, py_attr_file_name)) {
        PyObject *file_handle = PyObject_GetAttr(parser, py_attr_file_name);
        if (unlikely(!file_handle)) return;

        handle = PyObject_GetAttr(file_handle, py_attr_close_name);
        Py_DECREF(file_handle);
        if (unlikely(!handle)) return;

        arglist = PyTuple_New(0);
        if (unlikely(!arglist)) { Py_DECREF(handle); return; }

        res = PyObject_CallObject(handle, arglist);

        Py_XDECREF(res);
        Py_DECREF(handle);
        Py_DECREF(arglist);

        // TODO: something went wrong while closing the buffer.
        if (unlikely(!res)) return;
    }
}
