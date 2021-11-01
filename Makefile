CFLAGS =	-g -Wall -DDEBUG  #-pedantic
OBJCFLAGS =	-fobjc-exceptions

all: test_inject test_inject2 proclist monitor fuzz-aqua

fuzz-aqua: fuzz-aqua.m util.o FuzzTarget.o FuzzToggleEvent.o
	gcc $(CFLAGS) $(OBJCFLAGS) -framework Carbon -framework Foundation -o fuzz-aqua fuzz-aqua.m FuzzTarget.o util.o FuzzToggleEvent.o

monitor: monitor.c
	gcc $(CFLAGS) -framework Carbon -o monitor monitor.c

test_inject: test_inject.c
	gcc $(CFLAGS) -framework Carbon -o test_inject test_inject.c

test_inject2: test_inject2.m util.o FuzzTarget.o FuzzToggleEvent.o
	gcc $(CFLAGS) $(OBJCFLAGS) -framework Carbon -framework Foundation -o test_inject2 test_inject2.m FuzzTarget.o util.o FuzzToggleEvent.o

proclist: proclist.c
	gcc $(CFLAGS) -framework Carbon -o proclist proclist.c

clean:
	-rm monitor test_inject test_inject2 *.o proclist fuzz-aqua

clean-all: clean clean-backups

clean-backups:
	-rm *~

%.o: %.c %.h
	gcc $(CFLAGS) -c -o $*.o $*.c

%.o: %.m %.h
	gcc $(CFLAGS) $(OBJCFLAGS) -c -o $*.o $*.m
