/*
EXECUTION:
bison -d sample.y   (# create y.tab.h, y.tab.c)
flex sample.l (# create lex.yy.c)
gcc -o sample sample.tab.c
./sample.exe
*/

%{
#include<stdio.h>
#include<stdlib.h>
#include <stdbool.h>
#include <string.h>

#define STACK_LEN 30
#define FUN_ARRAY_LEN 20

int yylex();
void yyerror(const char *s);

 /* Global variables */
int yylineno;
char* dataType;
union yylval;
bool inside_function = false;
bool skip_if = false;
struct node root_node;
bool inside_while = false;
bool skip_next_condition = false;

bool exit_init = false;

// used to keep variable info and contents in the input code. 
typedef struct var {
	char* dataType;
	char* name;
	bool isArray;
	bool isInitialized;

	int intVal;
	char* strVal;
	double doubleVal;
	char charVal;
	bool boolVal;

	// for arrays
	char* strArr[20];
	int arraySize;
	int intArr[20];
	double doubleArr[20];
	char charArr[20];
	bool boolArr[20];
} var;
// points to the top of the stack array. 
int stack_top = -1; 
// points to the top of the function array. 
int fun_array_top = 0;

// used to keep function info and contents in the input code. 
struct stack_item{
	int var_array_len;
	char* fun_name;
	char* return_type;
	struct var *var_array;
} stack[STACK_LEN], fun_array[FUN_ARRAY_LEN]; // stack -> to keep variables in the scope, fun_array -> to keep function definitions. 

 /* Functions */
 // utility function to split strings.
 char *strsep(char **stringp, const char *delim) {
  if (*stringp == NULL) { return NULL; }
  char *token_start = *stringp;
  *stringp = strpbrk(token_start, delim);
  if (*stringp) {
    **stringp = '\0';
    (*stringp)++;
  }
  return token_start;
}

bool skip() {return inside_function || skip_if || inside_while; }
// add variable to stack item's var array 
void add_variable(struct var variable){
	

	int len = stack[stack_top].var_array_len;
	stack[stack_top].var_array[len] = variable;
	printf("\tvar_name: %s, var_type: %s\n", stack[stack_top].var_array[len].name, variable.dataType);
	stack[stack_top].var_array_len += 1;
	struct stack_item fun = stack[stack_top];
}

struct var x;

// get variable from stack item's var array
struct var *get_variable(char* var_name, bool isArray){ 
	int i;

	for (i=0; i<stack[stack_top].var_array_len; i++){
		if (!strcmp(var_name, stack[stack_top].var_array[i].name))
		{	
			if (isArray != stack[stack_top].var_array[i].isArray) yyerror("Wrong access=> array/variable\n");
			
			return &stack[stack_top].var_array[i];
		}
	}

	return &x;
}

// Finds the variable in stack and converts its value to string and returns the string
char* get_var_value(struct var *variable){

	char result[50];
	dataType = strdup(variable->dataType);

	if (!strcmp(variable->dataType, "INT")){		
		sprintf(result, "%d", variable->intVal);
	}
	else if (!strcmp(variable->dataType, "DOUBLE")){		 	
		sprintf(result, "%f", variable->doubleVal);
	}
	else if (!strcmp(variable->dataType, "CHAR")){		 	
		sprintf(result, "%c", variable->charVal);
	}
	else if (!strcmp(variable->dataType, "BOOL")){
		if (variable->boolVal) sprintf(result, "%c", 'T'); 
		else sprintf(result, "%c", 'F'); 
	}
	else if (!strcmp(variable->dataType, "STR")){		 	
		return strdup(variable->strVal);
	} else yyerror("Wrong data type!\n");

	return strdup(result);
}

// check if identifier used before. 
bool check_identifier(char* identifier_name, struct stack_item function){
	int i = 0;
	for (; i < function.var_array_len; i++){
		if (!strcmp(identifier_name, function.var_array[i].name)) yyerror("Identifier with same name already defined!");
	}
	return true;
}

// check if a function with the same name defined before. 
bool is_function_exists(struct stack_item fun){
	for (int i = 0; i < fun_array_top; i++){
		struct stack_item fun_to_compare = fun_array[i];
		if (!strcmp(fun_to_compare.fun_name, fun.fun_name))
			return true;
	}
	return false;
}
// check if a function with the same name defined before. 
bool check_function_name(char *name){
	for (int i = 0; i < fun_array_top; i++){
		struct stack_item fun_to_compare = fun_array[i];
		if (!strcmp(fun_to_compare.fun_name, name))
			return true;
	}
	return false;
}

struct stack_item null_function;
// check if a function with the same name defined before. 
struct stack_item *get_function(char *name){
	for (int i = 0; i < fun_array_top; i++){
		if (!strcmp(fun_array[i].fun_name, name))
			return &(fun_array[i]);
	}
	null_function.fun_name = NULL;
	return &null_function;
}

void add_function_to_fun_array(struct stack_item fun){
	if (fun_array_top >= FUN_ARRAY_LEN) yyerror("Max number of functions reached!");
	if(is_function_exists(fun)) yyerror("Function with name is already defined!");

    fun_array[fun_array_top] = fun;
	fun_array_top++;
	printf("\tFunction\n\tname: %s\n\treturn type:%s\n\tparam len:%d\n\t", fun.fun_name, fun.return_type, fun.var_array_len);
}

void add_function_to_stack(struct stack_item fun){
    stack_top++;
    stack[stack_top] = fun;
}

void remove_function_from_stack(){
	stack_top--;
}

// Input char** => TYPE VALUE -> return TYPE, input pointers points to VALUE
char* split_var_encoding(char** encoding_pointer){
	int i = 0;
	char* encoding = *encoding_pointer;
	char type[10];
	while(encoding[i] != ' '){
		type[i] = encoding[i];
		i++;
	}
	type[i] = '\0';
	*encoding_pointer = encoding+(i+1);

	return strdup(type);
}

// Returns value of array element as string.
char* get_arr_el_value(struct var *variable, int arr_id){

	char result[50];
	dataType = strdup(variable->dataType);

	if (!strcmp(variable->dataType, "INT")){		
		sprintf(result, "%d", variable->intArr[arr_id]);
	}
	else if (!strcmp(variable->dataType, "DOUBLE")){		 	
		sprintf(result, "%f", variable->doubleArr[arr_id]);
	}
	else if (!strcmp(variable->dataType, "CHAR")){		 	
		sprintf(result, "%c", variable->charArr[arr_id]);
	}
	else if (!strcmp(variable->dataType, "BOOL")){
		if (variable->boolArr[arr_id]) sprintf(result, "%c", 'T'); 
		else sprintf(result, "%c", 'F'); 
	}
	else if (!strcmp(variable->dataType, "STR")){		 	
		return strdup(variable->strArr[arr_id]);
	} else yyerror("Wrong data type!\n");

	return strdup(result);
}

// Used as parse tree node. 
typedef struct node {
	char* treeValue;
	int childCount;
	struct node *childs;
	bool is_terminal;
	char* returnValue;
} node;

// Print parse tree in a formatted way. 
void print_tree(node *root, int tab){


	int i = 0;
	int j = 0;
	for (; j < tab; j++)
		printf("\t");
	if (root->is_terminal) {
		printf("<< %s - %s >>\n", root->treeValue,root->returnValue);
		return;
	}

	printf("%s\n", root->treeValue);

	for (; i < root->childCount; i++){
		print_tree(&(root->childs[i]), tab+1);
	}
}

%}

// for using multiple data types
%union {
  int intVal;
  char* strVal;
  double doubleVal;
  char charVal;
  bool boolVal;
  struct node nodeVal;
}

%token <intVal> INT_VALUE
%token <doubleVal> DOUBLE_VALUE
%token <strVal> STR_VALUE 
%token <strVal> IDENTIFIER COMMA
%token <boolVal> BOOL_VALUE
%token <charVal> CHAR_VALUE

%token OP_P_BR CL_P_BR OP_SQ_BR CL_SQ_BR 
%token ASSIGN ARROW_SYMBOL END_OF_LINE OPEN_BLOCK CLOSE_BLOCK
%token AND OR GE NE LT GT LE EQ 
%token WHILE FUNCTION IF RETURN ELIF ELSE EXIT PRINT
%token INT STR CHAR BOOL DOUBLE
%token ADD SUBTRACT MULTIPLY DIVIDE
%left GE NE LT GT LE EQ  
%right ASSIGN '^'   

%type<nodeVal> VALUE VAR_TYPE ST S ARITHMETIC_OPERATION ARITHMETIC_OPERATOR ARRAY_DEFINITION ARRAY_EL_DEFINITION FUN_BLOCK FUNCTION_DEFINITION RETURN_ST
%type<nodeVal> FUN_PARAM FUN_PARAMS  FUN_CALL_PARAM FUN_CALL_PARAMS CONDITION_PARENT CONDITION CONDITION_ST RELOP AND_OR ST_BLOCK ELIF_ST ELSE_ST

%%

 /*Grammar*/
ROOT : S {
	root_node= $1;
}

S : ST { 

		struct node current_node ;
		current_node.treeValue = "S";
		current_node.childCount = 1;
		current_node.is_terminal = false;
		current_node.childs = (struct node *) malloc(sizeof(struct node) * 1);
		current_node.childs[0] = $1;
		$$ = current_node;
		if (exit_init){
			root_node = current_node;
			YYACCEPT;
		}
	}
	| S ST { 
		struct node current_node ;
		current_node.treeValue = "S";
		current_node.childCount = 2;
		current_node.is_terminal = false;
		current_node.childs = (struct node *) malloc(sizeof(struct node) * current_node.childCount);
		current_node.childs[0] = $1;
		current_node.childs[1] = $2;
		$$ = current_node; 
		if (exit_init){
			root_node = current_node;
			YYACCEPT;
		}
	}

ST: IDENTIFIER ARROW_SYMBOL VAR_TYPE END_OF_LINE {
		struct node eof = {"END OF LINE", 0, NULL, true, ":)"};
		struct node arrow = {"ARROW", 0, NULL, true, "=>"};
		struct node id = {"IDENTIFIER", 0, NULL, true, strdup($1)};
		struct node current_node ;
		current_node.treeValue = "ST";
		current_node.childCount = 4;
		current_node.is_terminal = false;
		current_node.childs = (struct node *) malloc(sizeof(struct node) * 4);
		current_node.childs[0] = id; current_node.childs[1] = arrow; current_node.childs[2] = $3; current_node.childs[3] = eof;
		$$ = current_node;

		if (!skip()){ 
			struct var variable;
			variable.name = strdup($1);
			variable.dataType = strdup($3.returnValue);
			variable.isArray = false;
			variable.isInitialized = false;
			if(check_identifier(variable.name, stack[stack_top]))
				add_variable(variable);
			}
	}
	| EXIT END_OF_LINE { 
		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 2);
		struct node eof = {"END OF LINE", 0, NULL, true, ":)"};
		struct node exit_node = {"EXIT()", 0, NULL, true, "EXIT()"};
		child_array[0] = exit_node; child_array[1] = eof; 
		struct node current_node = {"ST", 2, child_array, false, NULL};
		$$ = current_node;
		if (!skip()){
			exit_init = true;
		}
	}
	| PRINT OP_P_BR VALUE CL_P_BR END_OF_LINE {
		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 5);
		struct node print_node = {"PRINT", 1, child_array, true, "PRINT"};
		struct node eof = {"END OF LINE", 0, NULL, true, ":)"};
		struct node op_node = {"OP P BR", 0, NULL, true, "("};
		struct node cl_node = {"CL P BR", 0, NULL, true, ")"};
		
		child_array[0] = print_node; child_array[1] = op_node; child_array[2] = $3; child_array[3] = cl_node; child_array[4] = eof; 
		struct node current_node = {"ST", 5, child_array, false, NULL};
		$$ = current_node;
		if (!skip()){
			split_var_encoding(&($3.returnValue));
			printf("\tOutput -> %s\n", $3.returnValue);
		}
	}
 	| FUNCTION_DEFINITION FUN_BLOCK { 
		inside_function = false;
		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 2);
		child_array[0] = $1; child_array[1] = $2; 
		struct node current_node = {"ST", 2, child_array, false, NULL};
		$$ = current_node;
	}
	| WHILE OP_P_BR CONDITION_PARENT CL_P_BR ST_BLOCK {
		struct node while_node = {"WHILE", 0, NULL, true, "WHILE"};
		struct node op_node = {"OP P BR", 0, NULL, true, "("};
		struct node cl_node = {"CL P BR", 0, NULL, true, ")"};

		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 5);
		child_array[0] = while_node; child_array[1] = op_node; child_array[2] = $3; 
		child_array[3] = cl_node; child_array[4] = $5; 

		struct node current_node = {"ST", 5, child_array, false, NULL};
		$$ = current_node;
		inside_while = false
	}
	| IF OP_P_BR CONDITION_PARENT CL_P_BR ST_BLOCK ELIF_ST ELSE_ST { 
		struct node if_node = {"IF", 0, NULL, true, "IF"};
		struct node op_node = {"OP P BR", 0, NULL, true, "("};
		struct node cl_node = {"CL P BR", 0, NULL, true, ")"};

		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 7);
		child_array[0] = if_node; child_array[1] = op_node; child_array[2] = $3; 
		child_array[3] = cl_node; child_array[4] = $5; child_array[5] = $6; child_array[6] = $7; 

		struct node current_node = {"ST", 7, child_array, false, NULL};
		$$ = current_node;
		skip_if = false;
		skip_next_condition = false;
	}
	| ARRAY_DEFINITION {
		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
		child_array[0] = $1;
		struct  node current_node = {"ST", 1, child_array, false, NULL}; 
		$$ = current_node;
		}
	| ARRAY_EL_DEFINITION {
		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
		child_array[0] = $1;
		struct  node current_node = {"ST", 1, child_array, false, NULL};
		$$ = current_node;
		}
	| IDENTIFIER ASSIGN ARITHMETIC_OPERATION END_OF_LINE {
		struct node eof = {"END OF LINE", 0, NULL, true, ":)"};
		struct node assign = {"ASSIGN", 0, NULL, true, "="};
		struct node id = {"IDENTIFIER", 0, NULL, true, strdup($1)};
		struct node current_node ;
		current_node.treeValue = "ST";
		current_node.childCount = 4;
		current_node.is_terminal = false;
		current_node.childs = (struct node *) malloc(sizeof(struct node) * current_node.childCount);
		current_node.childs[0] = id; current_node.childs[1] = assign; current_node.childs[2] = $3; current_node.childs[3] = eof;
		$$ = current_node;

		if (!skip()){  
			
			var *variable = get_variable($1, false);
			if (variable->name == NULL){ yyerror("Variable is not defined!");}
			if(strcmp(variable->dataType, "INT") && strcmp(variable->dataType, "DOUBLE")) yyerror("Unsupported operation!");
			variable->isInitialized = true;
			if(!strcmp(variable->dataType, "INT")){
				variable->intVal = atoi($3.returnValue);
			}
			else{
				variable->doubleVal = atof($3.returnValue);
			}
		}
	}
	| IDENTIFIER ASSIGN VALUE END_OF_LINE { 
		struct node eof = {"END OF LINE", 0, NULL, true, ":)"};
		struct node assign = {"ASSIGN", 0, NULL, true, "="};
		struct node id = {"IDENTIFIER", 0, NULL, true, strdup($1)};
		struct node current_node ;
		current_node.treeValue = "ST";
		current_node.childCount = 4;
		current_node.is_terminal = false;
		current_node.childs = (struct node *) malloc(sizeof(struct node) * current_node.childCount);
		current_node.childs[0] = id; current_node.childs[1] = assign; current_node.childs[2] = $3; current_node.childs[3] = eof;
		$$ = current_node;

		// variable definition recognized
		// assign variable's value and type
		if (!skip()){  
			struct node eof = {"END OF LINE", 0, NULL, true, ":)"};
			struct node assign = {"ASSIGN", 0, NULL, true, "="};
			struct node id = {"IDENTIFIER", 0, NULL, true, strdup($1)};
			struct node current_node ;
			current_node.treeValue = "ST";
			current_node.childCount = 4;
			current_node.is_terminal = false;
			current_node.childs = (struct node *) malloc(sizeof(struct node) * current_node.childCount);
			current_node.childs[0] = id; current_node.childs[1] = assign; current_node.childs[2] = $3; current_node.childs[3] = eof;
			$$ = current_node;
			var *variable = get_variable(strdup($1), false);
			split_var_encoding(&($3.returnValue));

			if (variable->name == NULL){ yyerror("Variable is not defined!");}
						
			if(!strcmp(variable->dataType, dataType)){
				if (!strcmp(variable->dataType, "INT")){		
					variable->intVal = atoi($3.returnValue);
					printf("\t%s is set to %d\n", variable->name, variable->intVal);
				}
				else if (!strcmp(variable->dataType, "DOUBLE")){		 	
					variable->doubleVal = atof($3.returnValue);
					printf("\t%s is set to %f\n", variable->name, variable->doubleVal);
				}
				else if (!strcmp(variable->dataType, "CHAR")){		 	
					variable->charVal = $3.returnValue[0];
					printf("\t%s is set to %c\n", variable->name, variable->charVal);
				}
				else if (!strcmp(variable->dataType, "BOOL")){	
					if($3.returnValue[0] == 'T') {variable->boolVal = true;}
					else if($3.returnValue[0] == 'F'){variable->boolVal = false;} 	 	
					printf("\t%s is set to %d\n", variable->name, variable->boolVal);
				}
				else if (!strcmp(variable->dataType, "STR")){		 	
					variable->strVal = $3.returnValue;
					printf("\t%s is set to %s\n", variable->name, variable->strVal);
				}
				variable->isInitialized = true;
			} else yyerror("Wrong data type!\n");
		}
	} 
	| IDENTIFIER OP_P_BR FUN_CALL_PARAMS CL_P_BR END_OF_LINE {
		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 5);
		struct node id = {"IDENTIFIER", 0, NULL, true, strdup($1)};
		struct node eof = {"END OF LINE", 0, NULL, true, ":)"};
		struct node op_node = {"OP P BR", 0, NULL, true, "("};
		struct node cl_node = {"CL P BR", 0, NULL, true, ")"};
		child_array[0] = id; child_array[1] = op_node; child_array[2] = $3; child_array[3] = cl_node; child_array[4] = eof; 
		struct node current_node = {"ST", 5, child_array, false, NULL};
		$$= current_node;
		if (!skip()){
			struct stack_item *function = get_function(strdup($1));
			if (function->fun_name == NULL) yyerror("Function is not defined! ");

			char *params_str = strdup($3.returnValue);

			int i = 0, param_count = 0;
			while(params_str[i] != '\0'){
				if (params_str[i] == ' ')
					param_count++;
				i++;
			}

			if (param_count > 0) {param_count = (param_count + 1)/2;}
			if (param_count != function->var_array_len) yyerror("Invalid number of parameters! \n");

			char *token, *str;
			str = strdup(params_str);
			i = 0;	
			int j = 0;
			while ((token = strsep(&str, " "))){
				if (i%2 == 0){
					if(strcmp(function->var_array[j].dataType, token)) yyerror("Unexpected data type!\n ");
				} else {
					j++;
				}
				i++;
			}
		}
	}
FUNCTION_DEFINITION : FUNCTION IDENTIFIER OP_P_BR FUN_PARAMS CL_P_BR ARROW_SYMBOL VAR_TYPE {
		inside_function = true;

		struct node fun = {"FUNCTION", 0, NULL, true, ":)"};
		struct node id = {"IDENTIFIER", 0, NULL, true, strdup($2)};
		struct node op_node = {"OP P BR", 0, NULL, true, "("};
		struct node assign = {"ARROW", 0, NULL, true, "=>"};
		struct node cl_node = {"CL P BR", 0, NULL, true, ")"};
		struct node current_node ;
		current_node.treeValue = "FUNCTION DEFINITION";
		current_node.childCount = 7;
		current_node.is_terminal = false;
		current_node.childs = (struct node *) malloc(sizeof(struct node) * current_node.childCount);
		current_node.childs[0] = fun; current_node.childs[1] = id; current_node.childs[2] = op_node; 
		current_node.childs[3] = $4; current_node.childs[4] = cl_node; current_node.childs[5] = assign; 
		current_node.childs[6] = $7; 
		$$ = current_node;
		struct stack_item function;
		function.fun_name = strdup($2);
		function.return_type = strdup($7.returnValue);

		int i = 0, param_count = 0;
		while($4.returnValue[i] != '\0'){
			if ($4.returnValue[i] == ' ')
				param_count++;
			i++;
		}

		if (param_count > 0) {param_count = (param_count + 1)/2;}

		char *token, *str;
		function.var_array = (struct var *) malloc(sizeof(struct var) * param_count);

		str = strdup($4.returnValue);
		i = 0;	
		int j = 0;
		while ((token = strsep(&str, " "))){
			if (i%2 == 0){
				function.var_array[j].dataType = token;
			} 
			else{
				function.var_array[j].name = token;
				j++;
			}
			i++;
		} 

		function.var_array_len = param_count;
		add_function_to_fun_array(function);
}
ST_BLOCK : OPEN_BLOCK S CLOSE_BLOCK { 	
				struct node op_node = {"OPEN BLOCK", 0, NULL, true, "{:"};
				struct node cls_node = {"CLOSE BLOCK", 0, NULL, true, ":}"};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 3);
				
				child_array[0] = op_node; child_array[1] = $2; child_array[2] = cls_node;
				struct  node current_node = {"ST BLOCK", 3, child_array, false, "-"};
				$$ = current_node; 
				skip_if = false;
				}
FUN_BLOCK : OPEN_BLOCK S RETURN_ST CLOSE_BLOCK { 	
				struct node op_node = {"OPEN BLOCK", 0, NULL, true, "{:"};
				struct node cls_node = {"CLOSE BLOCK", 0, NULL, true, ":}"};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 4);
				
				child_array[0] = op_node; child_array[1] = $2; 
				child_array[2] = $3; child_array[3] = cls_node;
				struct  node current_node = {"FUN BLOCK", 4, child_array, false, "-"};
				$$ = current_node; 
				}
RETURN_ST : RETURN VALUE END_OF_LINE { 	
				struct node return_node = {"RETURN", 0, NULL, true, "RETURN"};
				struct node eol = {"END OF LINE", 0, NULL, true, ":)"};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 3);
				
				child_array[0] = return_node; child_array[1] = $2; child_array[2] = eol; 
				struct  node current_node = {"RETURN ST", 3, child_array, false, "-"};
				$$ = current_node; 
				}
		  | RETURN END_OF_LINE { 	
				struct node return_node = {"RETURN", 0, NULL, true, "RETURN"};
				struct node eol = {"END OF LINE", 0, NULL, true, ":)"};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 2);
				
				child_array[0] = return_node; child_array[1] = eol; 
				struct  node current_node = {"RETURN ST", 2, child_array, false, "-"};
				$$ = current_node; 
				}

ELIF_ST:	{
				struct  node current_node = {"ELIF ST", 0, NULL, false, ""};
				$$ = current_node; 
				if (skip_next_condition) skip_if = true;
				else skip_if = false;
			}
		 	| ELIF OP_P_BR CONDITION_PARENT CL_P_BR ST_BLOCK {
				struct node elif = {"ELIF", 0, NULL, true, "ELIF"};
				struct node op_node = {"OP P BR", 0, NULL, true, "("};
				struct node cls_node = {"CL P BR", 0, NULL, true, ")"};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 5);
				child_array[0] = elif; child_array[1] = op_node; child_array[2] = $3; 
				child_array[3] = cls_node; child_array[4] = $5; 

				struct  node current_node = {"ELIF ST", 5, child_array, false, ""};
				$$ = current_node; 
				if (skip_next_condition) skip_if = true;
				else skip_if = false;
			}

ELSE_ST: 	{
				struct  node current_node = {"ELSE ST", 0, NULL, false, ""};
				$$ = current_node; 
			}
			| ELSE ST_BLOCK {
				struct node else_node = {"ELSE", 0, NULL, true, "ELSE"};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 2);
				child_array[0] = else_node; child_array[1] = $2; 

				struct  node current_node = {"ELSE ST", 2, child_array, false, ""};
				$$ = current_node; 
			}
CONDITION_PARENT : CONDITION_ST {
	struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
	child_array[0] = $1; 
	struct  node current_node = {"CONDITION_PAR", 1, child_array, false, ""};
	$$ = current_node; 

	if (!(inside_function || inside_while )){
		if (!skip_next_condition){
			if ($1.returnValue[0] == '1'){

				skip_if = false;
				skip_next_condition = true;
			} else {
				skip_if = true;
			}
		} else skip_if = true;
	}
}

CONDITION_ST : CONDITION {
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = $1; 

				struct  node current_node = {"CONDITION ST", 1, child_array, false, ""};
				$$ = current_node; 
				if (!(inside_function || inside_while )){
					if (!skip_next_condition){
						$$.returnValue = strdup($1.returnValue);
					}
				}
			} | CONDITION AND_OR CONDITION_ST {
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 3);
				child_array[0] = $1; child_array[1] = $2; child_array[2] = $3; 

				struct  node current_node = {"CONDITION ST", 3, child_array, false, ""};
				$$ = current_node; 
				if (!(inside_function || inside_while)){
					if (!skip_next_condition){
						bool c1 = $1.returnValue[0] == '1';
						bool c2 = $3.returnValue[0] == '1';
						bool result;
						if ($2.returnValue[0] == 'A')
							result = c1 && c2;
						else
							result = c1 || c2;
						
						if (result) $$.returnValue = "1";
						else $$.returnValue = "0";
					}
				}
			}
CONDITION : VALUE RELOP VALUE {
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 3);
				child_array[0] = $1; child_array[1] = $2; child_array[2] = $3; 

				struct  node current_node = {"CONDITION", 3, child_array, false, ""};
				$$ = current_node; 

				if (!(inside_function || inside_while)){
					char *firstDataType = split_var_encoding(&($1.returnValue));
					char *secondDataType = split_var_encoding(&($3.returnValue));

					if (strcmp(firstDataType, secondDataType)) yyerror("Data types are not same! ");
					if (!strcmp(firstDataType, "STR")) yyerror("Strings are not allowed in comparisons! ");

					if (!strcmp($2.returnValue, "<")){
						if (!strcmp(firstDataType, "BOOL") || !strcmp(firstDataType, "CHAR") ) yyerror("Booleans and characters are not allowed in comparisons! "); 
						if (!strcmp(firstDataType, "INT")){
							if (atoi($1.returnValue) < atoi($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
						else if (!strcmp(firstDataType, "DOUBLE")){
							if (atof($1.returnValue) < atof($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
					} else if (!strcmp($2.returnValue, ">")){
						if (!strcmp(firstDataType, "BOOL") || !strcmp(firstDataType, "CHAR") ) yyerror("Booleans and characters are not allowed in comparisons! "); 
						if (!strcmp(firstDataType, "INT")){
							if (atoi($1.returnValue) > atoi($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
						else if (!strcmp(firstDataType, "DOUBLE")){
							if (atof($1.returnValue) > atof($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
					} else if (!strcmp($2.returnValue, "<=")){
						if (!strcmp(firstDataType, "BOOL") || !strcmp(firstDataType, "CHAR") ) yyerror("Booleans and characters are not allowed in comparisons! "); 
						if (!strcmp(firstDataType, "INT")){
							if (atoi($1.returnValue) <= atoi($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
						else if (!strcmp(firstDataType, "DOUBLE")){
							if (atof($1.returnValue) <= atof($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						} 
					} else if (!strcmp($2.returnValue, ">=")){
						if (!strcmp(firstDataType, "BOOL") || !strcmp(firstDataType, "CHAR") ) yyerror("Booleans and characters are not allowed in comparisons! "); 
						if (!strcmp(firstDataType, "INT")){
							if (atoi($1.returnValue) >= atoi($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
						else if (!strcmp(firstDataType, "DOUBLE")){
							if (atof($1.returnValue) >= atof($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
					} else if (!strcmp($2.returnValue, "==")){
						if (!strcmp(firstDataType, "INT")){
							if (atoi($1.returnValue) == atoi($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
						else if (!strcmp(firstDataType, "DOUBLE")){
							if (atof($1.returnValue) == atof($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
						else if (!strcmp(firstDataType, "BOOL")){
							if ($1.returnValue[0] == $3.returnValue[0])
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
						else if (!strcmp(firstDataType, "CHAR")){
							if ($1.returnValue[0] == $3.returnValue[0])
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
					} else if (!strcmp($2.returnValue, "!=")){
						if (!strcmp(firstDataType, "INT")){
							if (atoi($1.returnValue) != atoi($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
						else if (!strcmp(firstDataType, "DOUBLE")){
							if (atof($1.returnValue) != atof($3.returnValue))
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
						else if (!strcmp(firstDataType, "BOOL")){
							if ($1.returnValue[0] != $3.returnValue[0])
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
						else if (!strcmp(firstDataType, "CHAR")){
							if ($1.returnValue[0] != $3.returnValue[0])
								$$.returnValue = "1";
							else $$.returnValue = "0";
						}
					}
					
				}
			}
			| VALUE {
				
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = $1; 

				struct node current_node = {"CONDITION", 1, child_array, false, ""};
				$$ = current_node; 

				if (!(inside_function || inside_while)){
					char* type = split_var_encoding(&($1.returnValue));

					if (strcmp(type, "BOOL")) yyerror("Not a logical statement ! ");

					if ( $1.returnValue[0] == 'T') $$.returnValue = "1";
					else $$.returnValue = "0";
				}
			}

AND_OR : AND {
				struct node and = {"AND", 0, NULL, true, "&"};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = and; 

				struct  node current_node = {"AND OR", 1, child_array, false, "AND"};
				$$ = current_node; 
			} 
		| OR {
				struct node or = {"OR", 0, NULL, true, "|"};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = or;  

				struct  node current_node = {"AND OR", 1, child_array, false, "OR"};
				$$ = current_node; 
			}

VALUE : IDENTIFIER { 
			struct node id = {"IDENTIFIER", 0, NULL, true, strdup($1)};
			struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
			child_array[0] = id;
			struct  node current_node = {"VALUE", 1, child_array, false, NULL};
			$$ = current_node;

			if (!skip()){
				var *variable = get_variable($1, false);
				if (variable->name == NULL) yyerror("This variable is not defined!\n");
				if (!variable->isInitialized) yyerror("This variable is not initialized!\n");
				char* value = get_var_value(variable);
				if (strcmp(variable->dataType, dataType)) yyerror("Wrong data type!\n");
				else {  
					char* x = strcat(strdup(dataType), " "); 
					$$.returnValue = strcat(x,value);
				}
			}
		}
		| INT_VALUE {
			char result[50]; 
			sprintf(result, "%d", yylval.intVal); 
			struct node value = {"INT VAL", 0, NULL, true, strdup(result)};
			struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
			child_array[0] = value;
			struct  node current_node = {"VALUE", 1, child_array, false, NULL};
			$$ = current_node;

			if (!skip()){ 
			char* x = strcat(strdup(dataType), " "); 
			$$.returnValue = strcat(x,strdup(result));
			}
		} 
		| DOUBLE_VALUE {
			char result[50]; 
			sprintf(result, "%f", yylval.doubleVal); 
			struct node value = {"DOUBLE VAL", 0, NULL, true, strdup(result)};
			struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
			child_array[0] = value;
			struct  node current_node = {"VALUE", 1, child_array, false, NULL};
			$$ = current_node;
			if (!skip()){ 
				char* x = strcat(strdup(dataType), " "); 
				$$.returnValue = strcat(x,strdup(result));
			} 
		}
		| BOOL_VALUE {  
			char result[2]; 
			sprintf(result, "%c", yylval.charVal);
			struct node value = {"BOOL VAL", 0, NULL, true, strdup(result)};
			struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
			child_array[0] = value;
			struct  node current_node = {"VALUE", 1, child_array, false, NULL};
			$$ = current_node;
			if (!skip()){
				char* x = strcat(strdup(dataType), " "); 
				$$.returnValue = strcat(x,strdup(result));
			}
		} 
		| STR_VALUE {
			struct node value = {"STR VALUE", 0, NULL, true, strdup( yylval.strVal)};
			struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
			child_array[0] = value;
			struct  node current_node = {"VALUE", 1, child_array, false, NULL};
			$$ = current_node; 
			if (!skip()){  
				char* x = strcat(strdup(dataType), " "); 
				$$.returnValue = strcat(x,strdup( yylval.strVal));
			}
		} 
		| CHAR_VALUE {
			char result[2]; 
			sprintf(result, "%c", yylval.charVal); 
			struct node value = {"CHAR VALUE", 0, NULL, true, strdup(result)};
			struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
			child_array[0] = value;
			struct  node current_node = {"VALUE", 1, child_array, false, NULL};
			$$ = current_node; 
			if (!skip()){  
				char* x = strcat(strdup(dataType), " "); 
				$$.returnValue = strcat(x,strdup(result));
			} 
		}
		| IDENTIFIER OP_SQ_BR INT_VALUE CL_SQ_BR { 
			struct node val = {"IDENTIFIER", 0, NULL, true, strdup($1)};
			struct node op_br = {"OP SQ BR", 0, NULL, true, "["};  
			char result[50]; sprintf(result, "%d", yylval.intVal); 
			struct node int_val = {"INT VALUE", 0, NULL, true, strdup(result)}; 
			struct node cl_br = {"CL SQ BR", 0, NULL, true, "]"}; 
			struct node *child_array = (struct node *) malloc(sizeof(struct node) * 4);
			child_array[0] = val; child_array[1] = op_br; child_array[2] = int_val; child_array[3] = cl_br;
			struct  node current_node = {"VALUE", 4, child_array, false, NULL};
			$$ = current_node;
			if (!skip()){
				var *variable = get_variable($1, true);
				int arr_id = yylval.intVal;
				if (variable->name == NULL) yyerror("This variable is not defined!\n");
				if (arr_id >= variable->arraySize || arr_id < 0) yyerror("Wrong index! \n");
				
				char* value = get_arr_el_value(variable, arr_id);
				if (strcmp(variable->dataType, dataType)) yyerror("Wrong data type!\n");
				else { char* x = strcat(strdup(dataType), " "); 
					$$.returnValue = strcat(x,value);
				}
			}
		}
RELOP : LT {
				struct node op = {"LT", 0, NULL, true, "<"};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = op;  

				struct  node current_node = {"RELOP", 1, child_array, false, "<"};
				$$ = current_node; 
			} 
		| GT {
				struct node op = {"GT", 0, NULL, true, ">"};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = op;  

				struct  node current_node = {"RELOP", 1, child_array, false, ">"};
				$$ = current_node; 
			}
		| LE {
				struct node op = {"LE", 0, NULL, true, "<="};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = op;  

				struct  node current_node = {"RELOP", 1, child_array, false, "<="};
				$$ = current_node; 
			}
		| GE {
				struct node op = {"GE", 0, NULL, true, ">="};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = op;  

				struct  node current_node = {"RELOP", 1, child_array, false, ">="};
				$$ = current_node; 
			}
		| EQ {
				struct node op = {"EQ", 0, NULL, true, "=="};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = op;  

				struct  node current_node = {"RELOP", 1, child_array, false, "=="};
				$$ = current_node; 
			}
		| NE {
				struct node op = {"NE", 0, NULL, true, "!="};
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = op;  

				struct  node current_node = {"RELOP", 1, child_array, false, "!="};
				$$ = current_node; 
			}

VAR_TYPE: INT {	 	
					struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
					struct node child ={"INT", 1, NULL, true, strdup("INT")};
					child_array[0] = child;
					struct  node current_node = {"VAR TYPE", 1, child_array, false, strdup("INT")};
					$$ = current_node; 
				}
		| CHAR  { 		
					struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
					struct node child = {"CHAR", 1, NULL, true, strdup("CHAR")};
					child_array[0] = child;
					struct  node current_node = {"VAR TYPE", 1, child_array, false, strdup("CHAR")};
					$$ = current_node; 
				}
		| STR  { 		
					struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
					struct node child = {"STR", 1, NULL , true, strdup("STR")};
					child_array[0] = child;
					struct  node current_node = {"VAR TYPE", 1, child_array, false, strdup("STR")};
					$$ = current_node;
				}
		| BOOL  { 		
					struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
					struct node child = {"BOOL", 1, NULL, true, strdup("BOOL")};
					child_array[0] = child;
					struct  node current_node = {"VAR TYPE", 1, child_array, false, strdup("BOOL")};
					$$ = current_node;
				}
		| DOUBLE  { 		
					struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
					struct node child = {"DOUBLE", 1, NULL, true, strdup("DOUBLE")};
					child_array[0] = child;
					struct  node current_node = {"VAR TYPE", 1, child_array, false, strdup("DOUBLE")};
					$$ = current_node; 
				}

FUN_PARAMS : FUN_PARAM {
				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
				child_array[0] = $1;
				struct  node current_node = {"FUN PARAMS", 1, child_array, false, $1.returnValue};
				$$ = current_node;
			}
			| FUN_PARAMS COMMA FUN_PARAM {
				char* x = strcat($1.returnValue, " "); 

				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 3);
				struct node comma = {"COMMA", 0, NULL, true, ","};
				child_array[0] = $1; child_array[1] = comma; child_array[2] = $3;
				struct  node current_node = {"FUN PARAMS", 3, child_array, false, strcat(x, $3.returnValue)};
				$$ = current_node;} 
			| { 
				struct  node current_node = {"FUN PARAMS", 0, NULL, false, ""};
				$$ = current_node; 
			} // get function parameters infos
FUN_PARAM : VAR_TYPE IDENTIFIER {
				char* x = strcat($1.returnValue, " "); 

				struct node *child_array = (struct node *) malloc(sizeof(struct node) * 2);
				struct node id = {"IDENTIFIER", 0, NULL, true, strdup($2)};
				child_array[0] = $1; child_array[1] = id; 
				struct  node current_node = {"FUN PARAM", 2, child_array, false, strcat(x, $2)};
				$$ = current_node;
				
			} // return function parameter info

// new
FUN_CALL_PARAMS : FUN_CALL_PARAM {
						struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1); 
						child_array[0] = $1; 
						struct node current_node = {"FUN_CALL_PARAMS", 1, child_array, false, $1.returnValue}; 
						$$=current_node;
					} 
				| FUN_CALL_PARAMS COMMA FUN_CALL_PARAM {
						char* x = strcat($1.returnValue, " "); 

						struct node *child_array = (struct node *) malloc(sizeof(struct node) * 3); 
						struct node comma = {"COMMA", 0, NULL, true, ","};
						child_array[0] = $1; child_array[1] = comma; child_array[2] = $3; 
						struct node current_node = {"FUN_CALL_PARAMS", 3, child_array, false, strcat(x, $3.returnValue)}; 
						$$=current_node;
				  } 
				| {
					struct  node current_node = {"FUN CALL PARAMS", 0, NULL, false, ""};
					$$ = current_node; 
				  }
FUN_CALL_PARAM : VALUE {
	struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1); 
	child_array[0] = $1;
	struct node current_node = {"FUN_CALL_PARAM", 1, child_array, false, $1.returnValue}; 
	$$=current_node;
}

ARRAY_DEFINITION : IDENTIFIER ARROW_SYMBOL VAR_TYPE OP_SQ_BR INT_VALUE CL_SQ_BR END_OF_LINE {  
	struct node eof = {"END OF LINE", 0, NULL, true, ":)"};
	struct node assign = {"ARROW", 0, NULL, true, "=>"};
	struct node op_b = {"OP SQ BR", 0, NULL, true, "["};
	struct node cl_b = {"CL SQ BR", 0, NULL, true, "]"};
	char result[50]; sprintf(result, "%d", yylval.intVal); 
	struct node int_val = {"INT VAL", 0, NULL, true, strdup(result)};
	struct node id = {"IDENTIFIER", 0, NULL, true, strdup($1)};

	struct node *child_array = (struct node *) malloc(sizeof(struct node) * 7);
	child_array[0] = id; child_array[3] = op_b; child_array[4] = int_val; child_array[5] = cl_b; 
	child_array[1] = assign; child_array[6] = eof; child_array[2] = $3; // new

	struct  node current_node = {"ARRAY DEFINITION", 7, child_array, false, NULL};
	$$ = current_node;

	if (!skip()){
		struct var variable;
		variable.name = strdup($1);
		variable.dataType = strdup($3.returnValue);
		variable.arraySize = yylval.intVal;
		variable.isArray = true;

		printf("\tvar_name: %s, var_type: %s\n", variable.name, variable.dataType);
		if(check_identifier(variable.name, stack[stack_top]))
			add_variable(variable);
	}
}

ARRAY_EL_DEFINITION : IDENTIFIER OP_SQ_BR INT_VALUE CL_SQ_BR ASSIGN VALUE END_OF_LINE {  
	struct node eof = {"END OF LINE", 0, NULL, true, ":)"};
	struct node assign = {"ASSIGN", 0, NULL, true, "="};
	struct node op_b = {"OP SQ BR", 0, NULL, true, "["};
	struct node cl_b = {"CL SQ BR", 0, NULL, true, "]"};
	char result[50]; sprintf(result, "%d", $3); 
	struct node int_val = {"INT VAL", 0, NULL, true, strdup(result)};
	struct node id = {"IDENTIFIER", 0, NULL, true, strdup($1)};

	struct node *child_array = (struct node *) malloc(sizeof(struct node) * 7);
	child_array[0] = id; child_array[1] = op_b; child_array[2] = int_val; child_array[3] = cl_b; 
	child_array[4] = assign; child_array[6] = eof; child_array[5] = $6; // new

	struct  node current_node = {"ARRAY EL DEFINITION", 7, child_array, false, NULL};
	$$ = current_node;
	if (!skip()){
		var* array = get_variable($1, true);
		char* value_dt = split_var_encoding(&($6.returnValue));
		int index = $3;

		if (strcmp(value_dt, array->dataType)) yyerror("Wrong data type! \n");

		if (index >= array->arraySize || index < 0) yyerror("Wrong index! \n");

		if (!strcmp( array->dataType, "INT")){
			array->intArr[index] = atoi($6.returnValue);
			printf("\tArray element value update: %s[%d] => %d \n", array->name, index, array->intArr[index]);
		} else if (!strcmp( array->dataType, "DOUBLE")){
			array->doubleArr[index] = atof($6.returnValue);
			printf("\tArray element value update: %s[%d] => %f \n", array->name, index, array->doubleArr[index]);
		} else if (!strcmp( array->dataType, "CHAR")){
			array->charArr[index] = $6.returnValue[0];
			printf("\tArray element value update: %s[%d] => %c \n", array->name, index, array->charArr[index]);
		} else if (!strcmp( array->dataType, "BOOL")){
			if($6.returnValue[0] == 'T') {array->boolArr[index] = true;}
			else if($6.returnValue[0] == 'F'){array->boolArr[index] = false;} 	
			printf("\tArray element value update: %s[%d] => %d", array->name, index, array->boolArr[index]);
		} else if (!strcmp( array->dataType, "STR")){
			array->strArr[index] = strdup($6.returnValue);
			printf("\tArray element value update: %s[%d] => %s \n", array->name, index, array->strArr[index]);
		}
	}
}

ARITHMETIC_OPERATION : VALUE ARITHMETIC_OPERATOR VALUE {  
	struct node current_node ;
	current_node.treeValue = "ARITHMETIC_OPERATION";
	current_node.childCount = 3;
	current_node.is_terminal = false;
	current_node.returnValue = NULL;
	current_node.childs = (struct node *) malloc(sizeof(struct node) * current_node.childCount);
	current_node.childs[0] = $1; current_node.childs[1] = $2; current_node.childs[2] = $3;
	$$ = current_node;

	if (!skip()){		
		char* firstValueDataType = split_var_encoding(&($1.returnValue));
		char* secondValueDataType = split_var_encoding(&($3.returnValue));

		if (strcmp(firstValueDataType, "DOUBLE") && strcmp(secondValueDataType, "INT"))
			yyerror("Unsupported data type! ");
		char str[50];
		double result;

		if (!strcmp($2.returnValue, "ADD")){
			if (!strcmp(firstValueDataType, "DOUBLE") || !strcmp(secondValueDataType, "DOUBLE")){
				result = atof($1.returnValue) + atof($3.returnValue);
				sprintf(str, "%f", result);
			} else if (!strcmp(firstValueDataType, "INT") || !strcmp(secondValueDataType, "INT")) {
				result = atoi($1.returnValue) + atoi($3.returnValue);
				sprintf(str, "%f", result);
			}
		}
		else if (!strcmp($2.returnValue, "SUBTRACT")){		 	
			if (!strcmp(firstValueDataType, "DOUBLE") || !strcmp(secondValueDataType, "DOUBLE")){
				result = atof($1.returnValue) - atof($3.returnValue);
				sprintf(str, "%f", result);
			} else if (!strcmp(firstValueDataType, "INT") || !strcmp(secondValueDataType, "INT")) {
				result = atoi($1.returnValue) - atoi($3.returnValue);
				sprintf(str, "%f", result);
			}
		}
		else if (!strcmp($2.returnValue, "MULTIPLY")){		 	
			if (!strcmp(firstValueDataType, "DOUBLE") || !strcmp(secondValueDataType, "DOUBLE")){
				result = atof($1.returnValue) * atof($3.returnValue);
				sprintf(str, "%f", result);
			} else if (!strcmp(firstValueDataType, "INT") || !strcmp(secondValueDataType, "INT")) {
				result = atoi($1.returnValue) * atoi($3.returnValue);
				sprintf(str, "%f", result);
			}
		}
		else if (!strcmp($2.returnValue, "DIVIDE")){	
			if (atoi($3.returnValue) == 0) { yyerror("No division by zero!\n");}
			if (!strcmp(firstValueDataType, "DOUBLE") || !strcmp(secondValueDataType, "DOUBLE")){
				result = atof($1.returnValue) / atof($3.returnValue);
				sprintf(str, "%f", result);
			} else if (!strcmp(firstValueDataType, "INT") || !strcmp(secondValueDataType, "INT")) {
				result = atoi($1.returnValue) / atoi($3.returnValue);
				sprintf(str, "%f", result);
			};
		}
		printf("\tResult of %s %s %s = %s\n", $1.returnValue, $2.returnValue, $3.returnValue, str);
		$$.returnValue = strdup(str);
	}
}
ARITHMETIC_OPERATOR :  
	ADD { 
		struct node operator = {"ADD", 0, NULL, true, "+"};
		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
		child_array[0] = operator;
		struct  node current_node = {"ARITHMETIC OPERATOR", 1, child_array, false, "ADD"};
		$$ = current_node;
	} 
	| SUBTRACT  {
		struct node operator = {"SUBTRACT", 0, NULL, true, "-"};
		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
		child_array[0] = operator;
		struct  node current_node = {"ARITHMETIC OPERATOR", 1, child_array, false, "SUBTRACT"};
		$$ = current_node;
	}
	| MULTIPLY  {
		struct node operator = {"MULTIPLY", 0, NULL, true, "*"};
		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
		child_array[0] = operator;
		struct  node current_node = {"ARITHMETIC OPERATOR", 1, child_array, false, "MULTIPLY"};
		$$ = current_node;
	} 
	| DIVIDE  {
		struct node operator = {"DIVIDE", 0, NULL, true, "/"};
		struct node *child_array = (struct node *) malloc(sizeof(struct node) * 1);
		child_array[0] = operator;
		struct  node current_node = {"ARITHMETIC OPERATOR", 1, child_array, false, "DIVIDE"};
		$$ = current_node;
	}
%%

#include"lex.yy.c"  

int main() {   
	
	yylineno += 1;
	x.name = NULL;
	// add main function to the stack first
	struct var vars[20];
	struct stack_item main_function = {0, "main", "INT", vars};
	add_function_to_fun_array(main_function);
	add_function_to_stack(main_function);
	printf("\n>>> ");
	yyparse();  
	printf("\nCompiled successfully !\n");
	print_tree(&root_node, 0);

  	return 0;
}

void yyerror(const char *s){ fprintf(stderr, "\nERROR ON LINE %d : \n %s\n", yylineno, s); exit(0); }
int yywrap(){ return 1; }
