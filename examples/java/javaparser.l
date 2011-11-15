D            [0-9]
N            [1-9]
L            [a-zA-Z_$]
H            [a-fA-F0-9]
OC           [0-7]
E            [Ee][+-]?{D}+
LS           [fFdD]
Escape       \\[ntbrf\\'"]
Escchar      \\{D}({D}?{D})?
Escunichar   \\u{H}{H}{H}{H}

%{
int yylineno = 0;
#include <stdio.h>
#include <string.h>
#include "Python.h"
#define YYSTYPE void *
#include "tokens.h"
extern void *py_parser;
extern void (*py_input)(PyObject *parser, char *buf, int *result, int max_size);
#define returntoken(tok) /*printf("%d=%s\n", tok, yytext);*/ yylval = PyString_FromString(strdup(yytext)); return (tok);
#define YY_INPUT(buf,result,max_size) { (*py_input)(py_parser, buf, &result, max_size); }

#include "table.h"

%}

%%


{N}{D}*(l|L)?           { returntoken(INTEGER_LITERAL_TOKEN); }
{N}{D}*(d|D)?           { returntoken(INTEGER_LITERAL_TOKEN); }
0[xX]{H}+(l|L)?         { returntoken(INTEGER_LITERAL_TOKEN); }
0{OC}*(l|L)?            { returntoken(INTEGER_LITERAL_TOKEN); }

{D}+"."{D}*({E})?{LS}?  { returntoken(FLOATING_POINT_LITERAL_TOKEN); }
"."{D}+({E})?{LS}?      { returntoken(FLOATING_POINT_LITERAL_TOKEN); }
{D}+{E}{LS}?            { returntoken(FLOATING_POINT_LITERAL_TOKEN); }
{D}{LS}                 { returntoken(FLOATING_POINT_LITERAL_TOKEN); }


"true"                  { returntoken(BOOLEAN_LITERAL_TOKEN); }
"false"                 { returntoken(BOOLEAN_LITERAL_TOKEN); }

{L}({L}|{D})*           { returntoken(Table_Lookup(KeywordTable));}

'[^'\\]'                { returntoken(CHARACTER_LITERAL_TOKEN);}
'{Escape}'              { returntoken(CHARACTER_LITERAL_TOKEN);}


  \"([^\"\\]|{Escape}|{Escchar}|{Escunichar})*\" { returntoken(STRING_LITERAL_TOKEN); }

\/\/.*$                 {}
\/\*                    { comment();}

"("     { returntoken(OPEN_PAREN_TOKEN); }
")"     { returntoken(CLOSE_PAREN_TOKEN); }
"{"     { returntoken(OPEN_BRACE_TOKEN); }
"}"     { returntoken(CLOSE_BRACE_TOKEN); }
"["     { returntoken(OPEN_BRACKET_TOKEN); }
"]"     { returntoken(CLOSE_BRACKET_TOKEN); }
";"     { returntoken(SEMICOLON_TOKEN); }
","     { returntoken(COMMA_TOKEN); }
"."     { returntoken(PERIOD_TOKEN); }
"="     { returntoken(ASSIGNS_TOKEN); }
">"     { returntoken(GREATER_TOKEN); }
"<"     { returntoken(LESS_TOKEN); }
"!"     { returntoken(NOT_TOKEN); }
"~"     { returntoken(TILDE_TOKEN); }
"?"     { returntoken(CONDITIONAL_TOKEN); }
":"     { returntoken(COLON_TOKEN); }
"=="    { returntoken(EQ_TOKEN); }
"<="    { returntoken(LE_TOKEN); }
">="    { returntoken(GE_TOKEN); }
"!="    { returntoken(NE_OP_TOKEN); }
"||"    { returntoken(LOGICAL_OR_TOKEN); }
"&&"    { returntoken(LOGICAL_AND_TOKEN); }
"++"    { returntoken(INC_TOKEN); }
"--"    { returntoken(DEC_TOKEN); }
"+"     { returntoken(PLUS_TOKEN); }
"-"     { returntoken(MINUS_TOKEN); }
"*"     { returntoken(MUL_TOKEN); }
"/"     { returntoken(DIV_TOKEN); }
"&"     { returntoken(AND_TOKEN); }
"|"     { returntoken(OR_TOKEN); }
"^"     { returntoken(XOR_TOKEN); }
"%"     { returntoken(MOD_TOKEN); }
"<<"    { returntoken(SHL_TOKEN); }
">>"    { returntoken(SAR_TOKEN); }
">>>"   { returntoken(SHL_TOKEN); }
"+="    { returntoken(ADD_ASSIGN_TOKEN); }
"-="    { returntoken(SUB_ASSIGN_TOKEN); }
"*="    { returntoken(MUL_ASSIGN_TOKEN); }
"/="    { returntoken(DIV_ASSIGN_TOKEN); }
"&="    { returntoken(AND_ASSIGN_TOKEN); }
"|="    { returntoken(OR_ASSIGN_TOKEN); }
"^="    { returntoken(XOR_ASSIGN_TOKEN); }
"%="    { returntoken(MOD_ASSIGN_TOKEN); }
"<<="   { returntoken(SHL_ASSIGN_TOKEN); }
">>="   { returntoken(SAR_ASSIGN_TOKEN); }
">>>="  { returntoken(SHR_ASSIGN_TOKEN); }

[ \t\v\f]             {}
[\n]		{yylineno++;}

.       { printf("unknown char %c ignored\n", yytext[0]); /* ignore bad chars */}


%%

yywrap() { return(1); }

/* test_main()
{
    int t;

    for(t = yylex(), t > 0, t = yylex())
    {
        printf("%s\t%d\n", yytext,t);
    }

    return 0;
}
*/


/* input: Table of tokens
 * returns TokenCode of keyword if matched or 
 * ID_TOKEN if no match is found 
 */
int Table_Lookup(struct KeywordToken Table[])
{
    struct KeywordToken *Curr;
    int i = 0;

    for (Curr = Table; Curr->Keyword != ""; Curr++)
      {
        //printf("Table_Lookup: yytext='%s', Curr->Keyword='%s', idx=%d\n", yytext, Curr->Keyword, i);

        if (strcmp(Curr->Keyword, yytext)==0)
          {
            //printf("Table_Lookup: '%s' => %d\n", yytext, Curr->TokenCode);
            return (Curr->TokenCode);
          }
        i++;
      }
    return ID_TOKEN;
}

commentold()
{
    char c = -1, c1;
    while(c != 0)
    {
        for(c = input(); c != '*' && c!=0; c = input())
            ;

        /* now we have a star or no more chars */
        if(c == 0 || (c1 = input() == '/'))
            return;

        if (c1 == '*')
            unput(c1);
    }
}

comment()
{
  int prev=-1, cur=-1;

  while (1)
    {
      cur = input();
      if (cur == '/' && prev == '*')
        return;
      else if (cur == 0)
        return;
      prev = cur;
    }
}
