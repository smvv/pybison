#!/usr/bin/env python
"""
Runs the java parser on a small java source file
"""
import sys

import javaparser

#src = "tst.java"

argv = sys.argv
argc = len(argv)

if '-v' in argv:
    argv.remove('-v')
    argc -= 1
    verbose = 1
else:
    verbose = 0

if argc == 2:
    src = argv[1]
else:
    src = None

src = "I2PClient.java"

p = javaparser.Parser(verbose=verbose)

print "delmebld.py: running parser on HelloWorldApp.java"
res = p.run(file=src)
print "back from engine, parse tree dump follows:"
if 0:
    print "------------------------------------------"
    res.dump()
    print "------------------------------------------"
    print "end of parse tree dump"

