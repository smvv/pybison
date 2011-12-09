"""
Generic module for wrapping parse targets.

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
import xml

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
                val.dump(indent + 1)
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



