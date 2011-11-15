Welcome to PyBison

Bringing GNU Bison/Flex's raw speed and power to Python

1) What is PyBison?

PyBison is a framework which effectively 'wraps' Bison and Flex into a Python
class structure.

You define a parser class, define tokens and precedences as attributes,
and parse targets as methods with rules in the docstrings,
then instantiate and run.

Black Magick happens in the background, whereupon you get callbacks each
time yyparse() resolves a parse target.

2) There are already parsers for Python. Why re-invent the wheel?

I looked at all the Python-based parsing frameworks.

IMO, the best one was PLY - a pure-python lexx/yacc implementation
(which I have borrowed from heavily in designing PyBison's OO model).

But PLY suffers some major limitations:

 * usage of 'named groups' regular expressions in the lexer creates
   a hard limit of 100 tokens - not enough to comfortably handle major
   languages
 
 * pure-python implementation is a convenience, but incurs a cruel
   performance penalty

 * the parser engine is SLR, not full LALR(1)

The other frameworks utilise a fiddly script syntax - 
   
3) How do I use this?

Refer to the INSTALL file for setting up.
Refer to the examples and the doco for usage.
