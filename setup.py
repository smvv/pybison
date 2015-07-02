"""
Builds bison python module
"""

version = '0.1'

from distutils.core import setup
from distutils.extension import Extension
from Pyrex.Distutils import build_ext

import sys

if sys.platform == 'win32':
    print 'No windows support at this time. PyBison won\'t work for you :('
    libs = []
    extra_link_args = []
    bison2pyscript = 'utils/bison2py.py'
    bisondynlibModule = 'src/c/bisondynlib-win32.c'
elif sys.platform == 'linux2':
    libs = ['dl']
    extra_link_args = []
    bison2pyscript = 'utils/bison2py'
    bisondynlibModule = 'src/c/bisondynlib-linux.c'
else:
    print 'Sorry, your platform is presently unsupported.'
    sys.exit(1)

setup(
        name='bison',
        version=version,
        description='Python bindings for bison/flex parser engine',
        author='David McNab <david@freenet.org.nz>',
        url='http://www.freenet.org.nz/python/pybison',
        ext_modules=[
            Extension('bison_', [
                    'src/pyrex/bison_.pyx',
                    'src/c/bison_callback.c',
                    bisondynlibModule],
                libraries=libs,
                extra_link_args=extra_link_args,
                )
            ],
        packages=['bison'],
        package_dir={'bison': 'src/python'},
        #py_modules=['node', 'xmlifier', 'convert'],
        cmdclass={'build_ext': build_ext},
        scripts=[bison2pyscript],
        )
