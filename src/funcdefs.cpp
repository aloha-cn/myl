
/* funcdefs.h - define MYL internal functions
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

#include "vmachine.h"
#include <time.h>
#include <stdio.h>

//#include "type.h"

FuncInfo Function[]={
/*Name\param count(-1 means variable params)\return type*/  
	{"dos",		1,T_INTEGER},

	{"join",	-1,T_STRING},		/* join n strings */

	{"time",	0, T_INTEGER},

	{"acos",	1,T_FLOAT},
	{"asin",	1,T_FLOAT},
	{"atan",	1,T_FLOAT},
	{"ceil",	1,T_FLOAT},
	{"cos",		1,T_FLOAT},
	{"cosh",	1,T_FLOAT},
	{"exp",		1,T_FLOAT},
	{"fabs",	1,T_FLOAT},
	{"floor",	1,T_FLOAT},
	{"fmod",	2,T_FLOAT},
	{"int",		1,T_FLOAT},
	{"loge",	1,T_FLOAT},
	{"log10",	1,T_FLOAT},
	{"pow",		2,T_FLOAT},
	{"random",	1,T_FLOAT},
	{"sin",		1,T_FLOAT},
	{"sinh",	1,T_FLOAT},
	{"sqrt",	1,T_FLOAT},
	{"srandom",	1,T_NULL},
	{"tan",		1,T_FLOAT},
	{"tanh",	1,T_FLOAT},

	{"print",	-1,T_INTEGER},
};

const int FuncCount = sizeof(Function) / sizeof(FuncInfo);

//static void sql_f(char *sevname,char *username,char *pass,char *cmd, char *retbuf);

void DoCall()
 {
	int srcint1, srcint2;
	float RetValue = 0.0f;
	StringType StrValue="";
	int i;
	int IntValue = -1;

	PrepareInt(VMCode[IP].op, &srcint1, &srcint2);
	if (Function[srcint1].paramcnt != -1
		&& srcint2 != Function[srcint1].paramcnt) {
		printf ("Amount of parameters mismatch.\n");
		exit(0);
	}
	switch (srcint1) {
	case DOS:
		if (VMStack[SP+srcint2-1].tag != T_STRING) 
			VMError(__LINE__, "params ERROR");
		IntValue = system( (VMMEM(SP+srcint2-1).str)->c_str() );
		break;
	case JOIN:
		if (srcint2<3)
			VMError(__LINE__, "Too few params");
		if (VMStack[SP+srcint2-1].tag!=T_STRING
			||VMStack[SP+srcint2-2].tag!=T_STRING)
			VMError(__LINE__, "Be not a string");
		for ((i=srcint2-3),
			StrValue+=*VMMEM(SP+srcint2-2).str; i>=0; i--) {
			if (VMStack[SP+i].tag!=T_STRING)
				VMError(__LINE__, "Error");
			else {
				StrValue+=*VMMEM(SP+srcint2-1).str;
				StrValue+=*VMMEM(SP+i).str;
			}
		}
		break;
	case PRINT:
		for (i=srcint2-1; i>=0; i--) {
			switch (VMStack[SP+i].tag) {
			case T_INTEGER:
				printf ("%d", VMMEM(SP+i).i);
				break;
			case T_FLOAT:
				printf ("%f", VMMEM(SP+i).f);
				break;
			case T_STRING:
				printf ("%s", (VMMEM(SP+i).str)->c_str());
				break;
			case T_NULL:
			default:
				VMError(__LINE__, "Print error");
			}
		}
		printf("\n");
		IntValue=srcint2;
		break;
	case TIME:
		IntValue=time(0);
		break;
	case ACOS:
		RetValue=(float)acos(GetMemFloat(SP));
		break;
	case ASIN:
		RetValue=(float)asin(GetMemFloat(SP));
		break;
	case ATAN:
		RetValue=(float)atan(GetMemFloat(SP));
		break;
	case CEIL:
		RetValue=(float)ceil(GetMemFloat(SP));
		break;
	case COS:
		RetValue=(float)cos(GetMemFloat(SP));
		break;
	case COSH:
		RetValue=(float)cosh(GetMemFloat(SP));
		break;
	case EXP:
		RetValue=(float)exp(GetMemFloat(SP));
		break;
	case FABS:
		RetValue=(float)fabs(GetMemFloat(SP));
		break;
	case FLOOR:
		RetValue=(float)floor(GetMemFloat(SP));
		break;
	case FMOD:
		RetValue=(float)fmod(GetMemFloat(SP+1),GetMemFloat(SP));
		break;
	case F_INT:
		RetValue=(float)((int)GetMemFloat(SP));
		break;
	case LOGE:
		RetValue=(float)log(GetMemFloat(SP));
		break;
	case LOG10:
		RetValue=(float)log10(GetMemFloat(SP));
		break;
	case POW:
		RetValue=(float)pow(GetMemFloat(SP+1),GetMemFloat(SP));
		break;
	case RANDOM:
		RetValue=(float)(int)
			(rand()*floor(GetMemFloat(SP))/(RAND_MAX+1.0));
		break;
	case SIN:
		RetValue=(float)sin(GetMemFloat(SP));
		break;
	case SINH:
		RetValue=(float)sinh(GetMemFloat(SP));
		break;
	case SQRT:
		RetValue=(float)sqrt(GetMemFloat(SP));
		break;
	case SRANDOM:
		srand((unsigned)GetMemInt(SP));
		break;
	case TAN:
		RetValue=(float)tan(GetMemFloat(SP));
		break;
	case TANH:
		RetValue=(float)tanh(GetMemFloat(SP));
		break;
/*	ACOS, ASIN, ATAN, CEIL, COS, COSH, EXP, FABS, FLOOR,
	FMOD,INT,LOGE,LOG10,POW,RANDOM,SIN,SINH,SQRT,SRANDOM,
	TAN,TANH,*/
	case UNKNOWN:
		printf("Unknown function be called.\n");
		exit(0);
		break;
	default:
		printf("Unhandeled function(%d) be called.\n",srcint1);
		break;
	}
	switch (Function[srcint1].retval) {
	case T_FLOAT:		/* Function returns float	*/
		SetMemFloat(VMCode[IP].dest, RetValue);
		break;
	case T_INTEGER:		/* Function retruns integer	*/
		SetMemInt(VMCode[IP].dest, IntValue);
		break;
	case T_STRING:     /* Function retruns string) */
		SetMemStr(VMCode[IP].dest, StrValue);
		break;
	}
	IP++;
}


