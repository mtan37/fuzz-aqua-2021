CFLAGS =	-g -Wall -DDEBUG  #-pedantic
OBJCFLAGS =	-fobjc-exceptions

all: monitor fuzz-aqua

fuzz-aqua: fuzz-aqua.m util.o FuzzTarget.o FuzzToggleEvent.o
	gcc $(CFLAGS) $(OBJCFLAGS) -framework Carbon -framework Foundation -o fuzz-aqua fuzz-aqua.m FuzzTarget.o util.o FuzzToggleEvent.o

monitor: monitor.c
	gcc $(CFLAGS) -framework Carbon -o monitor monitor.c

clean:
	-rm *.o proclist fuzz-aqua

clean-all: clean clean-backups

clean-backups:
	-rm *~

%.o: %.c %.h
	gcc $(CFLAGS) -c -o $*.o $*.c

%.o: %.m %.h
	gcc $(CFLAGS) $(OBJCFLAGS) -c -o $*.o $*.m
