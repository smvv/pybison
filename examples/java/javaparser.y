/* yacc grammar for JAVA language */
/* print with     psf -p 10 -L50 -l 50 -w -E j.y > xx */

%{
#define REDUCE  /* will display the reduce rules */
#undef  REDUCE

#define PRNT_SYM
#undef  PRNT_SYM

#define YYDEBUG 1

#include <stdio.h>

extern FILE *yyin;
extern int yylineno;
extern int yydebug;
extern char yytext[];

#ifdef REDUCE
#   define reduce(a) printf("%s\n",a)
#else
#   define reduce(a)
#endif

#define YYSTYPE PyObject *

%}

/* Things defined here have to match the order of what's in the
   binop_lookup table.  */

%token   PLUS_TOKEN         MINUS_TOKEN        MUL_TOKEN         DIV_TOKEN    MOD_TOKEN
%token   SHL_TOKEN           SHR_TOKEN          SAR_TOKEN
%token   AND_TOKEN          XOR_TOKEN          OR_TOKEN
%token   LOGICAL_AND_TOKEN LOGICAL_OR_TOKEN 
%token   EQ_TOKEN NE_OP_TOKEN GREATER_TOKEN GE_TOKEN LESS_TOKEN LE_TOKEN

/* This maps to the same binop_lookup entry than the token above */

%token   ADD_ASSIGN_TOKEN  SUB_ASSIGN_TOKEN MUL_ASSIGN_TOKEN DIV_ASSIGN_TOKEN
%token   MOD_ASSIGN_TOKEN   
%token   SHL_ASSIGN_TOKEN    SHR_ASSIGN_TOKEN   SAR_ASSIGN_TOKEN
%token   AND_ASSIGN_TOKEN   XOR_ASSIGN_TOKEN   OR_ASSIGN_TOKEN


/* Modifier TOKEN have to be kept in this order. Don't scramble it */

%token   PUBLIC_TOKEN       PRIVATE_TOKEN         PROTECTED_TOKEN
%token   STATIC_TOKEN       FINAL_TOKEN           SYNCHRONIZED_TOKEN
%token   VOLATILE_TOKEN     TRANSIENT_TOKEN       NATIVE_TOKEN
%token   PAD_TOKEN          ABSTRACT_TOKEN        MODIFIER_TOKEN
%token   STRICT_TOKEN STRICTFP_TOKEN

/* Keep those two in order, too */
%token   DEC_TOKEN INC_TOKEN

/* From now one, things can be in any order */

%token   DEFAULT_TOKEN      IF_TOKEN              THROW_TOKEN
%token   BOOLEAN_TOKEN      DO_TOKEN              IMPLEMENTS_TOKEN
%token   THROWS_TOKEN       BREAK_TOKEN           IMPORT_TOKEN       
%token   ELSE_TOKEN         INSTANCEOF_TOKEN      RETURN_TOKEN
%token   VOID_TOKEN         CATCH_TOKEN           INTERFACE_TOKEN
%token   CASE_TOKEN         EXTENDS_TOKEN         FINALLY_TOKEN
%token   SUPER_TOKEN        WHILE_TOKEN           CLASS_TOKEN
%token   SWITCH_TOKEN       CONST_TOKEN           TRY_TOKEN
%token   FOR_TOKEN          NEW_TOKEN             CONTINUE_TOKEN
%token   GOTO_TOKEN         PACKAGE_TOKEN         THIS_TOKEN
%token   ASSERT_TOKEN

%token   BYTE_TOKEN         SHORT_TOKEN           INT_TOKEN            LONG_TOKEN
%token   CHAR_TOKEN

%token   FLOAT_TOKEN        DOUBLE_TOKEN

%token   ID_TOKEN

%token   CONDITIONAL_TOKEN         COLON_TOKEN TILDE_TOKEN  NOT_TOKEN

%token   ASSIGN_ANY_TOKEN   ASSIGNS_TOKEN
%token   OPEN_PAREN_TOKEN  CLOSE_PAREN_TOKEN  OPEN_BRACE_TOKEN  CLOSE_BRACE_TOKEN  OPEN_BRACKET_TOKEN  CLOSE_BRACKET_TOKEN  SEMICOLON_TOKEN  COMMA_TOKEN PERIOD_TOKEN

%token INTEGER_LITERAL_TOKEN   FLOATING_POINT_LITERAL_TOKEN   BOOLEAN_LITERAL_TOKEN   STRING_LITERAL_TOKEN
%token CHARACTER_LITERAL_TOKEN    NULL_TOKEN


%right SHL_ASSIGN_TOKEN SAR_ASSIGN_TOKEN AND_ASSIGN_TOKEN OR_ASSIGN_TOKEN XOR_ASSIGN_TOKEN
       ASSIGNS_TOKEN ADD_ASSIGN_TOKEN SUB_ASSIGN_TOKEN MUL_ASSIGN_TOKEN DIV_ASSIGN_TOKEN MOD_ASSIGN_TOKEN
%left  LOGICAL_OR_TOKEN
%left  LOGICAL_AND_TOKEN   
%left  OR_TOKEN 
%left  XOR_TOKEN
%left  AND_TOKEN
%left  RELATIVEQEUAL_TOKEN NE_OP_TOKEN 
%left  GREATER_TOKEN LESS_TOKEN GE_TOKEN LE_TOKEN
%left  SHL_TOKEN SAR_TOKEN SHR_TOKEN
%left  PLUS_TOKEN MINUS_TOKEN
%left  MUL_TOKEN DIV_TOKEN MOD_TOKEN
%nonassoc NOT_TOKEN TILDE_TOKEN 


%start goal

%%

goal
: compilation_unit
;

literal
: INTEGER_LITERAL_TOKEN
| FLOATING_POINT_LITERAL_TOKEN
| BOOLEAN_LITERAL_TOKEN
| CHARACTER_LITERAL_TOKEN
| STRING_LITERAL_TOKEN
| NULL_TOKEN
;

type
: primitive_type
| reference_type
;

primitive_type 
: INT_TOKEN
| LONG_TOKEN
| FLOAT_TOKEN
| DOUBLE_TOKEN
| BOOLEAN_TOKEN
| BYTE_TOKEN
| CHAR_TOKEN
| SHORT_TOKEN
;

reference_type
: class_or_interface_type
| array_type
;

class_or_interface_type
: name
;

class_type
: class_or_interface_type
;

interface_type
: class_or_interface_type
;

array_type
: primitive_type dims
| name dims
;

name
: simple_name
| qualified_name
;

simple_name
: identifier
;

qualified_name
: name PERIOD_TOKEN identifier
;

identifier
: ID_TOKEN
;

compilation_unit
:
| package_declaration
| import_declarations
| type_declarations
| package_declaration import_declarations
| package_declaration type_declarations
| import_declarations type_declarations
| package_declaration import_declarations type_declarations
;

import_declarations
: import_declaration
| import_declarations import_declaration
;

type_declarations 
: type_declaration
| type_declarations type_declaration
;

package_declaration 
: PACKAGE_TOKEN name SEMICOLON_TOKEN
;

import_declaration 
: single_type_import_declaration
| type_import_on_demand_declaration
;

single_type_import_declaration 
: IMPORT_TOKEN name SEMICOLON_TOKEN
;

type_import_on_demand_declaration 
: IMPORT_TOKEN name PERIOD_TOKEN MUL_TOKEN SEMICOLON_TOKEN
;

type_declaration 
: class_declaration
| interface_declaration
| empty_statement
;

modifiers 
: modifier
| modifiers modifier
;

modifier
: STATIC_TOKEN
| PUBLIC_TOKEN
| PROTECTED_TOKEN
| PRIVATE_TOKEN
| ABSTRACT_TOKEN
| FINAL_TOKEN
| NATIVE_TOKEN
| SYNCHRONIZED_TOKEN
| TRANSIENT_TOKEN
| VOLATILE_TOKEN
;

class_declaration 
: modifiers CLASS_TOKEN identifier super interfaces class_body
| CLASS_TOKEN identifier super interfaces class_body
;

super 
:
| EXTENDS_TOKEN class_type
;

interfaces 
:
| IMPLEMENTS_TOKEN interface_type_list
;

interface_type_list
: interface_type
| interface_type_list COMMA_TOKEN interface_type
;

class_body 
: OPEN_BRACE_TOKEN CLOSE_BRACE_TOKEN
| OPEN_BRACE_TOKEN class_body_declarations CLOSE_BRACE_TOKEN
;

class_body_declarations 
: class_body_declaration
| class_body_declarations class_body_declaration
;

class_body_declaration 
: class_member_declaration
| static_initializer
| constructor_declaration
| block
;

class_member_declaration 
: field_declaration
| method_declaration
| class_declaration
| interface_declaration
| empty_statement
;

field_declaration 
: type variable_declarators SEMICOLON_TOKEN
| modifiers type variable_declarators SEMICOLON_TOKEN
;

variable_declarators 
: variable_declarator
| variable_declarators COMMA_TOKEN variable_declarator
;

variable_declarator 
: variable_declarator_id
| variable_declarator_id ASSIGNS_TOKEN variable_initializer
;

variable_declarator_id 
: identifier
| variable_declarator_id OPEN_BRACKET_TOKEN CLOSE_BRACKET_TOKEN
;

variable_initializer 
: expression
| array_initializer
;

method_declaration 
: method_header method_body
;

method_header
: type method_declarator throws
| VOID_TOKEN method_declarator throws
| modifiers type method_declarator throws
| modifiers VOID_TOKEN method_declarator throws
;

method_declarator 
: identifier OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN
| identifier OPEN_PAREN_TOKEN formal_parameter_list CLOSE_PAREN_TOKEN
| method_declarator OPEN_BRACKET_TOKEN CLOSE_BRACKET_TOKEN
;

formal_parameter_list 
: formal_parameter
| formal_parameter_list COMMA_TOKEN formal_parameter
;

formal_parameter 
: type variable_declarator_id
| modifiers type variable_declarator_id
;

throws 
:
| THROWS_TOKEN class_type_list
;

class_type_list 
: class_type
| class_type_list COMMA_TOKEN class_type
;

method_body 
: block
| SEMICOLON_TOKEN
;

static_initializer 
: static block
;

static
: modifiers
;

constructor_declaration 
: constructor_header constructor_body
;

constructor_header
: constructor_declarator throws
|	modifiers constructor_declarator throws
;

constructor_declarator 
: simple_name OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN
| simple_name OPEN_PAREN_TOKEN formal_parameter_list CLOSE_PAREN_TOKEN
;

constructor_body
: block_begin constructor_block_end
| block_begin explicit_constructor_invocation constructor_block_end
| block_begin block_statements constructor_block_end
| block_begin explicit_constructor_invocation block_statements constructor_block_end
;

constructor_block_end
: block_end
;

block_begin
: OPEN_BRACE_TOKEN
;

block_end
: CLOSE_BRACE_TOKEN
;

explicit_constructor_invocation 
: this_or_super OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN SEMICOLON_TOKEN
| this_or_super OPEN_PAREN_TOKEN argument_list CLOSE_PAREN_TOKEN SEMICOLON_TOKEN
| name PERIOD_TOKEN SUPER_TOKEN OPEN_PAREN_TOKEN argument_list CLOSE_PAREN_TOKEN SEMICOLON_TOKEN
| name PERIOD_TOKEN SUPER_TOKEN OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN SEMICOLON_TOKEN
;

this_or_super
: THIS_TOKEN
| SUPER_TOKEN
;

interface_declaration 
: INTERFACE_TOKEN identifier interface_body
| modifiers INTERFACE_TOKEN identifier interface_body
| INTERFACE_TOKEN identifier extends_interfaces interface_body
| modifiers INTERFACE_TOKEN identifier extends_interfaces interface_body
;

extends_interfaces 
: EXTENDS_TOKEN interface_type
| extends_interfaces COMMA_TOKEN interface_type
;

interface_body 
: OPEN_BRACE_TOKEN CLOSE_BRACE_TOKEN
| OPEN_BRACE_TOKEN interface_member_declarations CLOSE_BRACE_TOKEN
;

interface_member_declarations 
: interface_member_declaration
| interface_member_declarations interface_member_declaration
;

interface_member_declaration 
: constant_declaration
| abstract_method_declaration
| class_declaration
| interface_declaration
;

constant_declaration 
: field_declaration
;

abstract_method_declaration 
: method_header SEMICOLON_TOKEN
;

array_initializer 
: OPEN_BRACE_TOKEN CLOSE_BRACE_TOKEN
| OPEN_BRACE_TOKEN COMMA_TOKEN CLOSE_BRACE_TOKEN
| OPEN_BRACE_TOKEN variable_initializers CLOSE_BRACE_TOKEN
| OPEN_BRACE_TOKEN variable_initializers COMMA_TOKEN CLOSE_BRACE_TOKEN
;

variable_initializers 
: variable_initializer
| variable_initializers COMMA_TOKEN variable_initializer
;

block 
: OPEN_BRACE_TOKEN CLOSE_BRACE_TOKEN
| OPEN_BRACE_TOKEN block_statements CLOSE_BRACE_TOKEN
;

block_statements 
: block_statement
| block_statements block_statement
;

block_statement 
: local_variable_declaration_statement
| statement
| class_declaration
;

local_variable_declaration_statement 
: local_variable_declaration SEMICOLON_TOKEN
;

local_variable_declaration 
: type variable_declarators
| modifiers type variable_declarators
;

statement 
: statement_without_trailing_substatement
| labeled_statement
| if_then_statement
| if_then_else_statement
| while_statement
| for_statement
;

statement_nsi 
: statement_without_trailing_substatement
| labeled_statement_nsi
| if_then_else_statement_nsi
| while_statement_nsi
| for_statement_nsi
;

statement_without_trailing_substatement 
: block
| empty_statement
| expression_statement
| switch_statement
| do_statement
| break_statement
| continue_statement
| return_statement
| synchronized_statement
| throw_statement
| try_statement
| assert_statement
;

empty_statement 
: SEMICOLON_TOKEN
;

label_decl 
: identifier COLON_TOKEN
;

labeled_statement 
: label_decl statement
;

labeled_statement_nsi 
: label_decl statement_nsi
;

expression_statement 
: statement_expression SEMICOLON_TOKEN
| SYNCHRONIZED_TOKEN OPEN_PAREN_TOKEN argument_list CLOSE_PAREN_TOKEN block
;

statement_expression
: assignment
| primary
| pre_increment_expression
| pre_decrement_expression
| post_increment_expression
| post_decrement_expression
| method_invocation
| class_instance_creation_expression
;

if_then_statement 
: IF_TOKEN OPEN_PAREN_TOKEN expression CLOSE_PAREN_TOKEN statement
;

if_then_else_statement 
: IF_TOKEN OPEN_PAREN_TOKEN expression CLOSE_PAREN_TOKEN statement_nsi ELSE_TOKEN statement
;

if_then_else_statement_nsi 
: IF_TOKEN OPEN_PAREN_TOKEN expression CLOSE_PAREN_TOKEN statement_nsi ELSE_TOKEN statement_nsi
;

switch_statement 
: switch_expression switch_block
;

switch_expression
: SWITCH_TOKEN OPEN_PAREN_TOKEN expression CLOSE_PAREN_TOKEN
;

switch_block 
: OPEN_BRACE_TOKEN CLOSE_BRACE_TOKEN
| OPEN_BRACE_TOKEN switch_labels CLOSE_BRACE_TOKEN
| OPEN_BRACE_TOKEN switch_block_statement_groups CLOSE_BRACE_TOKEN
| OPEN_BRACE_TOKEN switch_block_statement_groups switch_labels CLOSE_BRACE_TOKEN
;

switch_block_statement_groups
: switch_block_statement_group
| switch_block_statement_groups switch_block_statement_group
;

switch_block_statement_group 
: switch_labels block_statements
;

switch_labels 
: switch_label
| switch_labels switch_label
;

switch_label 
: CASE_TOKEN constant_expression COLON_TOKEN
| DEFAULT_TOKEN COLON_TOKEN
;

while_expression 
: WHILE_TOKEN OPEN_PAREN_TOKEN expression CLOSE_PAREN_TOKEN
;

while_statement 
: while_expression statement
;

while_statement_nsi 
: while_expression statement_nsi
;

do_statement_begin 
: DO_TOKEN
;

do_statement
: do_statement_begin statement WHILE_TOKEN OPEN_PAREN_TOKEN expression CLOSE_PAREN_TOKEN SEMICOLON_TOKEN
;

for_statement 
: for_begin SEMICOLON_TOKEN expression SEMICOLON_TOKEN for_update CLOSE_PAREN_TOKEN statement
| for_begin SEMICOLON_TOKEN SEMICOLON_TOKEN for_update CLOSE_PAREN_TOKEN statement
;

for_statement_nsi 
: for_begin SEMICOLON_TOKEN expression SEMICOLON_TOKEN for_update CLOSE_PAREN_TOKEN statement_nsi
| for_begin SEMICOLON_TOKEN SEMICOLON_TOKEN for_update CLOSE_PAREN_TOKEN statement_nsi
;

for_header 
: FOR_TOKEN OPEN_PAREN_TOKEN
;

for_begin 
: for_header for_init
;

for_init
:
| statement_expression_list
| local_variable_declaration
;

for_update
:
| statement_expression_list
;

statement_expression_list 
: statement_expression
| statement_expression_list COMMA_TOKEN statement_expression
;

break_statement 
: BREAK_TOKEN SEMICOLON_TOKEN
| BREAK_TOKEN identifier SEMICOLON_TOKEN
;

continue_statement 
: CONTINUE_TOKEN SEMICOLON_TOKEN
| CONTINUE_TOKEN identifier SEMICOLON_TOKEN
;

return_statement 
: RETURN_TOKEN SEMICOLON_TOKEN
| RETURN_TOKEN expression SEMICOLON_TOKEN
;

throw_statement 
: THROW_TOKEN expression SEMICOLON_TOKEN
;

assert_statement 
: ASSERT_TOKEN expression COLON_TOKEN expression SEMICOLON_TOKEN
| ASSERT_TOKEN expression SEMICOLON_TOKEN
| ASSERT_TOKEN error
| ASSERT_TOKEN expression error
;
synchronized_statement 
: synchronized OPEN_PAREN_TOKEN expression CLOSE_PAREN_TOKEN block
| synchronized OPEN_PAREN_TOKEN expression CLOSE_PAREN_TOKEN error
;

synchronized
: MODIFIER_TOKEN
;

try_statement 
: TRY_TOKEN block catches
| TRY_TOKEN block finally
| TRY_TOKEN block catches finally
;

catches 
: catch_clause
| catches catch_clause
;

catch_clause 
: CATCH_TOKEN OPEN_PAREN_TOKEN formal_parameter CLOSE_PAREN_TOKEN block
;

finally 
: FINALLY_TOKEN block
;

primary
: primary_no_new_array
| array_creation_expression
;

primary_no_new_array 
: literal
| THIS_TOKEN
| OPEN_PAREN_TOKEN expression CLOSE_PAREN_TOKEN
| class_instance_creation_expression
| field_access
| method_invocation
| array_access
| type_literals
| name PERIOD_TOKEN THIS_TOKEN
;

type_literals 
: name PERIOD_TOKEN CLASS_TOKEN
| array_type PERIOD_TOKEN CLASS_TOKEN
| primitive_type PERIOD_TOKEN CLASS_TOKEN
| VOID_TOKEN PERIOD_TOKEN CLASS_TOKEN
;

class_instance_creation_expression 
: NEW_TOKEN class_type OPEN_PAREN_TOKEN argument_list CLOSE_PAREN_TOKEN
| NEW_TOKEN class_type OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN
| anonymous_class_creation
| something_dot_new identifier OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN
| something_dot_new identifier OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN class_body
| something_dot_new identifier OPEN_PAREN_TOKEN argument_list CLOSE_PAREN_TOKEN
| something_dot_new identifier OPEN_PAREN_TOKEN argument_list CLOSE_PAREN_TOKEN class_body
;

anonymous_class_creation 
: NEW_TOKEN class_type OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN class_body 
| NEW_TOKEN class_type OPEN_PAREN_TOKEN argument_list CLOSE_PAREN_TOKEN class_body
;

something_dot_new
: name PERIOD_TOKEN NEW_TOKEN
| primary PERIOD_TOKEN NEW_TOKEN
;

argument_list 
: expression
| argument_list COMMA_TOKEN expression
| argument_list COMMA_TOKEN error
;

array_creation_expression 
: NEW_TOKEN primitive_type dim_exprs
| NEW_TOKEN class_or_interface_type dim_exprs
| NEW_TOKEN primitive_type dim_exprs dims
| NEW_TOKEN class_or_interface_type dim_exprs dims
| NEW_TOKEN class_or_interface_type dims array_initializer
| NEW_TOKEN primitive_type dims array_initializer
;

dim_exprs 
: dim_expr
| dim_exprs dim_expr
;

dim_expr 
: OPEN_BRACKET_TOKEN expression CLOSE_BRACKET_TOKEN
;

dims
: OPEN_BRACKET_TOKEN CLOSE_BRACKET_TOKEN
| dims OPEN_BRACKET_TOKEN CLOSE_BRACKET_TOKEN
;

field_access 
: primary PERIOD_TOKEN identifier
| SUPER_TOKEN PERIOD_TOKEN identifier
;

method_invocation 
: name OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN
| name OPEN_PAREN_TOKEN argument_list CLOSE_PAREN_TOKEN
| primary PERIOD_TOKEN identifier OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN
| primary PERIOD_TOKEN identifier OPEN_PAREN_TOKEN argument_list CLOSE_PAREN_TOKEN
| SUPER_TOKEN PERIOD_TOKEN identifier OPEN_PAREN_TOKEN CLOSE_PAREN_TOKEN
| SUPER_TOKEN PERIOD_TOKEN identifier OPEN_PAREN_TOKEN argument_list CLOSE_PAREN_TOKEN
;

array_access 
: name OPEN_BRACKET_TOKEN expression CLOSE_BRACKET_TOKEN
| primary_no_new_array OPEN_BRACKET_TOKEN expression CLOSE_BRACKET_TOKEN
;

postfix_expression 
: primary
| name
| post_increment_expression
| post_decrement_expression
;

post_increment_expression 
: postfix_expression INC_TOKEN
;

post_decrement_expression 
: postfix_expression DEC_TOKEN
;

trap_overflow_corner_case
: pre_increment_expression
| pre_decrement_expression
| PLUS_TOKEN unary_expression
| unary_expression_not_plus_minus
;

unary_expression
: trap_overflow_corner_case
| MINUS_TOKEN trap_overflow_corner_case
| MINUS_TOKEN error
;

pre_increment_expression 
: INC_TOKEN unary_expression
;

pre_decrement_expression 
: DEC_TOKEN unary_expression
;

unary_expression_not_plus_minus 
: postfix_expression
| TILDE_TOKEN unary_expression
| NOT_TOKEN unary_expression
| cast_expression
;

cast_expression
: OPEN_PAREN_TOKEN primitive_type dims CLOSE_PAREN_TOKEN unary_expression
| OPEN_PAREN_TOKEN primitive_type CLOSE_PAREN_TOKEN unary_expression
| OPEN_PAREN_TOKEN expression CLOSE_PAREN_TOKEN unary_expression_not_plus_minus
| OPEN_PAREN_TOKEN name dims CLOSE_PAREN_TOKEN unary_expression_not_plus_minus
;

multiplicative_expression 
: unary_expression
| multiplicative_expression MUL_TOKEN unary_expression
| multiplicative_expression DIV_TOKEN unary_expression
| multiplicative_expression MOD_TOKEN unary_expression
;

additive_expression 
: multiplicative_expression
| additive_expression PLUS_TOKEN multiplicative_expression
| additive_expression MINUS_TOKEN multiplicative_expression
;

shift_expression 
: additive_expression
| shift_expression SHL_TOKEN additive_expression
| shift_expression SHR_TOKEN additive_expression
| shift_expression SAR_TOKEN additive_expression
;

relational_expression 
: shift_expression
| relational_expression LESS_TOKEN shift_expression
| relational_expression GREATER_TOKEN shift_expression
| relational_expression LE_TOKEN shift_expression
| relational_expression GE_TOKEN shift_expression
| relational_expression INSTANCEOF_TOKEN reference_type
;

equality_expression 
: relational_expression
| equality_expression EQ_TOKEN relational_expression
| equality_expression NE_OP_TOKEN relational_expression
;

and_expression 
: equality_expression
| and_expression AND_TOKEN equality_expression
;

exclusive_or_expression 
: and_expression
| exclusive_or_expression XOR_TOKEN and_expression
;

inclusive_or_expression 
: exclusive_or_expression
| inclusive_or_expression OR_TOKEN exclusive_or_expression
;

conditional_and_expression 
: inclusive_or_expression
| conditional_and_expression LOGICAL_AND_TOKEN inclusive_or_expression
;

conditional_or_expression 
: conditional_and_expression
| conditional_or_expression LOGICAL_OR_TOKEN conditional_and_expression
;

conditional_expression
: conditional_or_expression
| conditional_or_expression CONDITIONAL_TOKEN expression COLON_TOKEN conditional_expression
;

assignment_expression 
: conditional_expression
| assignment
;

assignment 
: left_hand_side assignment_operator assignment_expression
;

left_hand_side 
: name
| field_access
| array_access
;

assignment_operator 
: ASSIGNS_TOKEN
| ADD_ASSIGN_TOKEN
| SUB_ASSIGN_TOKEN
| MUL_ASSIGN_TOKEN
| DIV_ASSIGN_TOKEN
| MOD_ASSIGN_TOKEN   
| SHL_ASSIGN_TOKEN
| SHR_ASSIGN_TOKEN
| SAR_ASSIGN_TOKEN
| AND_ASSIGN_TOKEN
| XOR_ASSIGN_TOKEN
| OR_ASSIGN_TOKEN
;

expression 
: assignment_expression
;

constant_expression 
: expression
;

%%


void print_prototype(void)
{
}

void generate_default_constructor(char *name)
{
}
    
int yyerror(char *mesg)
{
     printf("line %d: %s before %s\n", yylineno, mesg, yytext);
     exit(0);
}

