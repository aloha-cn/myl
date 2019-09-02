
/* myl_internal.h
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

#ifndef __MYL_INTERNAL_H
#define __MYL_INTERNAL_H

#include "myl.h"
#include "element.h"

#ifdef __cplusplus
extern "C" {
#endif

struct MYLParser {
	InputStream *stream;
	ElementParser *elemParser;
};

#ifdef __cplusplus
}
#endif

#endif

