
/* fileio.c - utilities to read file
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
#include <stdlib.h>

#include "fileio.h"

typedef struct FileInputStream {
	InputStream stream;
	FILE *infile;
	int line;
	int col;
} FileInputStream;

static int ReadFileStream(InputStream *s)
{
	FileInputStream *stream = (FileInputStream *)s;
	int ch = fgetc(stream->infile);

	if (ch == '\n') {
		stream->line++;
		stream->col=0;
	} else {
		stream->col++;
	}

	return ch;
}

static int GetCurLine(const InputStream *s)
{
	FileInputStream *stream = (FileInputStream *)s;

	return stream->line;
}

static int GetCurCol(const InputStream *s)
{
	FileInputStream *stream = (FileInputStream *)s;

	return stream->col;
}

InputStream *CreateFileStream(const char *filename)
{
	FileInputStream *stream = (FileInputStream *)malloc(sizeof(FileInputStream));
	InputStream *s = (InputStream *)stream;

	if (!stream) {
		return NULL;
	}

	stream->infile = fopen(filename,"r");
	if (!stream->infile) {
		free(stream);
		return NULL;
	}

	s->getChar = ReadFileStream;
	s->curLine = GetCurLine;
	s->curCol= GetCurCol;
	stream->line = 1;
	stream->col = 0;

	return (InputStream *)stream;
}

void CloseFileStream(InputStream *s)
{
	FileInputStream *stream = (FileInputStream *)s;

	fclose(stream->infile);
	free(stream);
}

