#!/usr/bin/env python
"""
Utility which creates a boilerplate pybison-compatible
python file from a yacc file and lex file

Run it with 2 arguments - filename.y and filename.l
Output is filename.py
"""
import sys

from bison import bisonToPython


def usage(s=None):
    """
    Display usage info and exit
    """
    progname = sys.argv[0]

    if s:
        print progname + ': ' + s

    print '\n'.join([
        'Usage: %s [-c] basefilename' % progname,
        '   or: %s [-c] grammarfile.y lexfile.l pyfile.py' % progname,
        '(generates a boilerplate python file from a grammar and lex file)',
        'The first form uses "basefilename" as base for all files, so:',
        '  %s fred' % progname,
        'is equivalent to:',
        '  %s fred.y fred.l fred.py' % progname,
        '',
        'The "-c" argument causes the creation of a unique node class',
        'for each parse target - highly recommended for complex grammars',
        ])

    sys.exit(1)


def main():
    """
    Command-line interface for bison2py
    """
    argv = sys.argv
    argc = len(argv)

    if '-c' in argv:
        generateClasses = 1
        argv.remove('-c')
        argc = argc - 1
    else:
        generateClasses = 0

    if argc == 2:
        basename = argv[1]
        bisonfile = basename + '.y'
        lexfile = basename + '.l'
        pyfile = basename + '.py'
    elif argc == 4:
        bisonfile, lexfile, pyfile = argv[1:4]
    else:
        usage('Bad argument count')

    bisonToPython(bisonfile, lexfile, pyfile, generateClasses)


if __name__ == '__main__':
    main()
