
/* main.c - Entry
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

#include "myl.h"
#include "fileio.h"

int main(int argc, char* argv[])
{
	MYLParser *parser = NULL;
	InputStream *stream = NULL;

	if (argc != 2) {
		printf("usage::=myl <infile>\n");
		return 1;
	}
	stream = CreateFileStream(argv[1]);

	if (!stream) {
		printf("Can't open file.\n");
		return 2;
	}

	parser = CreateMYLParser(stream);
	if (!parser) {
		printf("Can't create parser.\n");
		return 3;
	} else {
		Process(parser);
	}

	CloseMYLParser(parser);
	CloseFileStream(stream);

	return 0;
}

