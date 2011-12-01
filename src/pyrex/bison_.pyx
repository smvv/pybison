"""
Pyrex-generated portion of pybison
"""

cdef extern from "Python.h":
    object PyString_FromStringAndSize(char *, int)
    object PyString_FromString(char *)
    char *PyString_AsString(object o)

    object PyInt_FromLong(long ival)
    long PyInt_AsLong(object io)

    object PyList_New(int len)
    int PyList_SetItem(object list, int index, object item)

    void Py_INCREF(object o)

    object PyObject_GetAttrString(object o, char *attr_name)
    object PyTuple_New(int len)
    int PyTuple_SetItem(object p, int pos, object o)
    object PyObject_Call(object callable_object, object args, object kw)
    object PyObject_CallObject(object callable_object, object args)
    int PyObject_SetAttrString(object o, char *attr_name, object v)

# use libdl for now - easy and simple - maybe switch to
# glib or libtool if a keen windows dev sends in a patch

#cdef extern from "dlfcn.h":
#    void *dlopen(char *filename, int mode)
#    int dlclose(void *handle)
#    void *dlsym(void *handle, char *name)
#    char *dlerror()
#
#    ctypedef enum DL_MODES:
#        RTLD_LAZY
#        RTLD_NOW
#        RTLD_BINDING_MASK
#        RTLD_NOLOAD
#        RTLD_GLOBAL

cdef extern from "stdio.h":
    int printf(char *format,...)

cdef extern from "string.h":
    void *memcpy(void *dest, void *src, long n)

cdef extern from "../c/bisondynlib.h":
    void *bisondynlib_open(char *filename)
    int bisondynlib_close(void *handle)
    char *bisondynlib_err()
    object (*bisondynlib_lookup_parser(void *handle))(object, char *)
    char *bisondynlib_lookup_hash(void *handle)
    object bisondynlib_run(void *handle, object parser, void *cb, void *pyin, int debug)

    #int bisondynlib_build(char *libName, char *includedir)

# Definitions for variadic functions (e.g. py_callback).
cdef extern from "stdarg.h":
    ctypedef struct va_list:
        pass
    ctypedef struct fake_type:
        pass
    void va_start(va_list, int arg)
    void* va_arg(va_list, fake_type)
    void va_end(va_list)
    fake_type void_type "void *"
    fake_type str_type "char *"

# Callback function which is invoked by target handlers
# within the C yyparse() function.

import signal

cdef public object py_callback(object parser, char *target, int option, \
        int nargs, ...):

    cdef int i
    cdef va_list ap
    va_start(ap, <int>nargs)

    cdef void *objptr
    cdef object obj
    cdef object valobj
    cdef void *val
    cdef char *tokval
    cdef char *termname

    #if parser.verbose:
    #    print 'py_callback: called with nargs=%d' % nargs

    names = PyList_New(nargs)
    values = PyList_New(nargs)

    Py_INCREF(names)
    Py_INCREF(values)

    #for i in range(nargs):
    #    print 'i=%d' % i , <char*>va_arg(ap, str_type), \
    #                       hex(<int>va_arg(ap, str_type))

    for i in range(nargs):
        termname = <char*>va_arg(ap, str_type)
        PyList_SetItem(names, i, termname)
        Py_INCREF(termname)

        val = <void *>va_arg(ap, void_type)
        valobj = <object>val
        PyList_SetItem(values, i, valobj)
        Py_INCREF(valobj)

    #if parser.verbose:
    #    print 'py_callback: calling handler:', \
    #          (target, option, names, values)


    # Set the signal handler and a timeout alarm
    #signal.signal(signal.SIGALRM, parser.handle_timeout)
    #signal.alarm(parser.timeout)

    res = parser._handle(target, option, names, values)

    #signal.alarm(0)

    #if parser.verbose:
    #    print 'py_callback: handler returned:', res

    va_end(ap)

    return res

# callback routine for reading input
cdef public void py_input(object parser, char *buf, int *result, int max_size):
    cdef char *buf1
    cdef int buflen

    if parser.verbose:
        print '\npy_input: want to read up to %s bytes' % max_size

    raw = parser.read(max_size)
    buflen = PyInt_AsLong(len(raw))
    result[0] = buflen
    memcpy(buf, PyString_AsString(raw), buflen)

    if parser.verbose:
        print '\npy_input: got %s bytes' % buflen


import sys, os, sha, re, imp, traceback
import shutil
import distutils.sysconfig
import distutils.ccompiler


reSpaces = re.compile("\\s+")

#unquoted = r"""^|[^'"]%s[^'"]?"""
unquoted = '[^\'"]%s[^\'"]?'

cdef class ParserEngine:
    """
    Wraps the interface to the binary bison/lex-generated parser engine dynamic
    library.

    You shouldn't need to deal with this at all.

    Takes care of:
        - building the library (if the parser rules have changed)
        - loading the library and extracting the parser entry point
        - calling the entry point
        - closing the library

    Makes direct calls to the platform-dependent routines in
    bisondynlib-[linux|windows].c
    """
    cdef object parser
    cdef object parserHash # hash of current python parser object
    cdef object libFilename_py

    cdef void *libHandle

    # rules hash str embedded in bison parser lib
    cdef char *libHash

    def __init__(self, parser):
        """
        Creates a ParserEngine wrapper, and builds/loads the library.

        Arguments:
            - parser - an instance of a subclass of Parser

        In the course of initialisation, we check the library against the
        parser object's rules. If the lib doesn't exist, or can't be loaded, or
        doesn't match, we build a new library.

        Either way, we end up with a binary parser engine which matches the
        current rules in the parser object.
        """
        self.parser = parser

        self.libFilename_py = parser.buildDirectory \
                              + parser.bisonEngineLibName \
                              + imp.get_suffixes()[0][0]

        self.parserHash = hashParserObject(self.parser)

        self.openCurrentLib()

    def openCurrentLib(self):
        """
        Tests if library exists and is current. If not, builds a fresh one.

        Opens the library and imports the parser entry point.
        """
        parser = self.parser
        verbose = parser.verbose

        if not os.path.isfile(self.libFilename_py):
            self.buildLib()

        self.openLib()

        # hash our parser spec, compare to hash val stored in lib
        libHash = PyString_FromString(self.libHash)
        if self.parserHash != libHash:
            if verbose:
                print "Hash discrepancy, need to rebuild bison lib"
                print "  current parser class: %s" % self.parserHash
                print "         bison library: %s" % libHash
            self.closeLib()
            self.buildLib()
            self.openLib()
        else:
            if verbose:
                print "Hashes match, no need to rebuild bison engine lib"

    def openLib(self):
        """
        Loads the parser engine's dynamic library, and extracts the following
        symbols:

            - void *do_parse() (runs parser)
            - char *parserHash (contains hash of python parser rules)

        Returns lib handle, plus pointer to do_parse() function, as long ints
        (which later need to be cast to pointers)

        Important note -this is totally linux-specific.
        If you want windows support, you'll have to modify these funcs to
        use glib instead (or create windows equivalents), in which case I'd
        greatly appreciate you sending me a patch.
        """
        cdef char *libFilename
        cdef char *err
        cdef void *handle

        # convert python filename string to c string
        libFilename = PyString_AsString(self.libFilename_py)

        parser = self.parser

        if parser.verbose:
            print 'Opening library %s' % self.libFilename_py
        handle = bisondynlib_open(libFilename)
        self.libHandle = handle
        err = bisondynlib_err()
        if err:
            printf('ParserEngine.openLib: error "%s"\n', err)
            return

        # extract symbols
        self.libHash = bisondynlib_lookup_hash(handle)

        if parser.verbose:
            print 'Successfully loaded library'

    def buildLib(self):
        """
        Creates the parser engine lib

        This consists of:
            1. Ripping the tokens list, precedences, start target, handler docstrings
               and lex script from this Parser instance's attribs and methods
            2. Creating bison and lex files
            3. Compiling bison/lex files to C
            4. Compiling the C files, and link into a dynamic lib
        """
        cdef char *incdir

        # -------------------------------------------------
        # rip the pertinent grammar specs from parser class
        parser = self.parser

        # get target handler methods, in the order of appearance in the
        # source file.
        attribs = dir(parser)
        gHandlers = []

        for a in attribs:
            if a.startswith('on_'):
                method = getattr(parser, a)
                gHandlers.append(method)

        gHandlers.sort(cmpLines)

        # get start symbol, tokens, precedences, lex script
        gStart = parser.start
        gTokens = parser.tokens
        gPrecedences = parser.precedences
        gLex = parser.lexscript

        buildDirectory = parser.buildDirectory

        # ------------------------------------------------
        # now, can generate the grammar file
        if os.path.isfile(buildDirectory + parser.bisonFile):
            os.unlink(buildDirectory + parser.bisonFile)

        if parser.verbose:
            print 'generating bison file:', buildDirectory + parser.bisonFile

        f = open(buildDirectory + parser.bisonFile, "w")
        write = f.write
        writelines = f.writelines

        # grammar file prologue
        write("\n".join([
            "%{",
            '',
            '#include "Python.h"',
            "#include <stdio.h>",
            "extern FILE *yyin;",
            "extern int yylineno;"
            "extern char *yytext;",
            "#define YYSTYPE void*",
            #'extern void *py_callback(void *, char *, int, void*, ...);',
            'void *(*py_callback)(void *, char *, int, int, ...);',
            'void (*py_input)(void *, char *, int *, int);',
            'void *py_parser;',
            'char *rules_hash = "%s";' % self.parserHash,
            '',
            "%}",
            '',
            ]))

        # write out tokens and start target dec
        write("%%token %s\n\n" % " ".join(gTokens))
        write("%%start %s\n\n" % gStart)

        # write out precedences
        for p in gPrecedences:
            write("%%%s  %s\n" % (p[0], " ".join(p[1])))

        write("\n\n%%\n\n")

        # carve up docstrings
        rules = []
        for h in gHandlers:

            doc = h.__doc__.strip()

            # added by Eugene Oden
            #target, options = doc.split(":")
            doc = re.sub(unquoted % ";", "", doc)

            #print "---------------------"

            s = re.split(unquoted % ":", doc)
            #print "s=%s" % s

            target, options = s
            target = target.strip()

            options = options.strip()
            tmp = []

            #print "options = %s" % repr(options)
            opts = options.split("|")
            #print "opts = %s" % repr(opts)
            r = unquoted % r"\|"
            #print "r = <%s>" % r
            opts1 = re.split(r, " " + options)
            #print "opts1 = %s" % repr(opts1)

            for o in opts1:
                o = o.strip()

                tmp.append(reSpaces.split(o))
            options = tmp

            rules.append((target, options))

        # and render rules to grammar file
        for rule in rules:
            try:
                write("%s\n    : " % rule[0])
                options = []
                idx = 0
                for option in rule[1]:
                    nterms = len(option)
                    if nterms == 1 and option[0] == '':
                        nterms = 0
                        option = []
                    action = '\n        {\n'
                    if 'error' in option:
                        action = action + "             yyerrok;\n"
                    action = action + '          $$ = (*py_callback)(\n            py_parser, "%s", %s, %%s' % \
                             (rule[0], idx) # note we're deferring the substitution of 'nterms' (last arg)
                    args = []
                    if nterms == 0:
                        args.append('NULL')
                        i = -1
                    else:
                        for i in range(nterms):
                            if option[i] == '%prec':
                                i = i - 1
                                break # hack for rules using '%prec'
                            args.append('"%s", $%d' % (option[i], i+1))

                    # now, we have the correct terms count
                    action = action % (i + 1)

                    # assemble the full rule + action, ad to list
                    action = action + ",\n            "
                    action = action + ",\n            ".join(args) + "\n            );\n"

                    if 'error' in option:
                        action = action + "             PyObject_SetAttrString(py_parser, \"lasterror\", Py_None);\n"
                        action = action + "             Py_INCREF(Py_None);\n"
                        action = action + "             yyclearin;\n"

                    action = action + "          if ($$ && $$ != Py_None && PyObject_HasAttrString($$, \"_pyBisonError\"))\n"
                    action = action + "          {\n"
                    action = action + "             yyerror(PyString_AsString(PyObject_GetAttrString(py_parser, \"lasterror\")));\n"
                    action = action + "             Py_INCREF(Py_None);\n"
                    action = action + "             YYERROR;\n"
                    action = action + "          }\n"
                    action = action + "        }\n"
                    options.append(" ".join(option) + action)
                    idx = idx + 1
                write("    | ".join(options) + "    ;\n\n")
            except:
                traceback.print_exc()

        write("\n\n%%\n\n")

        # now generate C code
        epilogue = "\n".join([
            'void do_parse(void *parser1,',
            '              void *(*cb)(void *, char *, int, int, void *, ...),',
            '              void (*in)(void *, char*, int *, int),',
            '              int debug',
            '              )',
            '{',
            '   //printf("Not calling yyparse\\n");',
            '   //return;',
            '   py_callback = cb;',
            '   py_input = in;',
            "   py_parser = parser1;",
            "   yydebug = debug;",
            "   //yyin = stdin;",
            '   //printf("calling yyparse(), in=0x%lx\\n", py_input);',
            "   yyparse();",
            '   //printf("Back from parser\\n");',
            "}",
            "int yyerror(char *mesg)",
            "{",
            '  //printf("yytext=0x%lx\\n", yytext);',
            '  PyObject *args = PyTuple_New(3);',
            '  int ret;',
            '',
            '  PyTuple_SetItem(args, 0, PyInt_FromLong(yylineno+1));',
            '  PyTuple_SetItem(args, 1, PyString_FromString(mesg));',
            '  PyTuple_SetItem(args, 2, PyString_FromString(yytext));',
            '',
            '  ret = PyObject_SetAttrString((PyObject *)py_parser, "lasterror", args);',
            '  //printf("PyObject_SetAttrString: %d\\n", ret);',
            '',
            '  //printf("line %d: %s before %s\\n", yylineno+1, mesg, yytext);',
            "  //exit(0);",
            "}",
            ]) + "\n"
        write(epilogue)

        # done with grammar file
        f.close()

        # -----------------------------------------------
        # now generate the lex script
        if os.path.isfile(buildDirectory + parser.flexFile):
            os.unlink(buildDirectory + parser.flexFile)

        lexLines = gLex.split("\n")
        tmp = []
        for line in lexLines:
            tmp.append(line.strip())
        f = open(buildDirectory + parser.flexFile, "w")
        f.write("\n".join(tmp) + "\n")
        f.close()

        # create and set up a compiler object
        ccompiler = distutils.ccompiler.new_compiler(verbose=parser.verbose)
        ccompiler.set_include_dirs([distutils.sysconfig.get_python_inc()])

        # -----------------------------------------
        # Now run bison on the grammar file
        #os.system("bison -d tmp.y")
        bisonCmd = parser.bisonCmd + [buildDirectory + parser.bisonFile]

        if parser.verbose:
            print 'bison cmd:', ' '.join(bisonCmd)

        ccompiler.spawn(bisonCmd)

        if parser.verbose:
            print "renaming bison output files"
            print '%s => %s%s' % (parser.bisonCFile, buildDirectory,
                                  parser.bisonCFile1)
            print '%s => %s%s' % (parser.bisonHFile, buildDirectory,
                                  parser.bisonHFile1)

        if os.path.isfile(buildDirectory + parser.bisonCFile1):
            os.unlink(buildDirectory + parser.bisonCFile1)

        shutil.copy(parser.bisonCFile, buildDirectory + parser.bisonCFile1)

        if os.path.isfile(buildDirectory + parser.bisonHFile1):
            os.unlink(buildDirectory + parser.bisonHFile1)

        shutil.copy(parser.bisonHFile, buildDirectory + parser.bisonHFile1)

        # -----------------------------------------
        # Now run lex on the lex file
        #os.system("lex tmp.l")
        flexCmd = parser.flexCmd + [buildDirectory + parser.flexFile]

        if parser.verbose:
            print 'flex cmd:', ' '.join(flexCmd)

        ccompiler.spawn(flexCmd)

        if os.path.isfile(buildDirectory + parser.flexCFile1):
            os.unlink(buildDirectory + parser.flexCFile1)

        if parser.verbose:
            print '%s => %s%s' % (parser.flexCFile, buildDirectory,
                                  parser.flexCFile1)

        shutil.copy(parser.flexCFile, buildDirectory + parser.flexCFile1)

        # -----------------------------------------
        # Now compile the files into a shared lib

        # compile bison and lex c sources
        #bisonObj = ccompiler.compile([parser.bisonCFile1])
        #lexObj = ccompiler.compile([parser.flexCFile1])

        #cl /DWIN32 /G4 /Gs /Oit /MT /nologo /W3 /WX bisondynlib-win32.c /Id:\python23\include
        #cc.compile(['bisondynlib-win32.c'],
        #           extra_preargs=['/DWIN32', '/G4', '/Gs', '/Oit', '/MT', '/nologo', '/W3', '/WX', '/Id:\python23\include'])

        # link 'em into a shared lib
        objs = ccompiler.compile([buildDirectory + parser.bisonCFile1,
                                  buildDirectory + parser.flexCFile1],
                                 extra_preargs=parser.cflags_pre,
                                 extra_postargs=parser.cflags_post,
                                 debug=parser.debugSymbols)
        libFileName = buildDirectory + parser.bisonEngineLibName \
                      + imp.get_suffixes()[0][0]

        if os.path.isfile(libFileName+".bak"):
            os.unlink(libFileName+".bak")

        if os.path.isfile(libFileName):
            os.rename(libFileName, libFileName+".bak")

        if parser.verbose:
            print 'linking: %s => %s' % (', '.join(objs), libFileName)

        ccompiler.link_shared_object(objs, libFileName)

        #incdir = PyString_AsString(get_python_inc())
        #bisondynlib_build(self.libFilename_py, incdir)

        # --------------------------------------------
        # clean up, if we succeeded
        hitlist = objs[:]
        hitlist.append(buildDirectory + "tmp.output")

        if os.path.isfile(libFileName):
            for name in ['bisonFile', 'bisonCFile', 'bisonHFile',
                         'bisonCFile1', 'bisonHFile1', 'flexFile',
                         'flexCFile', 'flexCFile1',
                         ] + objs:
                if hasattr(parser, name):
                    fname = buildDirectory + getattr(parser, name)
                else:
                    fname = None
                #print "want to delete %s" % fname
                if fname and os.path.isfile(fname):
                    hitlist.append(fname)
        if not parser.keepfiles:
            for f in hitlist:
                try:
                    os.unlink(f)
                except:
                    print "Warning: failed to delete temporary file %s" % f

    def closeLib(self):
        """
        Does the necessary cleanups and closes the parser library
        """
        bisondynlib_close(self.libHandle)

    def runEngine(self, debug=0):
        """
        Runs the binary parser engine, as loaded from the lib
        """
        cdef void *handle

        cdef void *cbvoid
        cdef void *invoid

        handle = self.libHandle
        parser = self.parser

        cbvoid = <void *>py_callback
        invoid = <void *>py_input

        return bisondynlib_run(handle, parser, cbvoid, invoid, debug)

    def __del__(self):
        """
        Clean up and bail
        """
        self.closeLib()


def cmpLines(meth1, meth2):
    """
    Used as a sort() argument for sorting parse target handler methods by
    the order of their declaration in their source file.
    """
    try:
        line1 = meth1.func_code.co_firstlineno
        line2 = meth2.func_code.co_firstlineno
    except:
        line1 = meth1.__init__.func_code.co_firstlineno
        line2 = meth2.__init__.func_code.co_firstlineno

    return cmp(line1, line2)


def hashParserObject(parser):
    """
    Calculates an sha1 hex 'hash' of the lex script
    and grammar rules in a parser class instance.

    This is based on the raw text of the lex script attribute,
    and the grammar rule docstrings within the handler methods.

    Used to detect if someone has changed any grammar rules or
    lex script, and therefore, whether a shared parser lib rebuild
    is required.
    """
    hasher = sha.new()

    # add the lex script
    hasher.update(parser.lexscript)

    # add the tokens

    # workaround pyrex weirdness
    tokens = list(parser.tokens)
    hasher.update(",".join(list(parser.tokens)))

    # add the precedences
    for direction, tokens in parser.precedences:
        hasher.update(direction + "".join(tokens))

    # extract the parser target handler names
    handlerNames = dir(parser)

    #handlerNames = filter(lambda m: m.startswith('on_'), dir(parser))
    tmp = []
    for name in handlerNames:
        if name.startswith('on_'):
            tmp.append(name)
    handlerNames = tmp
    handlerNames.sort()

    # extract method objects, filter down to callables
    #handlers = [getattr(parser, m) for m in handlerNames]
    #handlers = filter(lambda h: callable(h), handlers)
    tmp = []
    for m in handlerNames:
        attr = getattr(parser, m)
        if callable(attr):
            tmp.append(attr)
    handlers = tmp

    # now add in the methods' docstrings
    for h in handlers:
        docString = h.__doc__
        hasher.update(docString)

    # done
    return hasher.hexdigest()
