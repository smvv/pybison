"""
Module for converting a bison file to a PyBison-python file.

Written April 2004 by David McNab <david@freenet.org.nz>
Copyright (c) 2004 by David McNab, all rights reserved.

Released under the GNU General Public License, a copy of which should appear in
this distribution in the file called 'COPYING'. If this file is missing, then
you can obtain a copy of the GPL license document from the GNU website at
http://www.gnu.org.

This software is released with no warranty whatsoever. Use it at your own
risk.

If you wish to use this software in a commercial application, and wish to
depart from the GPL licensing requirements, please contact the author and apply
for a commercial license.
"""
import re
import os

from bison_ import unquoted


reSpaces = re.compile('\\s+')


def bisonToPython(bisonfileName, lexfileName, pyfileName, generateClasses=0):
    """
    Rips the rules, tokens and precedences from a bison file, and the verbatim
    text from a lex file and generates a boilerplate python file containing a
    Parser class with handler methods and grammar attributes.

    Arguments:
     * bisonfileName - name of input bison script
     * lexfileName - name of input flex script
     * pyfileName - name of output python file
     * generateClasses - flag - default 0 - if 1, causes a unique class to
       be defined for each parse target, and for the corresponding target
       handler method in the main Parser class to use this class when creating
       the node.
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
    rulesLines = filter(lambda s: s != '', map(str.strip, re.split(unquoted % ';', rulesRaw)))

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
        'from bison import BisonParser, BisonNode #, BisonError',
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
            if target[0].lower() in ['a', 'e', 'i', 'o', 'u']:
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
        '    bisonEngineLibName = \'%s\'' % libfileName,
        '\n',
        ]))

    # add the tokens
    #pyfile.write('    tokens = (%s,)\n\n' % ', '.join([''%s'' % t for t in tokens]))
    #toks = ', '.join(tokens)

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
        #precline = ', '.join(prec[1])
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
            '            target=\'%s\',' % target,
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
