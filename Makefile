CC=gcc

CPP=g++

YACC=yacc

CFLAGS += -O2 -Wall

CFLAGS += -I./src

OBJS += ./src/main.o
OBJS += ./src/myl.o
OBJS += ./src/element.o
OBJS += ./src/fileio.o
OBJS += ./src/stackitem.o
OBJS += ./src/funcdefs.o
OBJS += ./src/vmachine.o
OBJS += ./src/y.tab.o

LIBS =
#LIBS += -lrt

LDFLAGS =

all: myl

myl: $(OBJS)
	$(CPP) $(LDFLAGS) -o myl $(OBJS) $(LIBS)

%.o: %.c
	$(CC) -c -o $@ $(CFLAGS) $<

%.o: %.cpp
	$(CPP) -c -o $@ $(CFLAGS) $<

./src/y.tab.o: ./src/y.tab.cpp

./src/y.tab.cpp: ./src/gram.y
	$(YACC) -o y.tab.cpp $<
	mv y.tab.cpp src

install: $(addprefix $(DESTDIR)$(BINDIR)/,$(ALL))

clean:
	rm -f core ./src/*~ ./src/*.o ./src/y.tab.cpp myl

