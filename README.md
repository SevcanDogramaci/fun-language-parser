# Fun Language Parser

This project is implemented in the extent of CENG 4001 Automata Theory and Formal Language as the term project. 

This project consists of 2 parts:
1. Part: We designed our own programming language consisting of the features:
    - Declaration of variables
    - Initialization of variables
    - Condition statement
    - Loop statement
    - Function statement
2. Part: We implemented a parser for your programming language using Lex and Yacc.
    - Lexical Analysis using Lex
    - Syntactic Analysis (Parsing) using Yacc

## About Parser

Our parser 
- parses an input code and generates a parse tree
- catches the whole syntax errors
    - if any syntax error exists, states an error message with the related line

## File structure

`FunLanguageDesign.md` -> Fun language design description

`fun.l` -> Lexical analyzer code

`fun.y` -> Parser code -> It needs refactoring

`tests.txt` -> Example test cases with fun language syntax

## Requirements
- Flex -> to run lexical analyzer
- Bison -> to run parser
- gcc -> to convert parser to executable

## How to run

```
flex fun.l
bison -d fun.y
gcc -o fun.exe fun.tab.c
fun.exe
```
