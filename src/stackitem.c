
/* stackitem.c - stack style memory used by VM
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

#include "stackitem.h"

void Push(StackItem **s, int data)
{
	StackItem *p = (StackItem *)malloc(sizeof(StackItem));
	if (!p) {
		fprintf(stderr, "Out of memory\n");
		exit(4);
	}

	p->data = data;
	p->next = 0;
	p->prev = (*s);
	(*s)->next = p;
	(*s) = p;
}

int Pop(StackItem **s)
{
	StackItem *p = (*s);
	int temp;

	(*s) = (*s)->prev;
	
	if (!(*s)) {
		fprintf(stderr, "Stack error\n");
		exit(4);
	}
	
	(*s)->next = 0;
	temp = p->data;
	free(p);
	return temp;
}

