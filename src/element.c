
/* element.c - lexis analyzer
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

#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "element.h"

#define TABLE_SIZE(__x) ((int)(sizeof(__x)/sizeof(__x[0])))

static const char *Keywords[]={
	"if",	"else",	"for",	"while",	"do",
	"continue",	"break", "switch",	"case",	
	"default",	"goto", 
	/* Types */
	"integer", "float", "string", "list"
};

const int FIRSTTYPE=11;
static const char *Symbols[]={
	"=",
	"+=",	"-=",	"<<=",	">>=",	"^=",
	"*=",	"/=",	"%=",
	"|=",	"&=",
	"?",	":",
	"!",
	"||",
	"&&",
	"|",
	"&",
	"!=",	"==",
	"<",	"<=",	">",	">=",
	"<<",	">>",
	"+",	"-",
	"*",	"/",	"%",
	"~",	"++",	"--",
	"(",	")",	
	"{",	"}",
	"\"",	",",	";",
	".",	"^"
};
static const char Charset[]="=+-<>^*/%|&?:!(){}\",;~.";

/* Element items */
typedef struct IntegerItem {
	int data;
	struct IntegerItem *next;
} IntegerItem;

typedef struct FloatItem {
	float data;
	struct FloatItem *next;
} FloatItem;

typedef struct IdentItem {
	char *data;
	struct IdentItem *next;
} IdentItem;

typedef struct StringItem {
	char *data;
	struct StringItem *next;
} StringItem;

struct ElementParser {
	/* Priviate Data Definitions */
	InputStream *stream;
	char buffer[128];
	int index;
	int ch;
	/* Elements lists */
	IntegerItem integerList;
	FloatItem floatList;
	IdentItem identList;
	StringItem stringList;
};

static int FindInteger(IntegerItem *integerList, int num);
static int NewInteger(IntegerItem *integerList, int num);
static int RegInteger(IntegerItem *integerList, int num);

static int FindFloat(FloatItem *floatList, float num);
static int NewFloat(FloatItem *floatList, float num);
static int RegFloat(FloatItem *floatList, float num);

static int FindIdent(IdentItem *itemList, const char *name);
static int NewIdent(IdentItem *itemList, const char *name);
static int RegIdent(IdentItem *itemList, const char *name);

static int NewString(StringItem *stringList, const char *name);
static int FindString(StringItem *stringList, const char *name);
static int RegString(StringItem *stringList, const char *name);

static int FindKeyword(const char *name);
static int FindSymbol(const char *name);
static int _ch_isblank(int ch);
static int _ch_issymbol(int ch);
static void ReportError();
/* DFA */
static int state02(ElementParser *parser, Element *elem);
static int state03(ElementParser *parser, Element *elem);
static int state04(ElementParser *parser, Element *elem);
static int state05(ElementParser *parser, Element *elem);
static int state06(ElementParser *parser, Element *elem);
static int state07(ElementParser *parser, Element *elem);
static int state08(ElementParser *parser, Element *elem);
static int state09(ElementParser *parser, Element *elem);
static int state10(ElementParser *parser, Element *elem);
static int state11(ElementParser *parser, Element *elem);
static int state12(ElementParser *parser, Element *elem);
static int state13(ElementParser *parser, Element *elem);
static int state14(ElementParser *parser, Element *elem);
static int state15(ElementParser *parser, Element *elem);
static int state16(ElementParser *parser, Element *elem);
static int state17(ElementParser *parser, Element *elem);
static int state18(ElementParser *parser, Element *elem);

static int app_state01(ElementParser *parser, Element *elem);
static int app_state02(ElementParser *parser, Element *elem);
static int app_state05(ElementParser *parser, Element *elem);
static int float_state(ElementParser *parser, Element *elem);

static int FindInteger(IntegerItem *iList, int num)
{
	int i=0;
	IntegerItem *pnode=iList;
	while (pnode->next) {
		i++;
		pnode=pnode->next;
		if (pnode->data==num)
			return i;
	}
	return 0;
}

static int NewInteger(IntegerItem *iList, int num)
{
	int i=0;
	IntegerItem *pnode=iList, *nnode;
	while (pnode->next) {
		i++;
		pnode=pnode->next;
	}
	nnode=(IntegerItem*)malloc(sizeof(IntegerItem));
	nnode->data=num;
	nnode->next=0;
	pnode->next=nnode;
	return i+1;
}

static int RegInteger(IntegerItem *integerList, int num)
{
	int i;

	if (!(i = FindInteger(integerList, num))) {
		return NewInteger(integerList, num);
	}
	else return i;
}

static int FindFloat(FloatItem *floatList, float num)
{
	int i=0;
	FloatItem *pnode = floatList;

	while (pnode->next) {
		i++;
		pnode=pnode->next;
		if (pnode->data==num)
			return i;
	}
	return 0;
}

static int NewFloat(FloatItem *floatList, float num)
{
	int i=0;
	FloatItem *pnode = floatList, *nnode;

	while (pnode->next) {
		i++;
		pnode=pnode->next;
	}
	nnode=(FloatItem*)malloc(sizeof(FloatItem));
	nnode->data=num;
	nnode->next=0;
	pnode->next=nnode;
	return i+1;
}

static int RegFloat(FloatItem *floatList, float num)
{
	int i;

	if (!(i=FindFloat(floatList, num))) {
		return NewFloat(floatList, num);
	}
	else return i;
}

static int FindString(StringItem *stringList, const char *name)
{
	int i=0;
	StringItem *pnode = stringList;

	while (pnode->next) {
		i++;
		pnode=pnode->next;
		if (!strcmp(pnode->data, name))
			return i;
	}
	return 0;
}

static int NewString(StringItem *stringList, const char *name)
{
	int i=0;
	StringItem *pnode = stringList, *nnode;

	while (pnode->next) {
		i++;
		pnode=pnode->next;
	}
	nnode=(StringItem*)malloc(sizeof(StringItem));
	nnode->data=(char *)malloc(sizeof(char)*strlen(name));
	strcpy(nnode->data, name);
	nnode->next=0;
	pnode->next=nnode;
	return i+1;
}

static int RegString(StringItem *stringList, const char *name)
{
	int i;

	if (!(i = FindString(stringList, name))) {
		return NewString(stringList, name);
	}
	else return i;
}

static int FindIdent(IdentItem *identList, const char *name)
{
	int i=0;
	IdentItem *pnode = identList;

	while (pnode->next) {
		i++;
		pnode=pnode->next;
		if (!strcmp(pnode->data, name))
			return i;
	}
	return 0;
}

static int NewIdent(IdentItem *identList, const char *name)
{
	int i=0;
	IdentItem *pnode = identList, *nnode;

	while (pnode->next) {
		i++;
		pnode=pnode->next;
	}
	nnode=(IdentItem*)malloc(sizeof(IdentItem));
	nnode->data=(char *)malloc(sizeof(char)*strlen(name));
	strcpy(nnode->data, name);
	nnode->next=0;
	pnode->next=nnode;
	return i+1;
}

static int RegIdent(IdentItem *identList, const char *name)
{
	int i;

	if (!(i=FindIdent(identList, name))) {
		return NewIdent(identList, name);
	}
	else return i;
}

float GetFloat(ElementParser *parser, int idx)
{
	FloatItem *pnode = &parser->floatList;

	while (idx-- > 0) pnode = pnode->next;
	return pnode->data;
}

int GetInteger(ElementParser *parser, int idx)
{
	IntegerItem *pnode = &parser->integerList;

	while (idx-- > 0) pnode = pnode->next;
	return pnode->data;
}

char *GetIdent(ElementParser *parser, int idx)
{
	IdentItem *pnode = &parser->identList;

	while (idx-- > 0) pnode = pnode->next;
	return pnode->data;
}

char *GetString(ElementParser *parser, int idx)
{
	StringItem *pnode = &parser->stringList;

	while (idx-- > 0) pnode = pnode->next;
	return pnode->data;
}

static int FindKeyword(const char *name)
{
	int i;
	for (i=0; i<TABLE_SIZE(Keywords); i++)
		if (!strcmp (Keywords[i], name)) return i;
	return -1;
}

static int FindSymbol(const char *name)
{
	int i;
	for (i=0; i<TABLE_SIZE(Symbols); i++)
		if (!strcmp(Symbols[i], name)) return i;
	return -1;
}

static int _ch_isblank(int ch)
{
	return ch == ' ' || ch == '\t'
		|| ch == '\n' || ch == -1;
}

static int _ch_issymbol(int ch)
{
	return strrchr(Charset, ch)!=NULL;
}

static void ReportError()
{
	printf("Error\n");
	exit (1);
}

static void InitDFA(ElementParser *parser)
{
	InputStream *stream = parser->stream;

	parser->ch = stream->getChar(stream);
}

int app_state01(ElementParser *parser, Element *elem)
{
	if (isdigit(parser->ch))
		return app_state02(parser, elem);
	else {
		parser->buffer[parser->index]=0;
		elem->type=SYMBOL;
		elem->id=FindSymbol(parser->buffer);
		return 1;
	}
}
int app_state02(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	while (isdigit(parser->ch)) {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	if (parser->ch=='E' || parser->ch=='e') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
		return app_state05(parser, elem);
	}
	else {
		return float_state(parser, elem);
	}
}
int app_state05(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='+' || parser->ch=='-') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	if (isdigit(parser->ch)) {
		/* append state06 */
		while (isdigit(parser->ch)) {
			parser->buffer[parser->index++]=parser->ch;
			parser->ch = stream->getChar(stream);
		}
		return float_state(parser, elem);
	}
	else {
		ReportError();
		return 0;
	}
}

int float_state(ElementParser *parser, Element *elem)
{
	parser->buffer[parser->index] = 0;
	elem->type = C_FLOAT;
	elem->id = RegFloat(&parser->floatList, (float)atof(parser->buffer));
	return 1;
}

ElementParser *CreateElementParser(InputStream *stream)
{
	ElementParser *parser = calloc(1, sizeof(ElementParser));

	if (!parser) {
		return NULL;
	}

	parser->stream = stream;
	InitDFA(parser);
	return parser;
}

void CloseElementParser(ElementParser *parser)
{
	free(parser);
}

int GetElement(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	parser->index=0;
	while (parser->ch!=EOF) {
		if (_ch_isblank(parser->ch)) {
			parser->ch = stream->getChar(stream);
			continue;
		}
		if (isalpha(parser->ch)) {
			parser->buffer[parser->index++]=parser->ch;
			parser->ch = stream->getChar(stream);
			return state02(parser, elem);
		}
		else if (isdigit(parser->ch))  {
			parser->buffer[parser->index++]=parser->ch;
			parser->ch = stream->getChar(stream);
			return state03(parser, elem);
		}
		else { 
			switch (parser->ch) {
				case '(':
				case ')':
				case '{':
				case '}':
				case ';':
				case ',':
				case '?':
				case ':':
				case '~':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					parser->buffer[parser->index]=0;
					elem->type=SYMBOL;
					elem->id=FindSymbol(parser->buffer);
					return 1;
				case '.':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					return app_state01(parser, elem);
				case '+':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					return state04(parser, elem);
				case '-':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					return state06(parser, elem);
				case '*':
				case '%':
				case '!':
				case '^':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					return state07(parser, elem);
				case '/':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					switch (state16(parser, elem)) {
						case 2:
							parser->index=0;
							continue;
						case 0:
							return 0;
						default:
							return 1;
					}
				case '=':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					return state05(parser, elem);
				case '&':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					return state08(parser, elem);
				case '|':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					return state09(parser, elem);
				case '<':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					return state10(parser, elem);
				case '>':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					return state11(parser, elem);
				case '\"':
					/*				parser->buffer[parser->index++]=parser->ch;*/
					/* Skip the first letter of a string */
					parser->ch = stream->getChar(stream);
					return state14(parser, elem);
				case '\'':
					parser->buffer[parser->index++]=parser->ch;
					parser->ch = stream->getChar(stream);
					return state15(parser, elem);
				default:
					ReportError();
					return 0;
			}
		}
	}
	elem->type=ENDFLAG;
	elem->id=0;
	return EOF;
}

static int state02(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	while (isalpha(parser->ch) || isdigit(parser->ch)) {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	if (_ch_isblank(parser->ch) || _ch_issymbol(parser->ch)) {
		parser->buffer[parser->index]=0;
		if ((elem->id=FindKeyword(parser->buffer))!=-1) {
			elem->type=KEYWORD;
		}
		else {
			elem->type=IDENTIFIER;
			elem->id=RegIdent(&parser->identList, parser->buffer);
		}
		return 1;
	}
	else {
		ReportError();
		return 0;
	}
}

static int state03(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	while (isdigit(parser->ch)) {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	if (parser->ch=='.') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
		if (isdigit(parser->ch))
			return app_state02(parser, elem);
		else if (parser->ch=='E'||parser->ch=='e') {
			parser->buffer[parser->index++]=parser->ch;
			parser->ch = stream->getChar(stream);
			return app_state05(parser, elem);
		}
		else
			return float_state(parser, elem);
	}
	else if (parser->ch=='E' || parser->ch=='e') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
		return app_state05(parser, elem);
	}
	if (_ch_isblank(parser->ch) || _ch_issymbol(parser->ch)) {
		parser->buffer[parser->index] = 0;
		elem->type = INTEGER;
		elem->id = RegInteger(&parser->integerList, atoi(parser->buffer));
		return 1;
	}
	else {
		ReportError();
		return 0;
	}
}

static int state04(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='+' || parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state05(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state06(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='-' || parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state07(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state08(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='&' || parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state09(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='|' || parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state10(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='<') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
		return state12(parser, elem);
	}
	else if (parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state11(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='>') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
		return state13(parser, elem);
	}
	else if (parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state12(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state13(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state14(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	while (parser->ch!=EOF) {
		if (parser->ch=='\"') {
			parser->buffer[parser->index]=0;
			parser->ch = stream->getChar(stream);
			elem->type = STRING;
			elem->id = RegString(&parser->stringList, parser->buffer);
			return 1;
		}
		else if (parser->ch=='\\') {
			parser->ch = stream->getChar(stream);
			if (parser->ch<='Z' && parser->ch>='A') {
				parser->buffer[parser->index++]=parser->ch-'A'+1;
				parser->ch = stream->getChar(stream);
			}
			else switch (parser->ch) {
				case 't':
					parser->buffer[parser->index++]='\t';
					parser->ch = stream->getChar(stream);
					break;
				case 'n':
					parser->buffer[parser->index++]='\n';
					parser->ch = stream->getChar(stream);
					break;
				case 'r':
					parser->buffer[parser->index++]='\r';
					parser->ch = stream->getChar(stream);
					break;
				case 'b':
					parser->buffer[parser->index++]='\b';
					parser->ch = stream->getChar(stream);
					break;
				case '\"':
					parser->buffer[parser->index++]='\"';
					parser->ch = stream->getChar(stream);
					break;
				case '\'':
					parser->buffer[parser->index++]='\'';
					parser->ch = stream->getChar(stream);
					break;
				case '\\':
					parser->buffer[parser->index++]='\\';
					parser->ch = stream->getChar(stream);
					break;
				default:
					ReportError();
			}
		}
		else {
			parser->buffer[parser->index++]=parser->ch;
			parser->ch = stream->getChar(stream);
		}
	}
	return 0;
}

static int state15(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='\\') {
		parser->ch = stream->getChar(stream);
		if (parser->ch<='Z' && parser->ch>='A') {
			parser->buffer[parser->index]=parser->ch-'A'+1;
			parser->ch = stream->getChar(stream);
		}
		else switch (parser->ch) {
			case 't':
				parser->buffer[parser->index]='\t';
				parser->ch = stream->getChar(stream);
				break;
			case 'n':
				parser->buffer[parser->index]='\n';
				parser->ch = stream->getChar(stream);
				break;
			case 'r':
				parser->buffer[parser->index]='\r';
				parser->ch = stream->getChar(stream);
				break;
			case 'b':
				parser->buffer[parser->index]='\b';
				parser->ch = stream->getChar(stream);
				break;
			case '\"':
				parser->buffer[parser->index]='\"';
				parser->ch = stream->getChar(stream);
				break;
			case '\'':
				parser->buffer[parser->index]='\'';
				parser->ch = stream->getChar(stream);
				break;
			case '\\':
				parser->buffer[parser->index]='\\';
				parser->ch = stream->getChar(stream);
				break;
			default:
				ReportError();
				return 0;
		}
	}
	else {
		parser->buffer[parser->index]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	if (parser->ch=='\'') {
		parser->ch = stream->getChar(stream);
		/* MYL doesn't accept char constant */
		ReportError();
		return 0;
		/*
		   elem->type=CONSTANT;
		   elem->id = RegInteger(&parser->integerList, parser->buffer[parser->index]);
		   return 1;*/
	}
	return 0;
}

static int state16(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='*') {
		parser->ch = stream->getChar(stream);
		return state17(parser, elem);
	}
	else if (parser->ch=='=') {
		parser->buffer[parser->index++]=parser->ch;
		parser->ch = stream->getChar(stream);
	}
	parser->buffer[parser->index]=0;
	elem->type=SYMBOL;
	elem->id=FindSymbol(parser->buffer);
	return 1;
}

static int state17(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	while (parser->ch!=EOF) {
		if (parser->ch=='*') {
			parser->ch = stream->getChar(stream);
			if (state18(parser, elem))	return 2;
		}
		parser->ch = stream->getChar(stream);
	}
	return 0;
}

static int state18(ElementParser *parser, Element *elem)
{
	InputStream *stream = parser->stream;

	if (parser->ch=='/') {
		parser->ch = stream->getChar(stream);
		return 2;
	}
	else return 0;
}

