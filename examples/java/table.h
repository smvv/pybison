//@+leo-ver=4
//@+node:@file examples/java/table.h
//@@language c
#include "tokens.h"

struct KeywordToken
{
	char * Keyword;
	int TokenCode;

};

struct KeywordToken KeywordTable [] = 
{

  {"abstract", ABSTRACT_TOKEN },
  {"boolean", BOOLEAN_TOKEN },
  {"break", BREAK_TOKEN },
  {"byte", BYTE_TOKEN },
  {"case", CASE_TOKEN }, 
  {"catch", CATCH_TOKEN },
  {"char", CHAR_TOKEN },
  {"class", CLASS_TOKEN },
  {"const", CONST_TOKEN },
  {"continue", CONTINUE_TOKEN },
  {"default", DEFAULT_TOKEN },
  {"do", DO_TOKEN },
  {"double", DOUBLE_TOKEN },
  {"else", ELSE_TOKEN },
  {"extends", EXTENDS_TOKEN },
  {"final", FINAL_TOKEN },
  {"finally", FINALLY_TOKEN },
  {"float", FLOAT_TOKEN },
  {"for", FOR_TOKEN },
  {"goto", GOTO_TOKEN },
  {"if", IF_TOKEN },
  {"implements", IMPLEMENTS_TOKEN },
  {"import", IMPORT_TOKEN },
  {"instanceof", INSTANCEOF_TOKEN },
  {"int", INT_TOKEN },
  {"interface", INTERFACE_TOKEN },
  {"long", LONG_TOKEN },
  {"native", NATIVE_TOKEN },
  {"new", NEW_TOKEN },
  {"null", NULL_TOKEN },
  {"package", PACKAGE_TOKEN },
  {"private", PRIVATE_TOKEN },
  {"protected", PROTECTED_TOKEN },
  {"public", PUBLIC_TOKEN },
  {"return", RETURN_TOKEN },
  {"short", SHORT_TOKEN },
  {"static", STATIC_TOKEN },
  {"strictfp", STRICTFP_TOKEN },
  {"super", SUPER_TOKEN },
  {"switch", SWITCH_TOKEN },
  {"synchronized", SYNCHRONIZED_TOKEN },
  {"this", THIS_TOKEN },
  {"throw", THROW_TOKEN },
  {"throws", THROWS_TOKEN },
  {"transient", TRANSIENT_TOKEN },
  {"try", TRY_TOKEN },
  {"void", VOID_TOKEN },
  {"volatile", VOLATILE_TOKEN },
  {"while", WHILE_TOKEN },
  {"", ID_TOKEN }
};
//@-node:@file examples/java/table.h
//@-leo
