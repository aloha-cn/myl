
/* stackitem.h - stack style memory used by VM
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

#ifndef __STACKITEM_H
#define __STACKITEM_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct StackItem {
	int data;
	struct StackItem *next;
	struct StackItem *prev;
} StackItem;

#define IsStackEmpty(s) (!((s)->prev))

void Push(StackItem **s, int data);
int Pop(StackItem **s);

#ifdef __cplusplus
}
#endif

#endif

