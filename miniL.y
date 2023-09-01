/* cs152-miniL phase3 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <iostream>
#include <sstream>
#include <cstring>
#include <unordered_map>
#include <set>
#include <bits/stdc++.h>
#include "lib.h"
using namespace std;

void yyerror(const char *msg);

extern int currLine;
extern int currPos;
extern int yylex();

FILE* fin;

string code = "";  // This variable holds all miniL code for a program after parsing.
bool mainFlag = false; // Indicates if the program must have a 'main' function.
bool errorFlag = false; // Used to prevent code output if errors exist.
set<string> funcs; // Set of function names.
set<string> symbols; // Set of variable/identifier names.
unordered_map<string, bool> isArr; // HashMap to store if a variable is an array.

set<string> reserved {
    "function", "beginparams", "endparams", "beginlocals", "endlocals", "beginbody", "endbody", "integer", "array",
    "enum","of", "if", "then", "endif", "else", "for", "while", "do", "beginloop", "endloop", "continue", "read", 
    "write", "and", "or", "not", "true", "false", "return"
};
%}

%union {
  int ival;
  char* str;

  struct attr {
    char* code;
    bool isArray;
    char* s_name;
  } attributes;

}

%error-verbose

%start prog_start

%token <str> FUNCTION "function" SEMICOLON ";" BEGIN_PARAMS "beginparams" END_PARAMS "endparams" BEGIN_LOCALS "beginlocals" END_LOCALS "endlocals" BEGIN_BODY "beginbody" END_BODY "endbody"
%token <str> COMMA ","  COLON ":" INTEGER "integer" ARRAY "array" L_SQUARE_BRACKET "[" R_SQUARE_BRACKET "]" OF "of" ENUM "enum" ASSIGN ":=" 
%token <str> IF "if" THEN "then" ELSE "else" ENDIF "endif" FOR "for" WHILE "while" BEGINLOOP "beginloop" ENDLOOP "endloop" DO "do" READ "read" WRITE "write" CONTINUE "continue"
%token <str> OR "or" AND "and" NOT "not" TRUE "true" FALSE "false" EQ "==" NEQ "<>" LT "<" GT ">" LTE "<=" GTE ">=" ADD "+" SUB "-" MULT "*" DIV "/" MOD "%" L_PAREN "(" R_PAREN ")" RETURN "return" ERROR "symbol" EQSIGN "="
%token <ival> NUMBER "number"
%token <str> IDENT "identifier"
%type <attributes> functions function declarations declaration statements statement vars var expressions expression bool_exp relation_and_exp relation_exp comp multiplicative_expression term identifiers ident funcid
%right ASSIGN
%left OR
%left AND
%right NOT
%left LT LTE GT GTE EQ NEQ
%left ADD SUB
%left MULT DIV MOD
%right UMINUS
%left L_SQUARE_BRACKET R_SQUARE_BRACKET
%left L_PAREN R_PAREN

%% 

/* Define your rules here */
prog_start:
  functions   { std::cout << code; } |
  error '\n'  { yyerrok; yyclearin; }
  ;

functions:
    {
       // Functions are epsilon
       if (!mainFlag) {
         cout << "Error: The \"main\" function is not defined" << endl;
         exit(1);
       }
       if (errorFlag) exit(1);
    } | 
    function functions  {}
    ;

function:
  FUNCTION funcid SEMICOLON BEGIN_PARAMS declarations END_PARAMS BEGIN_LOCALS declarations END_LOCALS BEGIN_BODY statements END_BODY
  {
    string codeblock($11.code);
    if (codeblock.find("continue") != string::npos) {
      errorFlag = true;
      cout << "Error on line " << currLine << ": continue statement not within a loop\n";
    }
    
    string build = ""; 
    string params($5.code);
    int count = 0; 
    int space = 0;
    for (int i = 0; i < params.size(); ++i) {
      if (params[i] == ' ') { 
        space = i; 
      }
      if (params[i] == '\n') {
        string s = params.substr(space, i - space);
        build.append("."+s+"\n");
        build.append("="+s+", $"+to_string(count++)+"\n");
      }
    }

    stringstream stream;
    stream << "func " << $2.s_name << "\n" << build << $8.code << $11.code << "endfunc\n\n";
    code.append(stream.str());
  }
  ;

funcid:
  IDENT {
    $$.code = strdup("");
    $$.s_name = strdup($1); 
    string id($1);
    if (id == "main") mainFlag = true;
    if (funcs.find(id) == funcs.end()) { 
      funcs.insert(id); 
    } else {
      errorFlag = true; 
      cout << "Error on line " << currLine << ": function \"" << id << "\" is multiply defined\n";
    }
  }
  ;
declarations:
    {
      // Declarations are epsilon
      $$.code = strdup("");
      $$.s_name = strdup("");
    } | 
    declaration SEMICOLON declarations {
      stringstream tmp;
      tmp << $1.code << $3.code;
      $$.code = strdup(tmp.str().c_str());
      $$.s_name = strdup("");
    }
    ;

declaration:
  identifiers COLON INTEGER {
    string name($1.s_name);
    string code_str = "";
    while (name.find(' ') != string::npos) {
      int i = name.find(' ');
      string id = name.substr(0, i);
      if (symbols.find(id) == symbols.end()) {
        symbols.insert(id);
        isArr[id] = false;
        code_str.append(". "+id+"\n");
      }
      else {
        errorFlag = true; 
        cout << "Error on line " << currLine << ": symbol \"" << id << "\" is multiply defined\n";
      }
      name = name.substr(i + 1);
    }
    if (symbols.find(name) == symbols.end()) {
      symbols.insert(name);
      isArr[name] = false;
      code_str.append(". "+name+"\n");
    }
    else {
      errorFlag = true; 
      cout << "Error on line " << currLine << ": symbol \"" << name << "\" is multiply defined\n";
    }
    $$.code = strdup(code_str.c_str());
    $$.s_name = strdup("");
  } |
  identifiers COLON ARRAY L_SQUARE_BRACKET NUMBER R_SQUARE_BRACKET OF INTEGER {
    string name($1.s_name);
    string code_str = "";
    while (name.find(' ') != string::npos) {
      int i = name.find(' ');
      string id = name.substr(0, i);
      if (symbols.find(id) == symbols.end()) {
        symbols.insert(id);
        isArr[id] = true;
        code_str.append(".[] "+id+", "+to_string($5)+"\n");
      }
      else {
        errorFlag = true; 
        cout << "Error on line " << currLine << ": symbol \"" << id << "\" is multiply defined\n";
      }
      name = name.substr(i + 1);
    }
    if (symbols.find(name) == symbols.end()) {
      symbols.insert(name);
      isArr[name] = true;
      code_str.append(".[] "+name+", "+to_string($5)+"\n");
    }
    else {
      errorFlag = true; 
      cout << "Error on line " << currLine << ": symbol \"" << name << "\" is multiply defined\n";
    }
    $$.code = strdup(code_str.c_str());
    $$.s_name = strdup("");
  } |
  identifiers COLON ENUM L_PAREN identifiers R_PAREN {
    // Implementation not required since not specified in https://cs152-ucr-gupta.github.io/website/mil.html
  }
  ;

statements:
    {
      // Statements are epsilon
      $$.code = strdup("");
      $$.s_name = strdup("");
    } |
  ;
var:
  IDENT {
    string name($1);
    $$.code = strdup(name.c_str());
    $$.s_name = strdup(name.c_str());
    $$.isArray = isArr[name];
  } |
  IDENT L_SQUARE_BRACKET expression R_SQUARE_BRACKET {
    string name($1);
    $$.code = strdup(name.c_str());
    $$.s_name = strdup(name.c_str());
    $$.isArray = isArr[name];
  }
  ;

expressions:
    {
      // Expressions are epsilon
      $$.code = strdup("");
      $$.s_name = strdup("");
    } |
    expression SEMICOLON expressions {
      stringstream stream;
      stream << $1.code << $3.code;
      $$.code = strdup(stream.str().c_str());
      $$.s_name = strdup("");
    }
    ;

expression:
  IDENT {
    string name($1);
    $$.code = strdup(name.c_str());
    $$.s_name = strdup(name.c_str());
  } |
  IDENT L_SQUARE_BRACKET expression R_SQUARE_BRACKET {
    string name($1);
    $$.code = strdup(name.c_str());
    $$.s_name = strdup(name.c_str());
  } |
  NUMBER {
    stringstream stream;
    stream << "const " << $1;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  } |
  ADD expression {
    stringstream stream;
    stream << "+" << $2.code;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  } |
  SUB expression {
    stringstream stream;
    stream << "-" << $2.code;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  } |
  L_PAREN expression R_PAREN {
    $$.code = strdup($2.code);
    $$.s_name = strdup($2.s_name);
  }
  ;

bool_exp:
  relation_and_exp {
    $$.code = strdup($1.code);
    $$.s_name = strdup($1.s_name);
  } |
  relation_and_exp OR bool_exp {
    string lab1 = newlabel();
    string lab2 = newlabel();
    stringstream stream;
    stream << $1.code << "?:= " << lab1 << ", " << $1.s_name << "\n";
    stream << $3.code << "?:= " << lab1 << ", " << $3.s_name << "\n";
    stream << ":= " << lab2 << "\n";
    stream << ": " << lab1 << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(lab2.c_str());
  }
  ;

relation_and_exp:
  relation_exp {
    $$.code = strdup($1.code);
    $$.s_name = strdup($1.s_name);
  } |
  relation_exp AND relation_and_exp {
    string lab1 = newlabel();
    string lab2 = newlabel();
    stringstream stream;
    stream << $1.code << "?:= " << lab1 << ", " << $1.s_name << "\n";
    stream << $3.code << "?:= " << lab1 << ", " << $3.s_name << "\n";
    stream << ":= " << lab2 << "\n";
    stream << ": " << lab1 << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(lab2.c_str());
  }
  ;

relation_exp:
  comp {
    $$.code = strdup($1.code);
    $$.s_name = strdup($1.s_name);
  } |
  comp EQ comp {
    stringstream stream;
    stream << $1.code << "eq " << $1.s_name << ", " << $3.s_name;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup($1.s_name);
  } |
  comp NEQ comp {
    stringstream stream;
    stream << $1.code << "neq " << $1.s_name << ", " << $3.s_name;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup($1.s_name);
  } |
  comp LT comp {
    stringstream stream;
    stream << $1.code << "lt " << $1.s_name << ", " << $3.s_name;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup($1.s_name);
  } |
  comp LTE comp {
    stringstream stream;
    stream << $1.code << "lte " << $1.s_name << ", " << $3.s_name;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup($1.s_name);
  } |
  comp GT comp {
    stringstream stream;
    stream << $1.code << "gt " << $1.s_name << ", " << $3.s_name;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup($1.s_name);
  } |
  comp GTE comp {
    stringstream stream;
    stream << $1.code << "gte " << $1.s_name << ", " << $3.s_name;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup($1.s_name);
  }
  ;

comp:
  multiplicative_expression {
    $$.code = strdup($1.code);
    $$.s_name = strdup($1.s_name);
  } |
  multiplicative_expression ADD multiplicative_expression {
    stringstream stream;
    stream << $1.code << "+" << $3.code;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  } |
  multiplicative_expression SUB multiplicative_expression {
    stringstream stream;
    stream << $1.code << "-" << $3.code;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  }
  ;

multiplicative_expression:
  term {
    $$.code = strdup($1.code);
    $$.s_name = strdup($1.s_name);
  } |
  term MULT term {
    stringstream stream;
    stream << $1.code << "*" << $3.code;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  } |
  term DIV term {
    stringstream stream;
    stream << $1.code << "/" << $3.code;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  } |
  term MOD term {
    stringstream stream;
    stream << $1.code << "%" << $3.code;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  }
  ;

term:
  IDENT {
    string name($1);
    $$.code = strdup(name.c_str());
    $$.s_name = strdup(name.c_str());
  } |
  NUMBER {
    stringstream stream;
    stream << "const " << $1;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  } |
  L_PAREN expression R_PAREN {
    $$.code = strdup($2.code);
    $$.s_name = strdup($2.s_name);
  }
  ;

identifiers:
    {
      // Identifiers are epsilon
      $$.code = strdup("");
      $$.s_name = strdup("");
    } |
    IDENT COMMA identifiers {
      stringstream stream;
      stream << $1 << " " << $3.code;
      $$.code = strdup(stream.str().c_str());
      $$.s_name = strdup("");
    }
    ;

vars:
    {
      // Vars are epsilon
      $$.code = strdup("");
      $$.s_name = strdup("");
    } |
    var COMMA vars {
      stringstream stream;
      stream << $1.code << " " << $3.code;
      $$.code = strdup(stream.str().c_str());
      $$.s_name = strdup("");
    }
    ;

ident:
  IDENT {
    string name($1);
    $$.code = strdup(name.c_str());
    $$.s_name = strdup(name.c_str());
    $$.isArray = isArr[name];
  } |
  IDENT L_SQUARE_BRACKET expression R_SQUARE_BRACKET {
    string name($1);
    $$.code = strdup(name.c_str());
    $$.s_name = strdup(name.c_str());
    $$.isArray = isArr[name];
  }
  ;

funcid:
  IDENT {
    $$.code = strdup("");
    $$.s_name = strdup($1);
    string id($1);
    if (id == "main") mainFlag = true;
    if (funcs.find(id) == funcs.end()) {
      funcs.insert(id);
    }
    else {
      errorFlag = true;
      cout << "Error on line " << currLine << ": function \"" << id << "\" is multiply defined\n";
    }
  }
  ;

%%

void yyerror(const char *msg);
extern int currLine;
extern int currPos;
extern int yylex();
FILE* fin;
std::string code = "";
bool mainFlag = false;
bool errorFlag = false;
set<string> funcs;
set<string> symbols;
unordered_map<string, bool> isArr;
std::set<std::string> reserved {
    "function", "beginparams", "endparams", "beginlocals", "endlocals", "beginbody", "endbody", "integer", "array",
    "enum","of", "if", "then", "endif", "else", "for", "while", "do", "beginloop", "endloop", "continue", "read", 
    "write", "and", "or", "not", "true", "false", "return"
};
bool_exp:
  relation_and_exp {
    $$.code = strdup($1.code);
    $$.s_name = strdup($1.s_name);
  } |
  relation_and_exp OR bool_exp {
    string temp = newtemp();
    stringstream stream;
    stream << $1.code << $3.code << ". " << temp << "\n";
    stream << "|| " << temp << ", " << $1.s_name << ", " << $3.s_name << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  }
  ;

relation_and_exp:
  relation_exp {
    $$.code = strdup($1.code);
    $$.s_name = strdup($1.s_name);
  } |
  relation_exp AND relation_and_exp {
    string temp = newtemp();
    stringstream stream;
    stream << $1.code << $3.code << ". " << temp << "\n";
    stream << "&& " << temp << ", " << $1.s_name << ", " << $3.s_name << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  }
  ;

relation_exp:
  expression comp expression {
    string temp = newtemp();
    stringstream stream;
    stream << $1.code << $3.code << ". " << temp << "\n" << $2.code << temp << ", " << $1.s_name << ", " << $3.s_name << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  } |
  TRUE {
    string temp("1");
    $$.code = strdup("");
    $$.s_name = strdup(temp.c_str());
  } |
  FALSE {
    string temp("0");
    $$.code = strdup("");
    $$.s_name = strdup(temp.c_str());
  } |
  L_PAREN bool_exp R_PAREN {
    $$.code = strdup($2.code);
    $$.s_name = strdup($2.s_name);
  } |
  NOT expression comp expression {
    string temp = newtemp();
    stringstream stream;
    stream << $2.code << $4.code << ". " << temp << "\n" << $3.code << temp << ", " << $2.s_name << ", " << $4.s_name << "\n";
    stream << "! " << temp << ", " << temp << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  } |
  NOT TRUE {
    string temp("0");
    $$.code = strdup("");
    $$.s_name = strdup(temp.c_str());
  } |
  NOT FALSE {
    string temp("1");
    $$.code = strdup("");
    $$.s_name = strdup(temp.c_str());
  } |
  NOT L_PAREN bool_exp R_PAREN {
    stringstream stream;
    stream << $3.code << "! " << $3.s_name << ", " << $3.s_name << "\n";;
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup($3.s_name);
  }
  ;

comp:
  EQ {
    $$.code = strdup("== ");
    $$.s_name = strdup("");
  } |
  NEQ {
    $$.code = strdup("!= ");
    $$.s_name = strdup("");
  } |
  LT {
    $$.code = strdup("< ");
    $$.s_name = strdup("");
  } |
  GT {
    $$.code = strdup("> ");
    $$.s_name = strdup("");
  } |
  LTE {
    $$.code = strdup("<= ");
    $$.s_name = strdup("");
  } |
  GTE {
    $$.code = strdup(">= ");
    $$.s_name = strdup("");
  }
  ;
expressions:
    {
      //exps -> epsilon
      $$.code = strdup("");
      $$.s_name = strdup("");
    } | 
    expression {
      // Expressions must come from 'ident L_PAREN expressions R_PAREN', so it's the parameters of a function call
      stringstream stream;
      stream << $1.code << "param " << $1.s_name << "\n";
      $$.code = strdup(stream.str().c_str());
      $$.s_name = strdup("");
    } |
    expression COMMA expressions {
      stringstream stream;
      stream << $1.code << "param " << $1.s_name << "\n" << $3.code;
      $$.code = strdup(stream.str().c_str());
      $$.s_name = strdup("");
    }
    ;

expression:
  multiplicative_expression {
    $$.code = strdup($1.code);
    $$.s_name = strdup($1.s_name);
  } |
  multiplicative_expression ADD expression {
    string temp = newtemp();
    stringstream stream;
    stream << $1.code << $3.code << ". " << temp << "\n" << "+ " << temp << ", " << $1.s_name << ", " << $3.s_name << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  } |
  multiplicative_expression SUB expression {
    string temp = newtemp();
    stringstream stream;
    stream << $1.code << $3.code << ". " << temp << "\n" << "- " << temp << ", " << $1.s_name << ", " << $3.s_name << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  }
  ;

multiplicative_expression:
  term {
    $$.code = strdup($1.code);
    $$.s_name = strdup($1.s_name);
  } |
  term MULT multiplicative_expression {
    string temp = newtemp();
    stringstream stream;
    stream << $1.code << $3.code << ". " << temp << "\n" << "* " << temp << ", " << $1.s_name << ", " << $3.s_name << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  } |
  term DIV multiplicative_expression {
    string temp = newtemp();
    stringstream stream;
    stream << $1.code << $3.code << ". " << temp << "\n" << "/ " << temp << ", " << $1.s_name << ", " << $3.s_name << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  } |
  term MOD multiplicative_expression {
    string temp = newtemp();
    stringstream stream;
    stream << $1.code << $3.code << ". " << temp << "\n" << "% " << temp << ", " << $1.s_name << ", " << $3.s_name << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  }
  ;

term:
  ident L_PAREN expressions R_PAREN {
    // This must be a function call
    string temp = newtemp();
    stringstream stream;
    stream << $3.code << ". " << temp << "\ncall " << $1.s_name << ", " << temp << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
    string id($1.s_name);
    if(funcs.find(id) == funcs.end()) {
      errorFlag=true; 
      cout << "Error on line " << currLine << ": use of function \"" << id << "\" is not declared\n";
    }
  } |
  var {
    string temp = newtemp();
    stringstream stream;
    if($1.isArray) { stream << $1.code << ". " << temp << "\n=[] " << temp << ", " << $1.s_name << "\n"; }
    else { stream << ". " << temp << "\n= " << temp << ", " << $1.s_name << "\n" << $1.code;}
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  } |
NUMBER {
    string temp = newtemp();
    stringstream stream;
    stream << ". " << temp << "\n= " << temp << ", " << $1 << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  } |
  L_PAREN expression R_PAREN {
    $$.code = strdup($2.code);
    $$.s_name = strdup($2.s_name);
  } |
  SUB var {
    string temp = newtemp();
    stringstream stream;
    if($2.isArray) { stream << $2.code << ". " << temp << "\n=[] " << temp << ", " << $2.s_name << "\n"; }
    else { stream << ". " << temp << "\n= " << temp << ", " << $2.s_name << "\n" << $2.code; }
    stream << "- " << temp << ", " << 0 << ", " << temp << "\n"; //-v = 0 - v
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  } %prec UMINUS    |
  SUB NUMBER {
    string temp = newtemp();
    stringstream stream;
    stream << ". " << temp << "\n= " << temp << ", -" << $2 << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  } %prec UMINUS    |
  SUB L_PAREN expression R_PAREN {
    string temp = newtemp();
    stringstream stream;
    stream << $3.code << ". " << temp << "\n-" << temp << ", " << 0 << ", " << $3.s_name << "\n";
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup(temp.c_str());
  } %prec UMINUS
  ;

vars:
  var {
    stringstream stream;
    if($1.isArray) { stream << $1.code << ".[]$ " << $1.s_name << "\n"; }
    else { stream << ".$ " << $1.s_name << "\n" << $1.code; }
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  }  |
  var COMMA vars {
    stringstream stream;
    if($1.isArray) { stream << $1.code << ".[]$ " << $1.s_name << "\n" << $3.code; }
    else { stream << $1.code << ".$ " << $1.s_name << "\n" << $3.code; }
    $$.code = strdup(stream.str().c_str());
    $$.s_name = strdup("");
  }
  ;

var:
  ident {
    $$.isArray = false;
    $$.code = strdup("");
    $$.s_name = strdup($1.s_name);
    string id($1.s_name);
    if(symbols.find(id) == symbols.end()) {errorFlag=true; cout << "Error on line " << currLine << ": use of variable \"" << id << "\" is not declared\n";}
    else if(isArr[id]) {errorFlag=true; cout << "Error on line " << currLine << ": use of array variable \"" << id << "\" is missing a specified index\n";}
  } |
  ident L_SQUARE_BRACKET expression R_SQUARE_BRACKET {
    $$.isArray = true;
    $$.code = strdup($3.code);
    stringstream temp;
    temp << $1.s_name << ", " << $3.s_name;
    $$.s_name = strdup(temp.str().c_str());
    string id($1.s_name);
    if(symbols.find(id) == symbols.end()) {errorFlag=true; cout << "Error on line " << currLine << ": use of variable \"" << id << "\" is not declared\n";}
    else if(!isArr[id]) {errorFlag=true; cout << "Error on line " << currLine << ": trying to use regular variable \"" << id << "\" as an array variable\n";}
  }
  ;

identifiers:
  ident {
    $$.code = strdup("");
    $$.s_name = strdup($1.s_name);
  } |
  ident COMMA identifiers {
    $$.code = strdup("");
    stringstream tmp;
    tmp << $1.s_name << " " << $3.s_name;
    $$.s_name = strdup(tmp.str().c_str());
  }
  ;

ident:
  IDENT {
    string id($1);
    transform(id.begin(), id.end(), id.begin(), ::tolower);
    if(reserved.find(id) != reserved.end()) {
      errorFlag = true;
      cout << "Error on line " << currLine << ": trying to use reserved word \"" << id << "\" as a variable name\n";
    }

    $$.code = strdup("");
    $$.s_name = strdup($1); 
  }
  ;
void yyerror(const char *msg);

int main(int argc, char **argv) {
    if (argc >= 2) {
        fin = fopen(argv[1], "r");
        if (fin == NULL) {
            printf("Syntax: %s filename\n", argv[0]);
        }
    }

    // Call the parser function to start parsing.
    yyparse();

    return 0;
}

void yyerror(const char *msg) {
    int flag = 0;
    const char* c = msg;
    while (*c) {
        if (*c++ == ':') {
            if (*c == '\0') { // Colon is the last character.
                flag = 1;
                break;
            }
        }
    }
    if (flag) {
        printf("** Line %d, position %d: Invalid declaration\n", currLine, currPos);
        return;
    }
    printf("** Line %d, position %d: %s\n", currLine, currPos, msg);
}
