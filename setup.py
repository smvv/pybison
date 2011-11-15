#@+leo-ver=4
#@+node:@file setup.py
"""
Builds bison python module
"""

version = "0.1"

from distutils.core import setup
from distutils.extension import Extension
from Pyrex.Distutils import build_ext

import sys

if sys.platform == 'win32':
    print "Sorry - no windows support at this time - pybison won't work for you"
    #sys.exit(1)
    libs = []
    extra_link_args = []
    bison2pyscript = 'utils/bison2py.py'
    bisondynlibModule = "src/c/bisondynlib-win32.c"
elif sys.platform == 'linux2':
    libs = ['dl']
    extra_link_args = []
    bison2pyscript = 'utils/bison2py'
    bisondynlibModule = "src/c/bisondynlib-linux.c"
else:
    print "Sorry, your platform is presently unsupported"
    sys.exit(1)

setup(
  name = "bison",
  version = version,
  description='Python bindings for bison/flex parser engine',
  author='David McNab <david@freenet.org.nz>',
  url='http://www.freenet.org.nz/python/pybison',
  ext_modules=[ 
    Extension("bison_", ["src/pyrex/bison_.pyx", bisondynlibModule],
              libraries=libs,
              extra_link_args=extra_link_args,
              )
    ],
  packages=[],
  package_dir={'': 'src/python'},
  py_modules=['bison'],
  cmdclass = {'build_ext': build_ext},
  scripts=[bison2pyscript],
)


#@-node:@file setup.py
#@-leo
