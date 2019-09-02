
/* element.h - lexis analyzer
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

#ifndef __ELEMENT_H
#define __ELEMENT_H

/* Data types */
#include "inputstream.h"

enum {
	S_SET, S_ADDSET, S_SUBSET, S_LSSET, S_RSSET, S_XORSET, S_MULSET, S_DIVSET,
	S_MODSET, S_ORSET, S_ANDSET, S_SELECT, S_COLON, S_LOGNOT, S_LOGOR, S_LOGAND, S_BITOR,
	S_BITAND, S_NOTEQU, S_EQU, S_LESS, S_LE, S_GREAT, S_GE, S_LSHIFT, S_RSHIFT,
	S_ADD, S_SUB, S_MUL, S_DIV, S_MOD, S_NOT, S_INC, S_DEC,
	S_LPARA, S_RPARA, S_LBRACKET, S_RBRACKET, S_QUOTE, S_COMMA, S_SEMICOLON,
	S_POINT, S_BITXOR
};

#ifdef __cplusplus
extern "C" {
#endif

typedef enum ElemType {
	KEYWORD,IDENTIFIER,INTEGER,C_FLOAT,STRING,SYMBOL,NTSYMBOL,ENDFLAG=-1
} ElemType;

typedef struct Element {
	ElemType type;
	int id;
} Element;

extern const int FIRSTTYPE;

typedef struct ElementParser ElementParser;

ElementParser *CreateElementParser(InputStream *stream);
void CloseElementParser(ElementParser *elem);

int GetElement(ElementParser *parser, Element *elem);

/* Getting items from elements lists */
char *GetIdent(ElementParser *parser, int idx);
int GetInteger(ElementParser *parser, int idx);
float GetFloat(ElementParser *parser, int idx);
char *GetString(ElementParser *parser, int idx);

#ifdef __cplusplus
}
#endif

#endif

