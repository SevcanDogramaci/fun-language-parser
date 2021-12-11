/*
Run by the followings:
flex fun.l
bison -d fun.y
gcc -o fun.exe fun.tab.c
fun.exe
*/

%{  
	#include <string.h>
    #include <stdlib.h>
    #include <stdbool.h>
    #include <string.h>
    #include "fun.tab.h"
    extern char* dataType;
	void InvalidToken();
%}

whitespace      [ \t\r\v\f]
linefeed        \n

%%
 /* Reserved Keywords */
"WHILE" {inside_while = true; return WHILE;}
"FUN" { return FUNCTION;}
"IF" { return IF;}
"ELIF" { return ELIF;}
"ELSE" { return ELSE;}
"RETURN" { return RETURN;}

"INT"  { return INT;}
"STR" {return STR;}
"CHAR" { return CHAR;}
"BOOL" {return BOOL;}
"DOUBLE" {return DOUBLE;}

"EXIT()" {return EXIT;}
"PRINT" {return PRINT;}

"=>" { return ARROW_SYMBOL;}
"=" {return ASSIGN;}

 /* Logical Ops */
"|" {return OR;}
"&" {return AND;}

 /* Relational Ops */
"<=" {return LE;}  
">=" {return GE;}  
">" {return GT;}  
"<" {return LT;}  
"!=" {return NE;}    
"==" {return EQ;}  

 /* Separators */
":)" { return END_OF_LINE;}
"{:" { return OPEN_BLOCK;}
":}" { return CLOSE_BLOCK;}
"(" {return OP_P_BR;}
")" {return CL_P_BR;}
"," {return COMMA;}
"[" {return OP_SQ_BR;}
"]" {return CL_SQ_BR;}

 /* Integers */
[-+]?[0-9]+ {   yylval.intVal = atoi(yytext);  
                dataType = "INT";
                return INT_VALUE;}
 /* Doubles */
[-+]?[0-9]*\.?[0-9]+ {  yylval.doubleVal = atof(yytext); 
                        dataType = "DOUBLE";
                        return DOUBLE_VALUE;}

 /* Strings */
\"(\\.|[^"])*\" {   yylval.strVal = strdup(yytext);
                    dataType = "STR";
                    return STR_VALUE;}

 /* Booleans */
TRUE|FALSE {    yylval.charVal = yytext[0];
                dataType = "BOOL";
                return BOOL_VALUE;}

 /* Chars */
[\'][a-zA-Z][\'] {  yylval.charVal = yytext[1];
                    dataType = "CHAR";
                    return CHAR_VALUE;}
 /* Identifiers */ 
[a-z_]+ { yylval.strVal=strdup(yytext); return IDENTIFIER;} 

"+" {return ADD;}
"-" {return SUBTRACT;}
"*" {return MULTIPLY;}
"/" {return DIVIDE;}

{linefeed}                                      {printf(">>> "); yylineno++;}
{whitespace}                                    ;
.                                               {InvalidToken();}
%%

void InvalidToken(){
    printf("ERROR ON LINE %d : \n Invalid Token %s\n", yylineno, yytext);
    exit(0);
}