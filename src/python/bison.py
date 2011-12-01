#@+leo-ver=4
#@+node:@file src/python/bison.py
"""
Wrapper module for interfacing with Bison (yacc)

Written April 2004 by David McNab <david@freenet.org.nz>
Copyright (c) 2004 by David McNab, all rights reserved.

Released under the GNU General Public License, a copy
of which should appear in this distribution in the file
called 'COPYING'. If this file is missing, then you can
obtain a copy of the GPL license document from the GNU
website at http://www.gnu.org.

This software is released with no warranty whatsoever.
Use it at your own risk.

If you wish to use this software in a commercial application,
and wish to depart from the GPL licensing requirements,
please contact the author and apply for a commercial license.
"""
import sys
import os
import sha
import re
import imp
import traceback
import xml.dom
import xml.dom.minidom
import types
import distutils.sysconfig
import distutils.ccompiler

from bison_ import ParserEngine, unquoted

reSpaces = re.compile('\\s+')


class ParserSyntaxError(Exception):
    pass


class TimeoutError(Exception):
    pass


class BisonError:
    """
    Flags an error to yyparse()

    You should return this in your actions to notify a syntax error
    """
    _pyBisonError = 1

    def __init__(self, value='syntax error'):
        self.value = value


class BisonNode:
    """
    Generic class for wrapping parse targets.

    Arguments:
        - targetname - the name of the parse target being wrapped.
        - items - optional - a list of items comprising a clause
          in the target rule - typically this will only be used
          by the PyBison callback mechanism.

    Keywords:
        - any keywords you want (except 'items'), with any type of value.
          keywords will be stored as attributes in the constructed object.
    """

    def __init__(self, **kw):

        self.__dict__.update(kw)

        # ensure some default attribs
        self.target = kw.get('target', 'UnnamedTarget')
        self.names = kw.get('names', [])
        self.values = kw.get('values', [])
        self.option = kw.get('option', 0)

        # mirror this dict to simplify dumping
        self.kw = kw

    def __str__(self):
        return '<BisonNode:%s>' % self.target

    def __repr__(self):
        return str(self)

    def __getitem__(self, item):
        """
        Retrieves the ith value from this node, or child nodes

        If the subscript is a single number, it will be used as an
        index into this node's children list.

        If the subscript is a list or tuple, we recursively fetch
        the item by using the first element as an index into this
        node's children, the second element as an index into that
        child node's children, and so on
        """
        if type(item) in [type(0), type(0L)]:
            return self.values[item]
        elif type(item) in [type(()), type([])]:
            if len(item) == 0:
                return self
            return self.values[item[0]][item[1:]]
        else:
            raise TypeError('Can only index %s objects with an int or a'
                            ' list/tuple' % self.__class.__name__)

    def __len__(self):

        return len(self.values)

    def __getslice__(self, fromidx, toidx):
        return self.values[fromidx:toidx]

    def __iter__(self):
        return iter(self.values)

    def dump(self, indent=0):
        """
        For debugging - prints a recursive dump of a parse tree node and its children
        """
        specialAttribs = ['option', 'target', 'names', 'values']
        indents = ' ' * indent * 2
        #print "%s%s: %s %s" % (indents, self.target, self.option, self.names)
        print '%s%s:' % (indents, self.target)

        for name, val in self.kw.items() + zip(self.names, self.values):
            if name in specialAttribs or name.startswith('_'):
                continue

            if isinstance(val, BisonNode):
                val.dump(indent+1)
            else:
                print indents + '  %s=%s' % (name, val)

    def toxml(self):
        """
        Returns an xml serialisation of this node and its children, as a raw string

        Called on the toplevel node, the xml is a representation of the
        entire parse tree.
        """
        return self.toxmldoc().toxml()

    def toprettyxml(self, indent='  ', newl='\n', encoding=None):
        """
        Returns a human-readable xml serialisation of this node and its
        children.
        """
        return self.toxmldoc().toprettyxml(indent=indent,
                                           newl=newl,
                                           encoding=encoding)

    def toxmldoc(self):
        """
        Returns the node and its children as an xml.dom.minidom.Document
        object.
        """
        d = xml.dom.minidom.Document()
        d.appendChild(self.toxmlelem(d))
        return d

    def toxmlelem(self, docobj):
        """
        Returns a DOM Element object of this node and its children.
        """
        specialAttribs = ['option', 'target', 'names', 'values']

        # generate an xml element obj for this node
        x = docobj.createElement(self.target)

        # set attribs
        for name, val in self.kw.items():
            if name in ['names', 'values'] or name.startswith('_'):
                continue

            x.setAttribute(name, str(val))
        #x.setAttribute('target', self.target)
        #x.setAttribute('option', self.option)

        # and add the children
        for name, val in zip(self.names, self.values):
            if name in specialAttribs or name.startswith('_'):
                continue

            if isinstance(val, BisonNode):
                x.appendChild(val.toxmlelem(docobj))
            else:
                sn = docobj.createElement(name)
                sn.setAttribute('target', name)
                tn = docobj.createTextNode(val)
                sn.appendChild(tn)
                x.appendChild(sn)

        # done
        return x


class BisonParser(object):
    """
    Base parser class

    You should subclass this, and provide a bunch of methods called
    'on_TargetName', where 'TargetName' is the name of each target in
    your grammar (.y) file.
    """
    # ---------------------------------------
    # override these if you need to

    # command and options for running yacc/bison, except for filename arg
    bisonCmd = ['bison', '-d', '-v', '-t']

    bisonFile = 'tmp.y'
    bisonCFile = 'tmp.tab.c'
    bisonHFile = 'tmp.tab.h' # name of header file generated by bison cmd

    bisonCFile1 = 'tmp.bison.c' # c output file from bison gets renamed to this
    bisonHFile1 = 'tokens.h' # bison-generated header file gets renamed to this

    flexCmd = ['flex', ] # command and options for running [f]lex, except for filename arg
    flexFile = 'tmp.l'
    flexCFile = 'lex.yy.c'

    flexCFile1 = 'tmp.lex.c' # c output file from lex gets renamed to this

    cflags_pre = ['-fPIC']  # = CFLAGS added before all arguments.
    cflags_post = ['-O3','-g']  # = CFLAGS added after all arguments.

    buildDirectory = './' # Directory used to store the generated / compiled files.
    debugSymbols = 1  # Add debugging symbols to the binary files.

    verbose = 0

    timeout = 1  # Timeout in seconds after which a computation is terminated.

    file = None # default to sys.stdin

    last = None # last parsed target, top of parse tree

    lasterror = None # gets set if there was an error

    keepfiles = 0 # set to 1 to keep temporary engine build files

    bisonEngineLibName = None # defaults to 'modulename-engine'

    defaultNodeClass = BisonNode # class to use by default for creating new parse nodes

    def __init__(self, **kw):
        """
        Abstract representation of parser

        Keyword arguments:
            - read - a callable accepting an int arg (nbytes) and returning a string,
              default is this class' read() method
            - file - a file object, or string of a pathname to open as a file, defaults
              to sys.stdin. Note that you can leave this blank, and pass a file keyword
              argument to the .run() method.
            - verbose - set to 1 to enable verbose output messages, default 0
            - keepfiles - if non-zero, keeps any files generated in the
              course of building the parser engine; by default, all these
              files get deleted upon a successful engine build
            - defaultNodeClass - the class to use for creating parse nodes, default
              is self.defaultNodeClass (in this base class, BisonNode)
        """
        # setup
        read = kw.get('read', None)
        if read:
            self.read = read

        fileobj = kw.get('file', None)
        if fileobj:
            if isinstance(fileobj, str):
                try:
                    fileobj = open(fileobj, 'rb')
                except:
                    raise Exception('Cannot open input file %s' % fileobj)
            self.file = fileobj
        else:
            self.file = sys.stdin

        nodeClass = kw.get('defaultNodeClass', None)
        if nodeClass:
            self.defaultNodeClass = nodeClass

        self.verbose = kw.get('verbose', 0)

        if kw.has_key('keepfiles'):
            self.keepfiles = kw['keepfiles']

        # if engine lib name not declared, invent ont
        if not self.bisonEngineLibName:
            self.bisonEngineLibName = self.__class__.__module__ + '-parser'

        # get an engine
        self.engine = ParserEngine(self)

    def __getitem__(self, idx):
        return self.last[idx]

    def _handle(self, targetname, option, names, values):
        """
        Callback which receives a target from parser, as a targetname
        and list of term names and values.

        Tries to dispatch to on_TargetName() methods if they exist,
        otherwise wraps the target in a BisonNode object
        """
        handler = getattr(self, 'on_'+targetname, None)
        if handler:
            if self.verbose:
                try:
                    hdlrline = handler.func_code.co_firstlineno
                except:
                    hdlrline = handler.__init__.func_code.co_firstlineno

                print 'BisonParser._handle: call handler at line %s with: %s' \
                      % (hdlrline, str((targetname, option, names, values)))

            try:
                self.last = handler(target=targetname, option=option, names=names,
                                    values=values)
            except Exception as e:
                self.lasterror = e
                print type(e), str(e)
                #traceback.print_last()
                #traceback.print_stack()
                traceback.print_stack()
                raise

            #if self.verbose:
            #    print 'handler for %s returned %s' \
            #          % (targetname, repr(self.last))
        else:
            if self.verbose:
                print 'no handler for %s, using default' % targetname
            self.last = BisonNode(targetname, option=option, names=names, values=values)

        # reset any resulting errors (assume they've been handled)
        if self.lasterror:
            print 'lasterror:', self.lasterror
        #self.lasterror = None

        # assumedly the last thing parsed is at the top of the tree
        return self.last

    def handle_timeout(self, signum, frame):
        raise TimeoutError('Computation exceeded timeout limit.')

    def run(self, **kw):
        """
        Runs the parser, and returns the top-most parse target.

        Keywords:
            - file - either a string, comprising a file to open and read input from, or
              a Python file object
            - debug - enables garrulous parser debugging output, default 0
        """
        if self.verbose:
            print 'Parser.run: calling engine'

        # grab keywords
        fileobj = kw.get('file', self.file)
        if isinstance(fileobj, str):
            filename = fileobj
            try:
                fileobj = open(fileobj, 'rb')
            except:
                raise Exception('Cannot open input file "%s"' % fileobj)
        else:
            filename = None
            fileobj = None

        read = kw.get('read', self.read)

        debug = kw.get('debug', 0)

        # back up existing attribs
        oldfile = self.file
        oldread = self.read

        # plug in new ones, if given
        if fileobj:
            self.file = fileobj
        if read:
            self.read = read

        # do the parsing job, spew if error
        self.lasterror = None
        self.engine.runEngine(debug)

        if self.lasterror:
            if filename != None:
                raise ParserSyntaxError('%s:%d: "%s" near "%s"' 
                                        % ((filename,) + self.lasterror))
            else:
                raise ParserSyntaxError('Line %d: "%s" near "%s"' 
                                        % self.lasterror)

        # restore old values
        self.file = oldfile
        self.read = oldread

        if self.verbose:
            print 'Parser.run: back from engine'

        return self.last

    def read(self, nbytes):
        """
        Override this in your subclass, if you desire.

        Arguments:
            - nbytes - the maximum length of the string which you may return.
              DO NOT return a string longer than this, or else Bad Things will
              happen.
        """
        # default to stdin
        if self.verbose:
            print 'Parser.read: want %s bytes' % nbytes

        bytes = self.file.readline(nbytes)

        if self.verbose:
            print 'Parser.read: got %s bytes' % len(bytes)

        return bytes

    def _error(self, linenum, msg, tok):

        print 'Parser: line %s: syntax error "%s" before "%s"' \
              % (linenum, msg, tok)

    def error(self, value):
        """
        Return the result of this method from a handler to notify a syntax error
        """
        self.lasterror = value
        return BisonError(value)

    def toxml(self):
        """
        Serialises the parse tree and returns it as a raw xml string
        """
        return self.last.toxml()

    def toxmldoc(self):
        """
        Returns an xml.dom.minidom.Document object containing the parse tree
        """
        return self.last.toxmldoc()

    def toprettyxml(self):
        """
        Returns a human-readable xml representation of the parse tree
        """
        return self.last.toprettyxml()

    def loadxml(self, raw, namespace=None):
        """
        Loads a parse tree from raw xml text

        Stores it in the '.last' attribute, which is where the root node
        of parsed text gets stored

        Arguments:
            - raw - string containing the raw xml
            - namespace - a dict or module object, where the node classes required for
              reconstituting the parse tree, can be found

        Returns:
            - root node object of reconstituted parse tree
        """
        doc = xml.dom.minidom.parseString(raw)
        tree = self.loadxmldoc(doc, namespace)
        self.last = tree
        return tree

    def loadxmldoc(self, xmldoc, namespace=None):
        """
        Returns a reconstituted parse tree, loaded from an
        xml.dom.minidom.Document instance

        Arguments:
            - xmldoc - an xml.dom.minidom.Document instance
            - namespace - a dict from which to find the classes needed
              to translate the document into a tree of parse nodes
        """
        return self.loadxmlobj(xmldoc.childNodes[0], namespace)

    def loadxmlobj(self, xmlobj, namespace=None):
        """
        Returns a node object, being a parse tree, reconstituted from an
        xml.dom.minidom.Element object

        Arguments:
            - xmlobj - an xml.dom.minidom.Element instance
            - namespace - a namespace from which the node classes
              needed for reconstituting the tree, can be found
        """
        # check on namespace
        if type(namespace) is types.ModuleType:
            namespace = namespace.__dict__
        elif namespace == None:
            namespace = globals()

        objname = xmlobj.tagName
        classname = objname + '_Node'
        classobj = namespace.get(classname, None)

        namespacekeys = namespace.keys()

        # barf if node is not a known parse node or token
        if (not classobj) and objname not in self.tokens:
            raise Exception('Cannot reconstitute %s: can\'t find required'
                    ' node class or token %s' % (objname, classname))

        if classobj:
            nodeobj = classobj()

            # add the attribs
            for k,v in xmlobj.attributes.items():
                setattr(nodeobj, k, v)
        else:
            nodeobj = None

        #print '----------------'
        #print 'objname=%s' % repr(objname)
        #print 'classname=%s' % repr(classname)
        #print 'classobj=%s' % repr(classobj)
        #print 'nodeobj=%s' % repr(nodeobj)

        # now add the children
        for child in xmlobj.childNodes:
            #print '%s attributes=%s' % (child, child.attributes.items())
            childname = child.attributes['target'].value
            #print 'childname=%s' % childname
            if childname + '_Node' in namespacekeys:
                #print 'we have a node for class %s' % classname
                childobj = self.loadxmlobj(child, namespace)
            else:
                # it's a token
                childobj = child.childNodes[0].nodeValue
                #print 'got token %s=%s' % (childname, childobj)

            nodeobj.names.append(childname)
            nodeobj.values.append(childobj)

        return nodeobj

    def _globals(self):
        return globals().keys()

def bisonToPython(bisonfileName, lexfileName, pyfileName, generateClasses=0):
    """
    Rips the rules, tokens and precedences from a bison file, and the verbatim
    text from a lex file and generates a boilerplate python file containing a
    Parser class with handler methods and grammar attributes.

    Arguments:
        - bisonfileName - name of input bison script
        - lexfileName - name of input flex script
        - pyfileName - name of output python file
        - generateClasses - flag - default 0 - if 1, causes a unique class to
          be defined for each parse target, and for the corresponding target
          handler method in the main Parser class to use this class when
          creating the node.
    """
    # try to create output file
    try:
        pyfile = file(pyfileName, 'w')
    except:
        raise Exception('Cannot create output file "%s"' % pyfileName)

    # try to open/read the bison file
    try:
        rawBison = file(bisonfileName).read()
    except:
        raise Exception('Cannot open bison file "%s"' % bisonfileName)

    # try to open/read the lex file
    try:
        rawLex = file(lexfileName).read()
    except:
        raise Exception('Cannot open lex file %s' % lexfileName)

    # break up into the three '%%'-separated sections
    try:
        prologue, rulesRaw, epilogue = rawBison.split('\n%%\n')
    except:
        raise Exception(
            'File %s is not a properly formatted bison file'
            ' (needs 3 sections separated by %%%%' % (bisonfileName)
            )

    # --------------------------------------
    # process prologue

    prologue = prologue.split('%}')[-1].strip() # ditch the C code
    prologue = re.sub('\\n([\t ]+)', ' ', prologue) # join broken lines

    #prologueLines = [line.strip() for line in prologue.split('\n')]
    lines = prologue.split('\n')
    tmp = []

    for line in lines:
        tmp.append(line.strip())

    prologueLines = tmp

    prologueLines = filter(None, prologueLines)
    tokens = []
    precRules = []

    for line in prologueLines:
        words = reSpaces.split(line)
        kwd = words[0]
        args = words[1:]

        if kwd == '%token':
            tokens.extend(args)
        elif kwd in ['%left', '%right', '%nonassoc']:
            precRules.append((kwd, args))
        elif kwd == '%start':
            startTarget = args[0]

    # -------------------------------------------------------------
    # process rules
    rulesRaw = re.sub('\\n([\t ]+)', ' ', rulesRaw) # join broken lines
    rulesLines = filter('', map(str.strip, re.split(unquoted % ';', rulesRaw)))

    rules = []
    for rule in rulesLines:
        #print '--'
        #print repr(rule)

        #tgt, terms = rule.split(':')
        try:
            tgt, terms = re.split(unquoted % ':', rule)
        except ValueError:
            print 'Error in rule: %s' % rule
            raise

        tgt, terms = tgt.strip(), terms.strip()

        #terms = [t.strip() for t in terms.split('|')]
        #terms = [reSpaces.split(t) for t in terms]

        tmp = []
        #for t in terms.split('|'):
        for t in re.split(unquoted % r'\|', terms):

            t = t.strip()
            tmp.append(reSpaces.split(t))
        terms = tmp

        rules.append((tgt, terms))

    # now we have our rulebase, we can churn out our skeleton Python file
    pyfile.write('\n'.join([
        '#!/usr/bin/env python',
        '',
        '"""',
        'PyBison file automatically generated from grammar file %s' % bisonfileName,
        'You can edit this module, or import it and subclass the Parser class',
        '"""',
        '',
        'import sys',
        '',
        'from bison import BisonParser, BisonNode, BisonError',
        '',
        'bisonFile = \'%s\'  # original bison file' % bisonfileName,
        'lexFile = \'%s\'    # original flex file' % lexfileName,
        '\n',
        ]))

    # if generating target classes
    if generateClasses:
        # create a base class for all nodes
        pyfile.write("\n".join([
            'class ParseNode(BisonNode):',
            '    """',
            '    This is the base class from which all your',
            '    parse nodes are derived.',
            '    Add methods to this class as you need them',
            '    """',
            '    def __init__(self, **kw):',
            '        BisonNode.__init__(self, **kw)',
            '',
            '    def __str__(self):',
            '        """Customise as needed"""',
            '        return \'<%s instance at 0x%x>\' % (self.__class__.__name__, hash(self))',
            '',
            '    def __repr__(self):',
            '        """Customise as needed"""',
            '        return str(self)',
            '',
            '    def dump(self, indent=0):',
            '        """',
            '        Dump out human-readable, indented parse tree',
            '        Customise as needed - here, or in the node-specific subclasses',
            '        """',
            '        BisonNode.dump(self, indent) # alter as needed',
            '\n',
            '# ------------------------------------------------------',
            '# Define a node class for each grammar target',
            '# ------------------------------------------------------',
            '\n',
            ]))

        # now spit out class decs for every parse target
        for target, options in rules:
            tmp = map(' '.join, options)

            # totally self-indulgent grammatical pedantry
            if target[0].lower() in ['a','e','i','o','u']:
                plural = 'n'
            else:
                plural = ''

            pyfile.write("\n".join([
                'class %s_Node(ParseNode):' % target,
                '    """',
                '    Holds a%s "%s" parse target and its components.' % (plural, target),
                '    """',
                '    def __init__(self, **kw):',
                '        ParseNode.__init__(self, **kw)',
                '',
                '    def dump(self, indent=0):',
                '        ParseNode.dump(self, indent)',
                '\n',
                ]))


    # start churning out the class dec
    pyfile.write('\n'.join([
        'class Parser(BisonParser):',
        '    """',
        '    bison Parser class generated automatically by bison2py from the',
        '    grammar file "%s" and lex file "%s"' % (bisonfileName, lexfileName),
        '',
        '    You may (and probably should) edit the methods in this class.',
        '    You can freely edit the rules (in the method docstrings), the',
        '    tokens list, the start symbol, and the precedences.',
        '',
        '    Each time this class is instantiated, a hashing technique in the',
        '    base class detects if you have altered any of the rules. If any',
        '    changes are detected, a new dynamic lib for the parser engine',
        '    will be generated automatically.',
        '    """',
        '\n',
        ]))

    # add the default node class
    if not generateClasses:
        pyfile.write('\n'.join([
            '    # -------------------------------------------------',
            '    # Default class to use for creating new parse nodes',
            '    # -------------------------------------------------',
            '    defaultNodeClass = BisonNode',
            '\n',
            ]))

    # add the name of the dynamic library we need
    libfileName = os.path.splitext(os.path.split(pyfileName)[1])[0] \
                  + '-engine'

    pyfile.write('\n'.join([
        '    # --------------------------------------------',
        '    # basename of binary parser engine dynamic lib',
        '    # --------------------------------------------',
        '    bisonEngineLibName = \'%s\'' % (parser.buildDirectory + libfileName),
        '\n',
        ]))

    # add the tokens
    #pyfile.write('    tokens = (%s,)\n\n' % ', '.join([''%s'' % t for t in tokens]))
    toks = ', '.join(tokens)

    pyfile.write('    # ----------------------------------------------------------------\n')
    pyfile.write('    # lexer tokens - these must match those in your lex script (below)\n')
    pyfile.write('    # ----------------------------------------------------------------\n')
    pyfile.write('    tokens = %s\n\n' % tmp)

    # add the precedences
    pyfile.write('    # ------------------------------\n')
    pyfile.write('    # precedences\n')
    pyfile.write('    # ------------------------------\n')
    pyfile.write('    precedences = (\n')
    for prec in precRules:
        precline = ', '.join(prec[1])
        pyfile.write('        (\'%s\', %s,),\n' % (
                prec[0][1:], # left/right/nonassoc, quote-wrapped, no '%s'
                tmp,  # quote-wrapped targets
                )
            )
    pyfile.write('        )\n\n'),

    pyfile.write('\n'.join([
        '    # ---------------------------------------------------------------',
        '    # Declare the start target here (by name)',
        '    # ---------------------------------------------------------------',
        '    start = \'%s\'' % startTarget,
        '\n',
        ]))

    # now the interesting bit - write the rule handler methods
    pyfile.write('\n'.join([
        '    # ---------------------------------------------------------------',
        '    # These methods are the python handlers for the bison targets.',
        '    # (which get called by the bison code each time the corresponding',
        '    # parse target is unambiguously reached)',
        '    #',
        '    # WARNING - don\'t touch the method docstrings unless you know what',
        '    # you are doing - they are in bison rule syntax, and are passed',
        '    # verbatim to bison to build the parser engine library.',
        '    # ---------------------------------------------------------------',
        '\n',
        ]))

    for target, options in rules:
        tmp = map(' '.join, options)

        if generateClasses:
            nodeClassName = target + '_Node'
        else:
            nodeClassName = 'self.defaultNodeClass'

        pyfile.write('\n'.join([
            '    def on_%s(self, target, option, names, values):' % target,
            '        """',
            '        %s' % target,
            '            : ' + '\n            | '.join(tmp),
            '        """',
            '        return %s(' % nodeClassName,
            '            target=\'%s\','  % target,
            '            option=option,',
            '            names=names,',
            '            values=values)',
            '\n',
            ]))

    # now the ugly bit - add the raw lex script
    pyfile.write('\n'.join([
        '    # -----------------------------------------',
        '    # raw lex script, verbatim here',
        '    # -----------------------------------------',
        '    lexscript = r"""',
        rawLex,
        '    """',
        '    # -----------------------------------------',
        '    # end raw lex script',
        '    # -----------------------------------------',
        '',
        '',
        ]))

    # and now, create a main for testing which either reads stdin, or a filename arg
    pyfile.write('\n'.join([
        'def usage():',
        '    print \'%s: PyBison parser derived from %s and %s\' % (sys.argv[0], bisonFile, lexFile)',
        '    print \'Usage: %s [-k] [-v] [-d] [filename]\' % sys.argv[0]',
        '    print \'  -k       Keep temporary files used in building parse engine lib\'',
        '    print \'  -v       Enable verbose messages while parser is running\'',
        '    print \'  -d       Enable garrulous debug messages from parser engine\'',
        '    print \'  filename path of a file to parse, defaults to stdin\'',
        '',
        'def main(*args):',
        '    """',
        '    Unit-testing func',
        '    """',
        '',
        '    keepfiles = 0',
        '    verbose = 0',
        '    debug = 0',
        '    filename = None',
        '',
        '    for s in [\'-h\', \'-help\', \'--h\', \'--help\', \'-?\']:',
        '        if s in args:',
        '            usage()',
        '            sys.exit(0)',
        '',
        '    if len(args) > 0:',
        '        if \'-k\' in args:',
        '            keepfiles = 1',
        '            args.remove(\'-k\')',
        '        if \'-v\' in args:',
        '            verbose = 1',
        '            args.remove(\'-v\')',
        '        if \'-d\' in args:',
        '            debug = 1',
        '            args.remove(\'-d\')',
        '    if len(args) > 0:',
        '        filename = args[0]',
        '',
        '    p = Parser(verbose=verbose, keepfiles=keepfiles)',
        '    tree = p.run(file=filename, debug=debug)',
        '    return tree',
        '',
        'if __name__ == \'__main__\':',
        '    main(*(sys.argv[1:]))',
        '',
        '',
        ]))
