/* Copyright (c) 2005 Gregory Cooksey, Fredrick Moore, Barton Miller
 * All rights reserved
 *  
 * This software is furnished under the condition that it may not be provided or
 * otherwise made available to, or used by, any other person.  No title to or
 * ownership of the software is hereby transferred.
 *
 * Any use of this software must include the above copyright notice.
 */

static const char Copyright[] =
  "@(#) Copyright (c) 2005 by Gregory Cooksey, Fredrick Moore, and Barton\
 Miller.\n All rights reserved.\n";

/* The equivalent of fuzz.c, but for testing OS X graphical apps.
 * TODO: Make a big, fancy, informative header comment as seen in fuzz.c.
 */

/*
 * Usage:  fuzz-aqua [-vlwch] [-s seed] [-k keys] [-d delay] [-r infile]
 *                   [-o outfile] pid [n]
 *
 * Send random input to the application represented by pid.
 *
 * -v          Allow "invalid" input (input that couldn't be provided by a
 *             normal user with a single keyboard and mouse).  By default,
 *             only valid input is produced.
 *
 * -l          Allow "overlapping" input where (keydown, keyup) and (buttondown,
 *             buttonup) can be interleaved with other input events.  By
 *             default, keypresses and button clicks are atomic (potentially
 *             bracketed by modifier keys)
 *
 * -w          Application to test has a single, rectangular window; print its
 *             geometry information (x1, y1, width, height).  This can be used
 *             to help ensure repeatability (although that may be tedious).
 *
 *             The semantics of this flag were formerly:
 *             Application to test has a single, rectangular window.  This
 *             reduces the amount of guesswork involved in picking random points
 *             in the target application.  Disallows clicks to the title bar
 *             (which can be problematic by allowing the window to be closed,
 *             minimized, or resized); should not be used for multi-window
 *             applications or applications with nonstandard title-bar heights
 *
 * -c          Print copyright and exit.
 *
 * -h          Print help and exit.
 *
 * -s seed     Specify the seed to the random-number generator (for
 *             repeatability)
 *
 * -k keys     Prevent the keys represented by characters in "keys" from being
 *             sent when the command key is down.  Allows the user to prevent
 *             things like Cmd+Q, Cmd+W, Cmd+M, Cmd+H, etc. from interfering
 *             with the rest of the random input.
 *
 * -r file     Replay events in file.
 *
 * -o outfile  Save generated events to outfile (for later replay).
 *
 * -d delay    Delay in seconds (floating point accepted) between input events.
 *
 * pid         PID of application to test.  You can get this from proclist.
 *
 * n           Number of events to send.
 *
 * Defaults:   fuzz-aqua -o /dev/null -d 0 n=1000
 *
 *  Authors:   Fred Moore, Greg Cooksey
 */

/* All the cool kids use these header files. */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>

#import <Foundation/Foundation.h>

/* Import FuzzTarget, as it's the main attraction here. */
#import "FuzzTarget.h"
/* Our utility functions can be found here */
#include "util.h"

/* Turn this on to have fuzz-aqua print a line representing each non-overlapping
 * event it sends
 */
#define EVENT_OUTPUT 0
/* Turn this on to have fuzz-aqua complain about problems with sending events
 */
#ifndef PROBLEM_OUTPUT
#define PROBLEM_OUTPUT 0
#endif

int flagv = 0;      /* -v: Invalid input */
int flagl = 0;      /* -l: Overlapping input */
int flagw = 0;      /* -w: Single, rectangular window */
/*int flagr = 0;*/      /* -r: Replay file */
/*int flago = 0;*/      /* -o: Output file */
unsigned flagd = 0; /* -d: Delay between events, in useconds */
int flags = 0;      /* -s: to seed or not to seed */

char* namer = NULL; /* Input/replay filename */
char* nameo = NULL; /* Output filename */
FILE* filer = NULL; /* Input/replay file */
FILE* fileo = NULL; /* Output file*/

char* listk = NULL; /* Keys we won't send when Cmd is down */
pid_t pid = -1;     /* PID of application to test */
unsigned long seed = 0; /* seed to random-number generator (srandom(seed)) */
int eventCount; /* Number of events to send to the target */

FuzzTarget* target = nil; /* The target object */

const char* use = "\
Usage: fuzz-aqua [-vlwch] [-s seed] [-k keys] [-d delay]\n\
                 [-r infile] [-o outfile] PID [n]";
const char* help_hint = "Try `fuzz-osx -h' for more information.";
const char* help_prefix = "\
fuzz-aqua sends random user input to the specified application.\n";
const char* help_body = "\n\
Options:\n\
   PID      ID of process to test; run proclist to see list of PIDs\n\
   n        number of events to send\n\
  -v        allow invalid user events\n\
  -l        allow overlapping events\n\
  -w        print window geometry (x1, y1, width, height); only works for\n\
            single-window applications\n\
  -s seed   seed random-number generator with <seed> (for repeatability)\n\
  -k keys   suppress the keys represented in <keys> from being sent with Cmd\n\
  -d delay  delay for <delay> seconds between events\n\
  -r file   replay events stored in <file>\n\
  -o file   save generated events to <file> for later replay\n\
  -c        print copyright information and exit\n\
  -h        print this help and exit\n\n\
Default:    fuzz-aqua -d 0 -k \"QMEsc\" <PID> 1000\n\n\
For a more detailed explanation of the options, see fuzz-aqua.m\n";

const CGKeyCode keyCodeMap[] = {
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
  23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41,
  42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 71, 96, 97, 98, 99, 100, 101,
  103, 105, 107, 109, 111, 113, 115, 116, 117, 118, 119, 120, 121, 122, 123,
  124, 125, 126
};
const int keyCodeMapLen = sizeof(keyCodeMap) / sizeof(keyCodeMap[1]);
const char* keyCodeNames[] = {
  "A", "S", "D", "F", "H", "G", "Z", "X", "C", "V", "B", "Q", "W", "E", "R",
  "Y", "T", "1", "2", "3", "4", "6", "5", "=", "9", "7", "-", "8", "0", "]",
  "O", "U", "[", "I", "P", "Return", "L", "J", "'", "K", ";", "\\", ",", "/",
  "N", "M", ".", "Tab", "Space", "`", "Backspace", "Enter", "Esc", "Clear",
  "F5", "F6", "F7", "F3", "F8", "F9", "F11", "F13", "F14", "F10", "F12", "F15",
  "Home", "PageUp", "Delete", "F4", "End", "F2", "PageDown", "F1", "Left",
  "Right", "Down", "Up"
};

typedef enum {
  KEY_Q = 12, KEY_W = 13, KEY_P = 35, KEY_M = 46, ESCAPE = 53,
  COMMAND = 55, SHIFT = 56, OPTION = 58, CONTROL = 59
} keyCodes;
  
/* Forward declarations */
void init();

void usage() {
  puts(use);
  puts(help_hint);
  exit(1);
}

void help() {
  puts(help_prefix);
  puts(use);
  puts(help_body);
  exit(0);
}

void sendValidEvents(int count);

/* Sends count simple non-overlapping events */
void sendNonOverlappingEvents(int count);

int main(int argc, char** argv) {
  int c;
  float f;
  unsigned long ulng;
  NSAutoreleasePool *pool;

  /* External variables used by getopt */
  extern int   optind; /* Index of option currently being processed */
  extern char* optarg; /* Argument string (if any) to current option */

  /* Process each option and set up the environment appropriately */
  while ((c = getopt(argc, argv, "mvlwchs:k:r:o:d:")) != EOF) {
    switch (c) {
    case 'm':
      printf("INT32_MAX = %d\n", INT32_MAX); exit(0);
    case 'v':
      puts("Warning: Invalid input is not yet supported; ignoring -v.");
      flagv = 1; break;
    case 'l': flagl = 1; break;
    case 'w': flagw = 1; break;
    case 'c':
      puts(Copyright + 5);
      exit(0);
    case 'h': help();
    case 's':
      if(sscanf(optarg, "%ld", &ulng) < 1)
	usage();
      flags = 1;
      seed  = ulng;
      break;
    case 'k':
      puts("Warning: the -k flag is not yet supported.\n\
By default, Cmd+(Q|M|Opt+Esc) are suppressed.");
      listk = optarg; break;
    case 'r':
      puts("Warning: File replay is not yet implemented.");
      namer = optarg; break;
    case 'o':
      puts("Warning: File output is not yet implemented.");
      nameo = optarg; break;
    case 'd':
      if (sscanf(optarg, "%f", &f) < 1)
	usage();
      flagd = (unsigned) (f * 1000000.0);
      break;
    default:
      usage();
    }
  }

  /* Now "optind" points to the command */
  if (optind >= argc) usage();
  pid = atol(argv[optind]);
  optind++;

  /* Now it points to the number of events (if specified) */
  if (optind >= argc) eventCount = 1000;
  else eventCount = atol(argv[optind]);

  /* We need an autorelease pool to use any objects */
  pool = [[NSAutoreleasePool alloc] init];

  /* Initialize everything and everybody */
  init();

  printf("Sending %d events to target\n", eventCount);
  if (flagl) {
    sendValidEvents(eventCount);
  } else {
    sendNonOverlappingEvents(eventCount);
  }

  /* Release the objects we own */
  if (target != nil) {
    [target release];
  }
  [pool release];
  return 0;
}

void init() {
  long now;
  time_t t;

  /* Init random numbers */
  if (!flags) {
    t = (long)time(&now);
    if(t == (time_t)-1) {
      puts("Warning: Seeding with time(time_t*) failed.  Seeding with PID instead.");
      seed = pid;
    }
    seed = (unsigned long)t;
  }
  printf("Using seed: %ld\n", seed);
  srandom(seed);

  /* Initialize the FuzzTarget object */
  target = [[FuzzTarget alloc] initWithPID: pid];
  if (nil == target) {
    fprintf(stderr, "Error initializing target\n");
    exit(1);
  }

  if(flagw && ![target printWindowGeometry])
#if PROBLEM_OUTPUT
    NSLog(@"Couldn't print target application's window geometry")
#endif
      ;

  if (namer) {
    filer = fopen(namer, "rt");
    if (filer == NULL) {
      perror(namer);
      exit(1);
    }
  }
  if (nameo) {
    fileo = fopen(nameo, "wt");
    if (fileo == NULL) {
      perror(nameo);
      exit(1);
    }
  }
}

typedef enum {
  feKeypress,
  feMouseClick,
  feMouseDoubleClick,
  feScrollWheel
} FEType;

void sendNonOverlappingEvents(int count) {
  float f_type; /* To hold random float */
  FEType type; /* The type of event to generate {key, mouse, scroll} */
  int i; /* Counter */
  BOOL status = true; /* Return status */
  /* Modifier keys */
  BOOL shift = false, ctrl = false, opt = false, cmd = false;

  /* Keypress variables */
  int keyndx; /* Index into keyCodeMap */
  CGKeyCode key; /* Which key to press */

  /* Mouse variables */
  float f_button; /* To hold random float */
  int button; /* Which button to click */
  const int NUM_BUTTONS_TO_USE = 3; /* Only use first 3 mouse buttons */
  BOOL drag; /* Is this a drag? */
  CGPoint pup, pdown; /* Positions for mouse down and up */

  /* Scroll variables */
  const int MAX_SCROLL_DELTA = 10;
  const int SCROLL_RANGE_SIZE = 2*MAX_SCROLL_DELTA + 1;
  int d1, d2, d3; /* deltas 1-3 */

  for (i = 0; i < count; i++) {
    @try {
      if(![target goToFront]) {
	/* What's the appropriate error? */
#if PROBLEM_OUTPUT
	NSLog(@"Target application couldn't be brought to foreground (event %d).",
	      i);
#else
	printf("Target application couldn't be brought to foreground.\n");
#endif
	return;
      }

      /* Decide which event type this should be */
      f_type = randf();
      if(f_type < 0.45) {
	type = feKeypress;
      } else if(f_type < 0.80) {
	type = feMouseClick; /* includes MouseMove, if dragging */
      } else if (f_type < 0.90) {
	type = feMouseDoubleClick;
      } else {
	type = feScrollWheel;
      }

      /* For each type, pick relevant parameters */
      switch(type) {
      case feKeypress:
	keyndx = randint(keyCodeMapLen);
	key    = keyCodeMap[keyndx];
	break;
	
      case feMouseClick:
	f_button = randf();
	/* 1. Pick mouse button, with preference toward lower-indexed buttons */
	button = getint(NUM_BUTTONS_TO_USE, f_button*f_button*f_button*f_button);
	/* 2. Is this a drag or just a click? */
	drag = (randf() < 0.3);
	/* 3. Pick points to click down and up */
	pdown = [target findValidPoint];
	pup   = drag ? [target randomPoint] : pdown;
	break;

      case feMouseDoubleClick:
	f_button = randf();
	button = getint(NUM_BUTTONS_TO_USE,
			f_button * f_button * f_button * f_button);
	pdown = [target findValidPointAllowingTitlebar: false];
	break;

      case feScrollWheel:
	do {
	  d1 = randint(SCROLL_RANGE_SIZE) - MAX_SCROLL_DELTA;
	  d2 = (randf() < 0.2) ? randint(SCROLL_RANGE_SIZE) - MAX_SCROLL_DELTA : 0;
	  d3 = (randf() < 0.1) ? randint(SCROLL_RANGE_SIZE) - MAX_SCROLL_DELTA : 0;
	} while(!d1 && !d2 && !d3);
	break;
      }

      /* If keypress or click, pick modifier keys */
      if(type == feKeypress || type == feMouseClick
	 || type == feMouseDoubleClick) {
	shift = (randf() < 0.1);
	ctrl  = (randf() < 0.03);
	opt   = (randf() < 0.03);
	cmd   = ((type != feKeypress ||
		  ((key != KEY_Q) && /* Cmd+Q quits */
		   (key != KEY_M) && /* Cmd+M minimizes window */
		   /*(key != KEY_P) && *//* Cmd+P prints (did we mean to block this one?) */
		   (!opt || key != ESCAPE))) && /* Cmd+Opt+Esc does force quit */
		 (randf() < 0.03));
	if(shift) {
#if EVENT_OUTPUT
	  printf("s");
#endif
	  status = (shift = [target postKeyDown: (CGKeyCode) SHIFT]) && status;
	}
	if(ctrl) {
#if EVENT_OUTPUT
	  printf("c");
#endif
	  status = (ctrl = [target postKeyDown: (CGKeyCode) CONTROL]) && status;
	}
	if(opt) {
#if EVENT_OUTPUT
	  printf("o");
#endif
	  status = (opt = [target postKeyDown: (CGKeyCode) OPTION]) && status;
	}
	if(cmd) {
#if EVENT_OUTPUT
	  printf("m");
#endif
	  status = (cmd = [target postKeyDown: (CGKeyCode) COMMAND]) && status;
	}
#if PROBLEM_OUTPUT
	if(!status) NSLog(@"Error posting modifier keys down!");
#endif
      }

      /* Now we can send the event(s) we've chosen */
      switch(type) {
      case feKeypress:
#if EVENT_OUTPUT
	printf(" %s\n", keyCodeNames[keyndx]);
#endif
	status = [target postKeyDown: key];
	status = status && [target postKeyUp: key];
#if PROBLEM_OUTPUT
	if(!status) NSLog(@"Error posting keypress!");
#endif
	break;

      case feMouseClick:
#if EVENT_OUTPUT
	printf(" %d(%.0f, %.0f)", button, pdown.x, pdown.y);
	if(drag) printf(" --> (%.0f, %.0f)\n", pup.x, pup.y);
	else     printf("\n");
#endif
	status   = [target postMouseMoveTo: pdown];
	status = status && [target postMouseButton: button downAtPoint: pdown];
	if(drag) status = status && [target postMouseMoveTo: pup];
	status = status && [target postMouseButton: button upAtPoint: pup];
#if PROBLEM_OUTPUT
	if(!status) NSLog(@"Error posting %s!", drag? "drag":"click");
#endif
	break;

      case feMouseDoubleClick:
#if EVENT_OUTPUT
	printf(" d%d(%.0f, %.0f)\n", button, pdown.x, pdown.y);
#endif
	status = [target postMouseMoveTo: pdown];
	status = status && [target postClicks: 2
				   withButton: button
				   atPoint: pdown];
#if PROBLEM_OUTPUT
	if (!status) NSLog(@"Error posting double-click!");
#endif
	break;

      case feScrollWheel:
#if EVENT_OUTPUT
	printf(" scroll(%d, %d, %d)\n", d1, d2, d3);
#endif
	status = [target postScrollWheelDelta1: d1 delta2: d2 delta3: d3];
#if PROBLEM_OUTPUT
	if(!status) NSLog(@"Error posting scroll wheel!");
#endif
	break;
      }

      /* Now bring all the modifier keys back up */
      status = true;
      if (cmd)   status = !(cmd = ![target postKeyUp: (CGKeyCode) COMMAND])
			&& status;
      if (opt)   status = !(opt = ![target postKeyUp: (CGKeyCode) OPTION])
			&& status;
      if (ctrl)  status = !(ctrl = ![target postKeyUp: (CGKeyCode) CONTROL])
			&& status;
      if (shift) status = !(shift = ![target postKeyUp: (CGKeyCode) SHIFT])
			&& status;
#if PROBLEM_OUTPUT
      if(!status) NSLog(@"Error posting modifier keys up!");
#endif
      usleep(flagd);
    } @catch (NSException *e) {
      if ([[e name] isEqualToString:@"FuzzApplicationMissingException"]) {
	printf("Target application terminated\n");
	return;
      } else {
	@throw;
      }
    }
  } /* for i in [0, count) */
} /* sendNonOverlappingEvents() */

/* Send a bunch of random valid events to the target */ 
void sendValidEvents(int numEvents) {
  float f;
  int i;
  id* events;

  events = malloc(numEvents * sizeof(*events));
  if (events == NULL) {
    return;
  }

  for (i = 0; i < numEvents; i++) {
    f = randf();
    if (f < 0.5) {
      /* Add a keypress to the bag */
      CGKeyCode key = (CGKeyCode) randint(128);
      if (i == (numEvents - 1)) {
	continue; /* Need room for two events to do a keypress */
      }
      events[i++] = [FuzzToggleEvent fuzzToggleEventWithKeyCode: key];
      events[i] = [FuzzToggleEvent fuzzToggleEventWithKeyCode: key];
    } else if (f < 0.7) {
      /* Add a mouse click to the bag */
      CGButtonCount button = (CGButtonCount) randint(32);
      if (i == (numEvents - 1)) {
	continue; /* Need room for two events to do a mouse click */
      }
      events[i++] = [FuzzToggleEvent fuzzToggleEventWithMouseButton: button];
      events[i] = [FuzzToggleEvent fuzzToggleEventWithMouseButton: button];
    } else {
      /* Add a mouse move to the bag */
      CGPoint point = [target findValidPoint];
      events[i] = [FuzzToggleEvent fuzzToggleEventWithPoint: point];
    }
  }

  @try {
    [target postToggleEventBag: [NSArray arrayWithObjects: events
					            count: numEvents]
	                 delay: flagd];
  } @catch (NSException *e) {
    if ([[e name] isEqualToString:@"FuzzApplicationMissingException"]) {
      printf("Target application terminated\n");
    } else {
      @throw;
    }
  } @finally {
    free(events);
  }
  return;
}
