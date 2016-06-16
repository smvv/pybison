#!/usr/bin/env python

import sys

sys.path.insert(0, '../../build/lib.linux-x86_64-2.7/')

import calc

parser = calc.Parser(verbose=1, keepfiles=0)
parser.run()
