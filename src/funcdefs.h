
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

#ifndef __FUNCDEFS_H
#define __FUNCDEFS_H

/* Change any function ID here, should change the function table in 
 * funcdefs.c accordinglly */
enum {
	/*OS FUNCTION*/
	DOS,
	/* String functions */
	JOIN,
	/* System calls */
	TIME,
	/* Maths */
	ACOS, ASIN, ATAN, CEIL, COS, COSH, EXP, FABS, FLOOR,
	FMOD,F_INT,LOGE,LOG10,POW,RANDOM,SIN,SINH,SQRT,SRANDOM,
	TAN,TANH,
	/* Standard I/O */
	PRINT,

	UNKNOWN = -1	/* Wrong call */
};

typedef struct FuncInfo {
	const char *funcname;
	int paramcnt;	/*	Zero means no parameter, -1 means the	*/
					/*	amount of params is flexible			*/
	int retval;		/*	Flag that determine what kind of return	*/
					/*	value it has									*/
} FuncInfo;

#ifdef __cplusplus
extern "C" {
#endif

extern FuncInfo Function[];
extern const int FuncCount;
void DoCall();

#ifdef __cplusplus
}
#endif

#endif

