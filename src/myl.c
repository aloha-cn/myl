
/* myl.c - define APIs of MYL compiler
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

#include <stdlib.h>

#include "myl_internal.h"

MYLParser *CreateMYLParser(InputStream *stream)
{
	MYLParser *parser = malloc(sizeof(MYLParser));

	if (!parser) {
		return NULL;
	}

	parser->elemParser = CreateElementParser(stream);
	if (!parser->elemParser) {
		free(parser);
		return NULL;
	}

	parser->stream = stream;
	return parser;
}

void CloseMYLParser(MYLParser *parser)
{
	CloseElementParser(parser->elemParser);
	free(parser);
}

