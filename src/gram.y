%{

/* gram.y - Grammar analyzer
 *
 * Copyright (c) 2019 Eric Wan <aloha_cn@hotmail.com>
 *
 * This file is part of MYL.
 *
 * MYL is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <ctype.h>

#include "myl.h"
#include "myl_internal.h"
#include "element.h"
#include "stackitem.h"
#include "vmachine.h"
#include "funcdefs.h"

typedef struct Varlistitem {
	int name;				/* variable name */
	int addr;				/* address */
	struct Varlistitem*next;
	char flag;
	char type;				/* T_FLOAT or T_INTEGER...etc. */
} Varlistitem;

typedef struct Caselistitem {
	int name;
	int addr;
	int type;
	struct Caselistitem*next;
} Caselistitem;

typedef struct Labellistitem {
	int name;
	int addr;
	int list;
	struct Labellistitem*next;
} Labellistitem;

typedef struct CaseStack {
	Caselistitem list;
	struct CaseStack *next,*prev;
} CaseStack;

typedef struct Expval {
	int codebegin;
	int place;
	int truelist, falselist;
	int nolist;
	int type;				/* Type of the expression */
} Expval;

typedef struct Intval {
	int codebegin;
	int chain;
	int breakchain;
	int paracnt;
} Intval;

typedef struct Paraval {
	int codebegin;
	int paracnt;
} Paraval;

typedef struct Varval {
	int var;
	int type;
} Varval;

typedef struct Caseval {
	int addr;
	int type;
} Caseval;

static StackItem LoopTable;
static StackItem *LoopTop;
static Varlistitem Varlist={-1,CODESIZE,0,0};
static CaseStack *CaseTop;
static Labellistitem *LabelList;

static Labellistitem *SearchLabel(int);
static Labellistitem *NewLabel(int);

static Instruction Code;

static void PushCase(int type);
static void PopCase();
static int CurrentCase();
static int SearchCase(int type, int cnt_id);
static int RegCase(int type, int cnt_id, int addr);
static void FreeCaseList(Caselistitem*);

static int SearchVar(int name);
static int GetVarType(int name);
static int NewVar(int name, int type);
//static void SetVarType(int varid, int type);
static void SetVarFlag(int varid, int flag);
//static int GetVarFlag(int varid);
static int GetVar(int varid);

static void makevalue(Expval *pval);
static void makelist(MYLParser *parser, Expval *pval);
static int FuncMap(const char *name);
static char memmap[STACKSIZE];
static int CurrentIP;
static int OprCode(int);
static void backpatch(int,int);
static int merge(int, int);
static int newmem();
static int newtemp();
static void freetemp(int);
static void GenCode(const Instruction *inst);
static void fGenCode(int op, float src1, float src2, int dest);
static void iGenCode(int op, int src1, int src2, int dest);

static int yyparse(MYLParser *parser);
static int yylex(MYLParser *parser);
static void yyerror(MYLParser *parser, const char *s);

#ifdef _DEBUG
#define ANALYZE(i) Analyze(i)
#else
#define ANALYZE(i)
#endif

#ifdef _DEBUG
void Analyze(const char *rule)
{
	printf ("%s\n",rule);
}
#endif

%}
%require "3.0"
%lex-param   {MYLParser *parser}
%parse-param {MYLParser *parser}
%union {
	int nval;
	Varval vval;
	Paraval pval;
	Expval eval;
	Intval ival;
	Element lexval;
	}
%token <lexval> CNTINT
%token <lexval> FLT
%token <lexval> STR
%token <lexval> IDENT
%token <lexval> KEYIF
%token <lexval> KEYELSE
%token <lexval> KEYFOR
%token <lexval> KEYWHILE
%token <lexval> KEYDO
%token <lexval> KEYCONT
%token <lexval> KEYBREAK
%token <lexval> KEYSWITCH
%token <lexval> KEYCASE
%token <lexval> KEYDEFAULT
%token <lexval> KEYGOTO
%token <lexval> KEYTYPE
%token <lexval> SEMICOLON
%token <lexval> LBRACKET
%token <lexval> RBRACKET
%token <lexval> LPARA
%token <lexval> RPARA
%token <lexval> SELECT
%token <lexval> COLON
%token <lexval> BOOLOR
%token <lexval> BOOLAND
%token <lexval> INCOPS
%token <lexval> DECOPS
%token <lexval> SETOPS
%token <lexval> COMMA
%token <lexval> BOOLOPS
%token <lexval> BITOPS
%token <lexval> SHIFTOPS
%token <lexval> ADDOPS
%token <lexval> MULOPS
%token <lexval> BOOLNOT
%token <lexval> BITNOT
%type <ival> MYL statement ifpre elsepre whilepre foractpre forinitpre
%type <eval> expression compexp boolandpre boolorpre forconpre 
%type <eval> boolexp bitexp shiftexp addexp mulexp factor function
%type <eval> boolpre bitpre shiftpre addpre mulpre selectpre colonpre switchpre
%type <eval> typepre
%type <pval> parameter paralist
%type <nval> langstart dopre label
%type <vval> lresult
%%

langstart	:	MYL
				{backpatch($1.chain, CurrentIP);
				backpatch($1.breakchain, CurrentIP);
				iGenCode(RET|FLAG1|FLAG2|FLAG3,0,0,0);}
			;
MYL			:	MYL statement
				{$$.codebegin=$1.codebegin;
				backpatch($1.chain, $2.codebegin);
				$$.chain=$2.chain;
				$$.breakchain=merge($1.breakchain, $2.breakchain);}
			|	statement
				{$$.codebegin=$1.codebegin;
				$$.chain=$1.chain;
				$$.breakchain=$1.breakchain;}
			;
statement	:	ifpre statement
				{$$.codebegin=$1.codebegin;
				$$.chain=merge($1.chain, $2.chain);
				$$.breakchain=$2.breakchain;}
			|	elsepre statement
				{$$.codebegin=$1.codebegin;
				$$.chain=merge($1.chain, $2.chain);
				$$.breakchain=$2.breakchain;}
			|	whilepre statement
				{$$.codebegin=$1.codebegin;
				backpatch($2.chain, $1.codebegin);
				iGenCode(JMP|FLAG3,0,0,$1.codebegin);
				$$.chain=merge($1.chain, $2.breakchain);
				$$.breakchain=CODESIZE;
				Pop(&LoopTop);}
			|	forinitpre forconpre foractpre statement
				{$$.codebegin=$1.codebegin;
				backpatch($1.chain, $2.codebegin);
				backpatch($2.truelist, $4.codebegin);
				backpatch($3.chain, $2.codebegin);
				backpatch($4.chain, $3.codebegin);
				iGenCode(JMP|FLAG3,0,0,$3.codebegin);
				$$.chain=merge($4.breakchain,$2.falselist);
				$$.breakchain=CODESIZE;
				Pop(&LoopTop);}
			|	dopre statement KEYWHILE LPARA expression RPARA SEMICOLON
				{$$.codebegin=$2.codebegin;
				makelist(parser, &$5);
				backpatch($5.truelist, $2.codebegin);
				backpatch($2.chain, $5.codebegin);
				$$.chain=merge($2.breakchain, $5.falselist);
				$$.breakchain=CODESIZE;
				Pop(&LoopTop);}
			|	expression SEMICOLON
				{$$.codebegin=$1.codebegin;
				if ($1.nolist) freetemp($1.place);
				else {
					backpatch ($1.truelist, CurrentIP);
					backpatch ($1.falselist, CurrentIP);
				}
				$$.chain=CODESIZE;
				$$.breakchain=CODESIZE;}
			|	KEYCONT SEMICOLON
				{if (!IsStackEmpty(LoopTop)) {
					$$.codebegin=CurrentIP;
					$$.chain=CODESIZE;
					$$.breakchain=CODESIZE;
					iGenCode(JMP|FLAG3,0,0,LoopTop->data);
				}
				else yyerror(parser, "Invalid continue statement.");}
			|	KEYBREAK SEMICOLON
				{if (!IsStackEmpty(LoopTop) || CaseTop->prev) {
					$$.codebegin=CurrentIP;
					$$.chain=CODESIZE;
					$$.breakchain=CurrentIP;
					iGenCode(JMP|FLAG3,0,0,CODESIZE);
				}
				else yyerror(parser, "Invalid break statement");}
			|	LBRACKET MYL RBRACKET
				{$$.codebegin=$2.codebegin;
				$$.chain=$2.chain;
				$$.breakchain=$2.breakchain;}
			|	LBRACKET RBRACKET
				{$$.codebegin=CurrentIP;
				$$.chain=CODESIZE;
				$$.breakchain=CODESIZE;}
			|	SEMICOLON
				{$$.codebegin=CurrentIP;
				$$.chain=CODESIZE;
				$$.breakchain=CODESIZE;}
			|	typepre IDENT SEMICOLON
				{int var;
				$$.codebegin=CurrentIP;
				$$.chain=CODESIZE;
				$$.breakchain=CODESIZE;
				var=SearchVar($2.id);
				if (!var) {
					NewVar($2.id,$1.type);
				}
				else yyerror(parser, "Variable redefined");}
			|	switchpre statement
				{Caselistitem *plist,*defnode;
				$$.codebegin=$1.codebegin;
				$$.breakchain=CODESIZE;
				$$.chain=CurrentIP;
				iGenCode(JMP|FLAG3,0,0,CODESIZE);
				backpatch($1.truelist, CurrentIP);
				plist=&(CaseTop->list);
				defnode=0;
				while (plist->next) {
					plist=plist->next;
					if (plist->type!=-1&&plist->name!=0) {
						if (plist->type!=$1.type)
							yyerror(parser, "Case type mismatch");
						switch ($1.type) {
						case T_INTEGER:
							iGenCode(JE|FLAG2|FLAG3,$1.place,
								GetInteger(parser->elemParser, plist->name),plist->addr);
							break;
						case T_FLOAT:
							Code.op=JE|FLAG2|FLAG3|FLFLAG;
							Code.src1.i=$1.place;
							Code.src2.f=GetFloat(parser->elemParser, plist->name);
							Code.dest=plist->addr;
							GenCode(&Code);
							break;
						case T_STRING:
							{int temp;
							temp=newmem();
							PrepareMem(temp);
							SetMemStr(temp, GetString(parser->elemParser, plist->name));
							iGenCode(JE|FLAG3|STRFLAG,$1.place,temp,
								plist->addr);}
						}
					}
					else defnode=plist;
				}
				if (defnode) {
					iGenCode(JMP|FLAG3,0,0,defnode->addr);
				}
				backpatch($2.breakchain, CurrentIP);
				PopCase();
				freetemp($1.place);}
			|	label statement
				{$$.codebegin=$2.codebegin;
				$$.chain=$2.chain;
				$$.breakchain=$2.breakchain;}
			|	KEYGOTO IDENT SEMICOLON
				{Labellistitem *label;
				$$.codebegin=CurrentIP;
				$$.chain=CODESIZE;
				$$.breakchain=CODESIZE;
				if ((label=SearchLabel($2.id))) {
					if (label->addr!=CODESIZE) {
						iGenCode(JMP|FLAG3,0,0,label->addr);
					}
					else {
						iGenCode(JMP|FLAG3,0,0,CODESIZE);
						label->list=merge(CurrentIP-1,label->list);
					}
				}
				else {
					label=NewLabel($2.id);
					label->addr=CODESIZE;
					label->list=CurrentIP;
					iGenCode(JMP|FLAG3,0,0,CODESIZE);
				}}
			;
typepre		:	typepre IDENT COMMA
				{int var;
				$$.type=$1.type;
				var=SearchVar($2.id);
				if (!var) {
					NewVar($2.id,$$.type);
				}
				else yyerror(parser, "Variable redefined");}
			|	KEYTYPE
				{$$.type=$1.id-FIRSTTYPE+1;}
			;
label		:	IDENT COLON
				{Labellistitem *label;
				if ((label=SearchLabel($1.id))) {
					if (label->addr!=CODESIZE)
						yyerror(parser, "Label redefined");
					else {
						label->addr=CurrentIP;
						backpatch(label->list, CurrentIP);
					}
				}
				else {
					label=NewLabel($1.id);
					label->addr=CurrentIP;
					label->list=CODESIZE;
				}}
			|	KEYCASE CNTINT COLON
				{if (CurrentCase()!=T_INTEGER || SearchCase(T_INTEGER, $2.id))
					yyerror(parser, "Illegel case");
				else $$=RegCase(T_INTEGER, $2.id, CurrentIP);}
			|	KEYCASE FLT COLON
				{if (CurrentCase()!=T_FLOAT || SearchCase(T_FLOAT, $2.id))
					yyerror(parser, "Illegel case");
				else $$=RegCase(T_FLOAT, $2.id, CurrentIP);}
			|	KEYCASE STR COLON
				{if (CurrentCase()!=T_STRING || SearchCase(T_STRING,$2.id))
					yyerror(parser, "Illegel case");
				else $$=RegCase(T_STRING,$2.id, CurrentIP);}
			|	KEYDEFAULT COLON
				{if (CurrentCase()==T_NULL || SearchCase(-1,0))
					yyerror(parser, "Illegel default");
				else $$=RegCase(-1,0, CurrentIP);}
			;
switchpre	:	KEYSWITCH LPARA expression RPARA
				{$$.codebegin=$3.codebegin;
				$$.type=$3.type;
				makevalue(&$3);
				$$.place=$3.place;
				$$.truelist=CurrentIP;
				iGenCode(JMP|FLAG3,0,0,CODESIZE);
				PushCase($3.type);}
			;
dopre		:	KEYDO
				{Push(&LoopTop, CurrentIP);}
			;
forinitpre	:	KEYFOR LPARA expression SEMICOLON
				{$$.codebegin=$3.codebegin;
				if ($3.nolist) {
					freetemp($3.place);
					$$.chain=CODESIZE;
				}
				else {
					$$.chain=merge($3.truelist,$3.falselist);
				}}
			;
forconpre	:	expression SEMICOLON
				{$$.codebegin=$1.codebegin;
				makelist(parser, &$1);
				$$.truelist=$1.truelist;
				$$.falselist=$1.falselist;}
			;
foractpre	:	expression RPARA
				{$$.codebegin=$1.codebegin;
				$$.chain=CurrentIP;
				Push(&LoopTop, $1.codebegin);
				iGenCode(JMP|FLAG3,0,0,CODESIZE);
				if ($1.nolist) freetemp($1.place);}
			;
whilepre	:	KEYWHILE LPARA expression RPARA
				{$$.codebegin=$3.codebegin;
				Push(&LoopTop, $3.codebegin);
				makelist(parser, &$3);
				backpatch($3.truelist, CurrentIP);
				$$.chain=$3.falselist;}
			;
ifpre		:	KEYIF LPARA expression RPARA
				{$$.codebegin=$3.codebegin;
				makelist(parser, &$3);
				backpatch($3.truelist, CurrentIP);
				$$.chain=$3.falselist;}
			;
elsepre		:	ifpre statement KEYELSE
				{$$.codebegin=$1.codebegin;
				iGenCode(JMP|FLAG3,0,0,CODESIZE);
				backpatch($1.chain, CurrentIP);
				$$.chain=merge($2.chain, CurrentIP-1);}
			;
expression	:	lresult SETOPS expression
				{$$.codebegin=$3.codebegin;
				$$.nolist=1;
				$$.place=newtemp();
				SetVarFlag($1.var,1);
				if ($2.id!=S_SET) {
				$$.type=$1.type;
					switch ($1.type) {
					case T_NULL:
						yyerror(parser, "Unknown variable.");
						break;
					case T_STRING:
						yyerror(parser, "Can't compute a string variable.");
						break;
					case T_INTEGER:
						if ($3.type==T_INTEGER||$3.type==T_FLOAT)
							iGenCode(OprCode($2.id),
								GetVar($1.var),$3.place,GetVar($1.var));
						else yyerror(parser, "Wrong expression.");
						break;
					case T_FLOAT:
						if ($3.type==T_INTEGER||$3.type==T_FLOAT)
							iGenCode(OprCode($2.id)|FLFLAG,
								GetVar($1.var),$3.place,GetVar($1.var));
						else yyerror(parser, "Wrong expression.");
						break;
					case T_LIST:
						yyerror(parser, "The type 'List' can't be supported by now");
						break;
					}
				}
				else {
					switch ($1.type) {
					case T_NULL:
						yyerror(parser, "Internal error");
						break;
					case T_INTEGER:
						if ($3.type==T_FLOAT)
							iGenCode(CNV|FLFLAG,$3.place,0,GetVar($1.var));
						else if ($3.type==T_INTEGER)
							iGenCode(MOV,$3.place,0,GetVar($1.var));
						else
							yyerror(parser, "Incompatible data type");
						break;
					case T_FLOAT:
						if ($3.type==T_INTEGER)
							iGenCode(CNV,$3.place,0,GetVar($1.var));
						else if ($3.type==T_FLOAT)
							iGenCode(MOV,$3.place,0,GetVar($1.var));
						else
							yyerror(parser, "Incompatible data type");
						break;
					case T_STRING:
						if ($3.type==T_STRING)
							iGenCode(MOV,$3.place,0,GetVar($1.var));
						else
							yyerror(parser, "Incompatible data type");
						break;
					case T_LIST:
						yyerror(parser, "The type 'List' can't be supported by now");
						break;
				}
				}
				/*iGenCode(MOV,GetVar($1.var),0,$$.place);*/
				freetemp($3.place);}
			|	selectpre colonpre expression
				{$$.codebegin=$1.codebegin;
				$$.place=$2.place;
				makevalue(&$3);
				backpatch($1.truelist, $2.codebegin);
				backpatch($1.falselist, $3.codebegin);
				iGenCode(MOV,$3.place,0,$2.place);
				backpatch($2.truelist, CurrentIP);
				freetemp($3.place);}
			|	boolexp
				{$$.codebegin=$1.codebegin;
				$$.nolist=$1.nolist;
				$$.type=$1.type;
				if (!$1.nolist) {
					$$.truelist=$1.truelist;
					$$.falselist=$1.falselist;
				}
				else $$.place=$1.place;}
			;
selectpre	:	expression SELECT
				{$$.codebegin=$1.codebegin;
				makelist(parser, &$1);
				$$.truelist=$1.truelist;
				$$.falselist=$1.falselist;}
			;
colonpre	:	expression COLON
				{$$.codebegin=$1.codebegin;
				makevalue(&$1);
				$$.type=$1.type;
				$$.truelist=CurrentIP;
				iGenCode(JMP|FLAG3,0,0,CODESIZE);}
			;
lresult		:	IDENT
				{$$.var=SearchVar($1.id);
				if (!$$.var) {
					yyerror(parser, "Undefined variable.");
				}
				else $$.type=GetVarType($$.var);}
			;
boolexp		:	boolorpre compexp
				{$$.codebegin=$1.codebegin;
				$$.nolist=0;
				$$.type=T_INTEGER;
				makelist(parser, &$2);
				backpatch($1.falselist,$2.codebegin);
				$$.truelist=merge($1.truelist, $2.truelist);
				$$.falselist=$2.falselist;}
			|	boolandpre compexp
				{$$.codebegin=$1.codebegin;
				$$.nolist=0;
				$$.type=T_INTEGER;
				makelist(parser, &$2);
				backpatch($1.truelist,$2.codebegin);
				$$.falselist=merge($1.falselist, $2.falselist);
				$$.truelist=$2.truelist;}
			|	compexp
				{$$.codebegin=$1.codebegin;
				$$.nolist=$1.nolist;
				$$.type=$1.type;
				if (!$1.nolist) {
					$$.truelist=$1.truelist;
					$$.falselist=$1.falselist;
				}
				else $$.place=$1.place;}
			;
boolorpre	:	boolexp BOOLOR
				{$$.codebegin=$1.codebegin;
				makelist(parser, &$1);
				$$.truelist=$1.truelist;
				$$.falselist=$1.falselist;}
			;
boolandpre	:	boolexp BOOLAND
				{$$.codebegin=$1.codebegin;
				makelist(parser, &$1);
				$$.truelist=$1.truelist;
				$$.falselist=$1.falselist;}
			;
compexp		:	boolpre bitexp
				{int addr=-1;
				$$.codebegin=$1.codebegin;
				$$.nolist=1;
				makevalue(&$2);
				$$.place=newtemp();
				$$.type=T_INTEGER;
				if ($1.type!=$2.type) {							
					if ($1.type==T_STRING || $2.type==T_STRING
					|| $1.type==T_LIST || $2.type==T_LIST)
						yyerror(parser, "Type error.");
					addr=newtemp();								
					if ($1.type==T_INTEGER) {
						iGenCode(CNV,$1.place,0,addr);			
						iGenCode(OprCode($1.nolist)|FLFLAG,		
							addr,$2.place,$$.place);			
					}											
					else {
						iGenCode(CNV,$2.place,0,addr);			
						iGenCode(OprCode($1.nolist)|FLFLAG,
							$1.place,addr,$$.place);			
					}
				}												
				else {											
					if ($1.type==T_INTEGER) {					
						iGenCode(OprCode($1.nolist)				
							,$1.place,$2.place,$$.place);		
					}											
					else if ($1.type==T_FLOAT) {										
						iGenCode(OprCode($1.nolist)|FLFLAG		
							,$1.place,$2.place,$$.place);		
					}
					else if ($1.type==T_STRING) {
						iGenCode(OprCode($1.nolist)|STRFLAG
							,$1.place,$2.place,$$.place);		
					}
					else yyerror(parser, "Unhandled branch");
				}												
				freetemp(addr);									
				freetemp($1.place);
				freetemp($2.place);}
			|	bitexp
				{$$.codebegin=$1.codebegin;
				$$.nolist=$1.nolist;
				$$.type=$1.type;
				if (!$1.nolist) {
					$$.truelist=$1.truelist;
					$$.falselist=$1.falselist;
				}
				else $$.place=$1.place;}
			;
bitexp		:	bitpre shiftexp
				{$$.codebegin=$1.codebegin;
				$$.nolist=1;
				makevalue(&$2);
				$$.place=newtemp();
				$$.type=T_INTEGER;
				if ($2.type!=T_INTEGER)
					yyerror(parser, "Op error.");
				iGenCode(OprCode($1.nolist),
						$1.place,$2.place,$$.place);
				freetemp($1.place);
				freetemp($2.place);}
			|	shiftexp
				{$$.codebegin=$1.codebegin;
				$$.nolist=$1.nolist;
				$$.type=$1.type;
				if (!$1.nolist) {
					$$.truelist=$1.truelist;
					$$.falselist=$1.falselist;
				}
				else $$.place=$1.place;}
			;
shiftexp	:	shiftpre addexp
				{$$.codebegin=$1.codebegin;
				$$.nolist=1;
				makevalue(&$2);
				$$.place=newtemp();
				$$.type=T_INTEGER;
				if ($2.type!=T_INTEGER)
					yyerror(parser, "Op error.");
				iGenCode(OprCode($1.nolist),
						$1.place,$2.place,$$.place);
				freetemp($1.place);
				freetemp($2.place);}
			|	addexp
				{$$.codebegin=$1.codebegin;
				$$.nolist=$1.nolist;
				$$.type=$1.type;
				if (!$1.nolist) {
					$$.truelist=$1.truelist;
					$$.falselist=$1.falselist;
				}
				else $$.place=$1.place;}
			;
addexp		:	addpre mulexp 
				{int addr=-1;
				$$.codebegin=$1.codebegin;
				$$.nolist=1;
				makevalue(&$2);
				$$.place=newtemp();

				if ($2.type==T_STRING)							
					yyerror(parser, "Op error.");						
				if ($1.type!=$2.type) {							
					$$.type=T_FLOAT;							
					addr=newtemp();								
					if ($1.type==T_INTEGER) {					
						iGenCode(CNV,$1.place,0,addr);			
						iGenCode(OprCode($1.nolist)|FLFLAG,		
							addr,$2.place,$$.place);			
					}											
					else if ($2.type==T_INTEGER) {				
						addr=newtemp();							
						iGenCode(CNV,$2.place,0,addr);			
						iGenCode(OprCode($1.nolist)|FLFLAG,		
							$1.place,addr,$$.place);			
					}											
				}												
				else {											
					$$.type=$1.type;							
					if ($1.type==T_INTEGER) {					
						iGenCode(OprCode($1.nolist)				
							,$1.place,$2.place,$$.place);		
					}											
					else {										
						iGenCode(OprCode($1.nolist)|FLFLAG		
							,$1.place,$2.place,$$.place);		
					}											
				}												
				freetemp(addr);									
				freetemp($1.place);
				freetemp($2.place);}
			|	mulexp
				{$$.codebegin=$1.codebegin;
				$$.nolist=$1.nolist;
				if (!$1.nolist) {
					$$.truelist=$1.truelist;
					$$.falselist=$1.falselist;
				}
				else $$.place=$1.place;}
			;
mulexp		:	mulpre factor
				{int addr=-1;
				$$.codebegin=$1.codebegin;
				$$.nolist=1;
				makevalue(&$2);
				$$.place=newtemp();

				if ($2.type==T_STRING)							
					yyerror(parser, "Op error.");						
				if ($1.type!=$2.type) {							
					$$.type=T_FLOAT;							
					addr=newtemp();								
					if ($1.type==T_INTEGER) {					
						iGenCode(CNV,$1.place,0,addr);			
						iGenCode(OprCode($1.nolist)|FLFLAG,		
							addr,$2.place,$$.place);			
					}											
					else if ($2.type==T_INTEGER) {				
						addr=newtemp();							
						iGenCode(CNV,$2.place,0,addr);			
						iGenCode(OprCode($1.nolist)|FLFLAG,		
							$1.place,addr,$$.place);			
					}											
				}												
				else {											
					$$.type=$1.type;							
					if ($1.type==T_INTEGER) {					
						iGenCode(OprCode($1.nolist)				
							,$1.place,$2.place,$$.place);		
					}											
					else {										
						iGenCode(OprCode($1.nolist)|FLFLAG		
							,$1.place,$2.place,$$.place);		
					}											
				}												
				freetemp(addr);									
				freetemp($1.place);
				freetemp($2.place);}
			|	factor
				{$$.codebegin=$1.codebegin;
				$$.nolist=$1.nolist;
				$$.type=$1.type;
				if (!$1.nolist) {
					$$.truelist=$1.truelist;
					$$.falselist=$1.falselist;
				}
				else $$.place=$1.place;}
			|	ADDOPS factor
				{$$.codebegin=$2.codebegin;
				$$.nolist=1;
				$$.type=$2.type;
				if ($2.type==T_STRING)
					yyerror(parser, "+ op misused.");
				makevalue(&$2);
				$$.place=newtemp();
				if ($1.id==S_SUB) {
					if ($2.type==T_INTEGER)
						iGenCode(SUB|FLAG1,0,$2.place,$$.place);
					if ($2.type==T_FLOAT) {
						Code.op=SUB|FLAG1|FLFLAG;
						Code.src1.f=0.0;
						Code.src2.i=$2.place;
						Code.dest=$$.place;
						GenCode(&Code);
					}
					freetemp($2.place);
				}
				else $$.place=$2.place;}
			|	BOOLNOT factor
				{$$.codebegin=$2.codebegin;
				$$.nolist=0;
				makelist(parser, &$2);
				$$.truelist=$2.falselist;
				$$.falselist=$2.truelist;}
			|	BITNOT factor
				{$$.codebegin=$2.codebegin;
				$$.nolist=1;
				if ($2.type!=T_INTEGER) {
					yyerror(parser, "~ op misused.");
				}
				$$.type=T_INTEGER;
				makevalue(&$2);
				$$.place=newtemp();
				iGenCode(OprCode($1.id),$2.place,0,$$.place);
				freetemp($2.place);}
			;
boolpre		:	compexp BOOLOPS
				{$$.codebegin=$1.codebegin;
				$$.type=$1.type;
				makevalue(&$1);
				$$.nolist=$2.id;
				$$.place=$1.place;}
			;
bitpre		:	bitexp BITOPS
				{$$.codebegin=$1.codebegin;
				$$.type=T_INTEGER;
				if ($1.type!=T_INTEGER)
					yyerror(parser, "Wrong operation.");
				makevalue(&$1);
				$$.nolist=$2.id;
				$$.place=$1.place;}
			;
shiftpre	:	shiftexp SHIFTOPS
				{$$.codebegin=$1.codebegin;
				$$.type=T_INTEGER;
				if ($1.type!=T_INTEGER)
					yyerror(parser, "Wrong operation.");
				makevalue(&$1);
				$$.nolist=$2.id;
				$$.place=$1.place;}
			;
addpre		:	addexp ADDOPS
				{$$.codebegin=$1.codebegin;
				$$.type=$1.type;
				makevalue(&$1);
				$$.nolist=$2.id;
				$$.place=$1.place;}
			;
mulpre		:	mulexp MULOPS
				{$$.codebegin=$1.codebegin;
				$$.type=$1.type;
				makevalue(&$1);
				$$.nolist=$2.id;
				$$.place=$1.place;}
			;
factor		:	CNTINT
				{$$.codebegin=CurrentIP;
				$$.nolist=1;
				$$.place=newtemp();
				$$.type=T_INTEGER;
				iGenCode(MOV|FLAG1,GetInteger(parser->elemParser, $1.id),0,$$.place);}
			|	FLT
				{$$.codebegin=CurrentIP;
				$$.nolist=1;
				$$.place=newtemp();
				$$.type=T_FLOAT;
				fGenCode(MOV|FLAG1,GetFloat(parser->elemParser, $1.id),0.0,$$.place);}
			|	STR
				{int temp;
				$$.codebegin=CurrentIP;
				$$.nolist=1;
				temp=newmem();
				PrepareMem(temp);
				SetMemStr(temp, GetString(parser->elemParser, $1.id));
				$$.place=newtemp();
				$$.type=T_STRING;
				iGenCode(MOV,temp,0,$$.place);}
			|	INCOPS lresult
				{$$.codebegin=CurrentIP;
				$$.type=$2.type;
				$$.nolist=1;
				$$.place=newtemp();
				if ($2.type==T_INTEGER)
					iGenCode(INC,0,0,GetVar($2.var));
				else if ($2.type==T_FLOAT)
					fGenCode(INC,0.0,0.0,GetVar($2.var));
				else {
					yyerror(parser, "Data mismatch.");
				}
				iGenCode(MOV,GetVar($2.var),0,$$.place);
				}
			|	DECOPS lresult
				{$$.codebegin=CurrentIP;
				$$.type=$2.type;
				$$.nolist=1;
				$$.place=newtemp();
				if ($2.type==T_INTEGER)
					iGenCode(DEC,0,0,GetVar($2.var));
				else if ($2.type==T_FLOAT)
					fGenCode(DEC,0.0,0.0,GetVar($2.var));
				else {
					yyerror(parser, "Data mismatch.");
				}
				iGenCode(MOV,GetVar($2.var),0,$$.place);
				}
			|	lresult INCOPS
				{$$.codebegin=CurrentIP;
				$$.type=$1.type;
				$$.nolist=1;
				$$.place=newtemp();
				if ($1.type==T_INTEGER) {
					iGenCode(MOV,GetVar($1.var),0,$$.place);
					iGenCode(INC,0,0,GetVar($1.var));
				}
				else if ($1.type==T_FLOAT) {
					iGenCode(MOV,GetVar($1.var),0,$$.place);
					fGenCode(INC,0.0,0.0,GetVar($1.var));
				}
				else {
					yyerror(parser, "Data mismatch.");
				}
				}
			|	lresult DECOPS
				{$$.codebegin=CurrentIP;
				$$.type=$1.type;
				$$.nolist=1;
				$$.place=newtemp();
				iGenCode(MOV,GetVar($1.var),0,$$.place);
				if ($1.type==T_INTEGER) {
					iGenCode(DEC,0,0,GetVar($1.var));
				}
				else if ($1.type==T_FLOAT) {
					fGenCode(DEC,0.0,0.0,GetVar($1.var));
				}
				else {
					yyerror(parser, "Data mismatch.");
				}
				}
			|	IDENT {int var_index;
				$$.codebegin=CurrentIP;
				$$.nolist=1;
				$$.place=newtemp();
				var_index=SearchVar($1.id);
				if (!var_index) {
					yyerror(parser, "Unknown variable.");
				}
				$$.type=GetVarType(var_index);
				iGenCode(MOV,GetVar(var_index),0,$$.place);}
			|	function {$$.codebegin=$1.codebegin;
				$$.type=$1.type;
				$$.nolist=1;
				$$.place=$1.place;}
			|	LPARA expression RPARA
				{$$.codebegin=$2.codebegin;
				$$.type=$2.type;
				$$.nolist=$2.nolist;
				if (!$2.nolist) {
					$$.truelist=$2.truelist;
					$$.falselist=$2.falselist;
				}
				else $$.place=$2.place;}
			;
function	:	IDENT LPARA parameter RPARA
				{int func_index;
				$$.codebegin=$3.codebegin;
				func_index = FuncMap(GetIdent(parser->elemParser, $1.id));
				if (func_index == UNKNOWN) {
					yyerror(parser, "Unknown function.");
				}
				$$.type=Function[func_index].retval;
				$$.place=newtemp();
				iGenCode(CALL|FLAG1|FLAG2,
					func_index,$3.paracnt,$$.place);
				iGenCode(POP|FLAG1|FLAG3,$3.paracnt,0,0);}
			;
parameter	:	paralist
				{$$.codebegin=$1.codebegin;
				$$.paracnt=$1.paracnt;}
			|	{$$.codebegin=CurrentIP;
				$$.paracnt=0;}
			;
paralist	:	paralist COMMA expression
				{$$.codebegin=$1.codebegin;
				$$.paracnt=$1.paracnt+1;
				makevalue(&$3);
				iGenCode(PUSH,$3.place,0,0);
				if ($3.nolist) freetemp($3.place);}
			|	expression
				{$$.codebegin=$1.codebegin;
				$$.paracnt=1;
				makevalue(&$1);
				iGenCode(PUSH,$1.place,0,0);
				if ($1.nolist) freetemp($1.place);}
			;
%%

static void makelist(MYLParser *parser, Expval *pval)
{
	if (pval->nolist) {
		pval->truelist=CurrentIP;
		if (pval->type==T_INTEGER)
			iGenCode(JNE|FLAG2|FLAG3,pval->place,0,CODESIZE);
		else if (pval->type==T_FLOAT) {
			Code.op=JNE|FLAG2|FLAG3;
			Code.src1.i=pval->place;
			Code.src2.f=0.0;
			Code.dest=CODESIZE;
			GenCode(&Code);
		}
		else if (pval->type==T_STRING) {
			yyerror(parser, "Internal error");
		}
		pval->falselist=CurrentIP;
		iGenCode(JMP|FLAG3,0,0,CODESIZE);
		freetemp(pval->place);
	}
}

static void makevalue(Expval *pval)
{
	if (!pval->nolist) {
		pval->place=newtemp();
		backpatch(pval->truelist, CurrentIP);
		iGenCode(MOV|FLAG1,1,0,pval->place);
		iGenCode(JMP|FLAG3,0,0,CurrentIP+2);
		backpatch(pval->falselist, CurrentIP);
		iGenCode(MOV|FLAG1,0,0,pval->place);
	}
}

static void FreeCaseList(Caselistitem *plist)
/* plist is a pointer which is pointed to the head of a list */
{
	Caselistitem *temp;
	plist=plist->next;
	while (plist) {
		temp=plist;
		plist=plist->next;
		free(temp);
	}
}

static void PushCase(int type)
{
	CaseStack *nnode;
	nnode=(CaseStack *)malloc(sizeof(CaseStack));
	nnode->list.name=0;
	nnode->list.addr=CODESIZE;
	nnode->list.type=type;
	nnode->list.next=0;
	nnode->next=0;
	nnode->prev=CaseTop;
	CaseTop->next=nnode;
	CaseTop=nnode;
}

static void PopCase()
{
	CaseStack *pnode=CaseTop;
	CaseTop=CaseTop->prev;
#ifdef _DEBUG
	if (!CaseTop) yyerror(parser, "Error when pop case");
#endif
	FreeCaseList(&(pnode->list));
	free(pnode);
}

static int SearchCase(int type, int data)
{
	int i=0;
	Caselistitem *plist=&(CaseTop->list);
	while (plist->next) {
		i++;
		plist=plist->next;
		if (plist->type==type&&plist->name==data) return i;
	}
	return 0;
}

static int CurrentCase()
{
	if (CaseTop->prev) {
		Caselistitem *plist=&(CaseTop->list);
		return plist->type;
	}
	else return T_NULL;
}

static int RegCase(int type, int cnt_id, int addr)
{
	Caselistitem *pnode,*nnode;
	int i=0;
	pnode=&(CaseTop->list);
	nnode=(Caselistitem*)malloc(sizeof(Caselistitem));
	nnode->name=cnt_id;
	nnode->addr=addr;
	nnode->type=type;
	nnode->next=0;
	while (pnode->next) {
		pnode=pnode->next;
		i++;
	}
	pnode->next=nnode;
	return i+1;
}

static Labellistitem *SearchLabel(int name)
{
	Labellistitem *plabel=LabelList;
	while (plabel->next) {
		plabel=plabel->next;
		if (plabel->name==name) return plabel;
	}
	return 0;
}

static Labellistitem *NewLabel(int name)
{
	Labellistitem *plabel=LabelList,
		*nnode=(Labellistitem*)malloc(sizeof(Labellistitem));
	nnode->name=name;
	nnode->next=0;
	while (plabel->next) {
		plabel=plabel->next;
	}
	plabel->next=nnode;
	return nnode;
}

static int NewVar(int name, int type)
{
	int i=0;
	Varlistitem *pnode=&Varlist,*nnode;
	while (pnode->next) {
		i++;
		pnode=pnode->next;
	}
	nnode=(Varlistitem*)malloc(sizeof(Varlistitem));
	nnode->addr=newtemp();
	nnode->flag=0;
	nnode->name=name;
	nnode->next=0;
	nnode->type=type;
	pnode->next=nnode;
	return i+1;
}

static int SearchVar(int name)
{
	int i=0;
	Varlistitem *pnode=&Varlist;
	while (pnode->next) {
		i++;
		pnode=pnode->next;
		if (pnode->name==name) return i;
	}
	return 0;
}
static int GetVarType(int varid)
{
	Varlistitem *pnode=&Varlist;
	if (!varid) {
		printf("Variable undefined.\n");
		exit(1);
	}
	while (varid-->0) pnode=pnode->next;
	return pnode->type;
}

#if 0
static void SetVarType(int varid, int type)
{
	Varlistitem *pnode=&Varlist;
	while (varid-->0) pnode=pnode->next;
	pnode->type=type;
}
#endif

static void SetVarFlag(int varid, int flag)
{
	Varlistitem *pnode=&Varlist;
	while (varid-->0) pnode=pnode->next;
	pnode->flag=1;
}

#if 0
static int GetVarFlag(int varid)
{
	Varlistitem *pnode=&Varlist;
	while (varid-->0) pnode=pnode->next;
	return pnode->flag;
}
#endif

static int GetVar(int varid)
{
	Varlistitem *pnode=&Varlist;
	if (!varid) {
		printf("Variable undefined.\n");
		exit(1);
	}
	while (varid-->0) pnode=pnode->next;
	return pnode->addr;
}

static void backpatch(int i,int addr)
{
	while (i!=CODESIZE) {
		int temp;
		temp=VMCode[i].dest;
		VMCode[i].dest=addr;
		i=temp;
	}
}

static int merge(int a1, int a2)
{
	if (a2!=CODESIZE) {
		while (VMCode[a2].dest!=CODESIZE)
			a2=VMCode[a2].dest;
		VMCode[a2].dest=a1;
		return a2;
	}
	else return a1;
}

static void GenCode(const Instruction *inst)
{
	VMCode[CurrentIP]=*inst;
	CurrentIP++;
}

static void fGenCode(int op, float src1, float src2, int dest)
{
	VMCode[CurrentIP].op=op|FLFLAG;
	VMCode[CurrentIP].src1.f=src1;
	VMCode[CurrentIP].src2.f=src2;
	VMCode[CurrentIP].dest=dest;
	CurrentIP++;
}
static void iGenCode(int op, int src1, int src2, int dest)
{
	VMCode[CurrentIP].op=op;
	VMCode[CurrentIP].src1.i=src1;
	VMCode[CurrentIP].src2.i=src2;
	VMCode[CurrentIP].dest=dest;
	CurrentIP++;
}

static int FuncMap(const char *name)
{
	int i;

	for (i = 0; i < FuncCount; i++) {
		if (!strcmp(Function[i].funcname, name)) return i;
	}
	return UNKNOWN;
}

static int OprCode(int i)
{
	static const int xtable[]={
		-1, ADD, SUB, SHL, SHR, XOR, MUL, DIV,
		MOD, OR, AND, -1, -1, -1, -1, -1, OR,
		AND, NOTEQU, EQU, LESS, LE, GREAT, GE, SHL, SHR,
		ADD, SUB, MUL, DIV, MOD, NOT, INC, DEC,
		-1, -1, -1, -1, -1, -1, -1};
	return xtable[i];
}

static int newmem()
{
	int mem=HEAPSTART;
	while (memmap[mem]) mem++;
	memmap[mem]=1;
	return mem;
}

static int newtemp()
{
	int mem=0;
	while (memmap[mem]) mem++;
	memmap[mem]=1;
	return mem;
}

static void freetemp(int addr)
{
	if (addr!=-1)
		memmap[addr]=0;
}

void Process(MYLParser *parser)
{
	int i;
	FILE *fdump;

	CurrentIP=0;
	LoopTable.data=0;
	LoopTable.next=LoopTable.prev=0;
	LoopTop=&LoopTable;

	CaseTop=(CaseStack *)malloc(sizeof(CaseStack));
	CaseTop->prev=CaseTop->next=0;
	CaseTop->list.next=0;

	LabelList=(Labellistitem *)malloc(sizeof(Labellistitem));
	LabelList->next=0;

	for (i=0; i<STACKSIZE; i++) memmap[i]=0;

	ResetVM();
	yyparse(parser);

	// dump VM
	fdump = fopen("out.asm", "w");
	for (i = 0; i<CurrentIP; i++)
		PrintDisasm(fdump, i, &VMCode[i]);
	fprintf(fdump, "\nDumping memory:\n");
	for (i=0; i<STACKSIZE; i++) {
		switch (VMStack[i].tag) {
		case T_INTEGER:
			fprintf(fdump, "Memory[0x%4.4X]:%i\n", i, VMMEM(i).i);
			break;
		case T_FLOAT:
			fprintf(fdump, "Memory[0x%4.4X]:%f\n", i, VMMEM(i).f);
			break;
		case T_STRING:
			fprintf(fdump, "Memory[0x%4.4X]:%s\n", i, VMMEM(i).str->c_str());
			break;
		}
	}
	fclose(fdump);

	// run VM
	Run(0);

	free(CaseTop);
}

static int yylex(MYLParser *parser)
{
	ElementParser *elemParser = parser->elemParser;
	Element elem;

	if (GetElement(elemParser, &elem)==EOF) return 0;
	yylval.lexval=elem;
	if (elem.type==INTEGER) return CNTINT;
	if (elem.type==C_FLOAT) return FLT;
	if (elem.type==STRING)	return STR;
	if (elem.type==IDENTIFIER) return IDENT;
	if (elem.type==KEYWORD) {
		if (elem.id+KEYIF<KEYTYPE)
			return elem.id+KEYIF;
		else return KEYTYPE;
	}
	if (elem.type==SYMBOL) {
		if (elem.id<=S_ANDSET) return SETOPS;
		if (elem.id==S_LBRACKET) return LBRACKET;
		if (elem.id==S_RBRACKET) return RBRACKET;
		if (elem.id==S_LPARA) return LPARA;
		if (elem.id==S_RPARA) return RPARA;
		if (elem.id==S_COMMA) return COMMA;
		if (elem.id==S_SEMICOLON) return SEMICOLON;
		if (elem.id==S_LOGOR) return BOOLOR;
		if (elem.id==S_LOGAND) return BOOLAND;
		if (elem.id==S_LOGNOT) return BOOLNOT;
		if (elem.id>=S_NOTEQU && elem.id<=S_GE) return BOOLOPS;
		if (elem.id==S_ADD||elem.id==S_SUB) return ADDOPS;
		if (elem.id==S_LSHIFT||elem.id==S_RSHIFT) return SHIFTOPS;
		if (elem.id==S_BITOR||elem.id==S_BITAND||elem.id==S_BITXOR) return BITOPS;
		if (elem.id==S_NOT) return BITNOT;
		if (elem.id==S_MUL||elem.id==S_DIV||elem.id==S_MOD) return MULOPS;
		if (elem.id==S_INC) return INCOPS;
		if (elem.id==S_DEC) return DECOPS;
		if (elem.id==S_SELECT) return SELECT;
		if (elem.id==S_COLON) return COLON;
	}
	yyerror(parser, "LEX error");
	return 0;
}

static void yyerror(MYLParser *parser, const char *s)
{
	InputStream *stream = parser->stream;
	fprintf(stderr, "(Line:%3d,Column:%3d)%s\n", stream->curLine(stream), stream->curCol(stream),s);
	exit(0);
}

