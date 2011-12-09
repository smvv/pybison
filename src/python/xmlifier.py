"""
Wrapper module for importing and exporting bison grammar from/to XML.

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

# TODO: use cElementTree instead of Python's xml module.
# TODO: test this module, since it is currently only moved to another file.

import xml.dom
import xml.dom.minidom
import types

class XMLifier(object):

    def __init__(self, parser):
        self.parser = parser

    def toxml(self):
        """
        Serialises the parse tree and returns it as a raw xml string
        """
        return self.parser.last.toxml()

    def toxmldoc(self):
        """
        Returns an xml.dom.minidom.Document object containing the parse tree
        """
        return self.parser.last.toxmldoc()

    def toprettyxml(self):
        """
        Returns a human-readable xml representation of the parse tree
        """
        return self.parser.last.toprettyxml()

    def loadxml(self, raw, namespace=None):
        """
        Loads a parse tree from raw xml text.

        Arguments:
            - raw - string containing the raw xml
            - namespace - a dict or module object, where the node classes required for
              reconstituting the parse tree, can be found

        Returns:
            - root node object of reconstituted parse tree
        """
        doc = xml.dom.minidom.parseString(raw)
        tree = self.loadxmldoc(doc, namespace)
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
            for k, v in xmlobj.attributes.items():
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
