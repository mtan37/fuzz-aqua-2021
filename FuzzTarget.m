/* This is the implementation file for the FuzzTarget class */

/* I want some utility functions from here */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <Cocoa/Cocoa.h>

/* Import the header for this class.  It's where the other header
 * includes/imports are defined, and it declares the instance variables and
 * prototypes all the methods for the class, much like a regular C/C++ header.
 */
#import "FuzzTarget.h"

/* Our utility functions can be found here */
#include "util.h"

/* Turn this on to have FuzzTarget complain about problems with sending events
 * and checking points.
 */
#define PROBLEM_OUTPUT 0

/* @implementation keyword tells the compiler that the class definition for
 * FuzzTarget begins here
 */
@implementation FuzzTarget

/* First method we have is the initializer for the class.  It's a lot like
 * a constructor.  The alloc method allocates memory for the class, then
 * initWithPID: is called on the new object to finish the constructor activity.
 */
- (FuzzTarget *) initWithPID: (pid_t) target_pid
		     screenX: (int) xSize
		     screenY: (int) ySize {
  OSStatus status;
  AXUIElementRef targetAXUI;
  int i;

  /* First thing you do in an initializer is call the initializer for the
   * parent class.  We replace the self pointer with the return value, because
   * an initializer may return a different object than was originally allocated.
   */
  self = [super init];
  if (nil == self) {
    /* An initializer may return nil (null object) if there's an error. */
    return self;
  }

  /* Initialize our arrays of mouse-button and key states.  Greg doesn't like
   * doing array initializations this way, so Fred is responsible for
   * maintaining this code.
   */
  for (i = 0; i < MAX_MOUSE_BUTTONS; i++) {
    buttonStates[i] = false;
  }
  for (i = 0; i < MAX_KEYS; i++) {
    keyStates[i] = false;
  }
  numButtonsDown = numKeysDown = 0;

  /* Initialize all these guys to invalid values. */
  winX = winY = width = height = -1;

  pid = target_pid;

  status = GetProcessForPID(pid, &psn);
  if (status != noErr) {
    /* The autorelease method tells the runtime system that this object can
     * be released (its memory freed) when the runtime gets around to it.
     * I don't need the pointer in self anymore at this point, but I don't think
     * it's safe to release self.
     */
    NSLog(@"FuzzTarget -init..: Can't get PSN for this PID");
    [self autorelease]; /* Is this safe?  I think so.. */
    return nil;
  } else {
    source = CGEventSourceCreate(kCGEventSourceStatePrivate);
    if (NULL == source) {
      [self autorelease]; /* Is this safe?  I think so.. */
      return nil;
    }
  }
  targetAXUI = AXUIElementCreateApplication(pid);
  status = AXUIElementCopyAttributeValue(targetAXUI, kAXTitleAttribute,
					 (CFTypeRef *) &processName);
  if (status != noErr) {
    NSLog(@"FuzzTarget -init..: AXUI name error, trying ProcMan");
    status = CopyProcessName(&psn, (CFStringRef *) &processName);
    if (status != noErr) {
      NSLog(@"FuzzTarget -init..: Couldn't get process name of target");
      processName = nil;
    }
  }

  maxX = xSize;
  maxY = ySize;
  for (i = 0; i < MAX_MOUSE_BUTTONS; i++) {
    buttonStates[i] = false; /* start with all buttons up */
  }

  /* May as well start at (0,0) */
  currentMousePosition.x = 0.0;
  currentMousePosition.y = 0.0;

  /* Don't want my mouse events getting confused with the system's */
  CGEnableEventStateCombining(false);

  return self;
}

/* Determine the size of the main display & intialize based on that */
- (FuzzTarget *) initWithPID: (pid_t) target_pid {
  return [self initWithPID: target_pid
	       screenX: CGDisplayPixelsWide(CGMainDisplayID())
	       screenY: CGDisplayPixelsHigh(CGMainDisplayID())];
}

/* The dealloc method gets called when an object is released, so you can do
 * cleanup.  It corresponds to a destructor method.
 */
- (void) dealloc {
  /* Core Foundation types use a similar memory management model to Objective-C
   * objects, so we call CFRelease on them to free up the memory they use.
   */
  if (source != NULL) {
    CFRelease(source);
  }
  if (processName != nil) {
    [processName release];
  }
  /* Then call the superclass's dealloc method to do any other cleanup that
   * needs to get done.
   */
  [super dealloc];
}

- (ProcessSerialNumber) psn {
  return psn;
}

- (BOOL) goToFront {
  OSErr status;
  status = SetFrontProcess(&psn);
  if (procNotFound == status) {
    NSException *e = 
        [NSException exceptionWithName: @"FuzzApplicationMissingException"
		                reason: @"Application not found"
		              userInfo: nil];
    @throw e;
  }
  return (errorCode = (int) status) == noErr;
} /* -goToFront */

- (BOOL) isPointInTarget: (CGPoint) point {
  return [self isPointInTarget: point allowingTitlebar: true];
} /* -isPointInTarget: */

- (BOOL) isPointInTarget: (CGPoint) point allowingTitlebar: (BOOL) allowed {
  AXError axStatus;
  AXUIElementRef atPoint = NULL;
  pid_t pidAtPoint;
  BOOL status;
  CFTypeRef attr;

  if ((point.x < 45) && (point.y < 22)) {
    return false; /* Don't click on the Apple menu */
  }

  axStatus = AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(),
					      point.x, point.y,
					      &atPoint);
  if (axStatus != kAXErrorSuccess) {
    /* Something bad happened.. */
    errorCode = (int) axStatus;
#if PROBLEM_OUTPUT
    NSLog(@"FuzzTarget -isPointInTarget: couldn't find AX object (%d)",
	  (int) axStatus);
#endif
    return false;
  }
  /* I don't want to click on a minimize button either. */
  if (AXUIElementCopyAttributeValue(atPoint, kAXSubroleAttribute,
				    &attr) == kAXErrorSuccess) {
    if (CFStringCompare((CFStringRef) attr, kAXMinimizeButtonSubrole, 0)
	== kCFCompareEqualTo) {
      CFRelease(attr);
      return false;
    } 
    CFRelease(attr);
  }
  if (!allowed) { /* Don't want to click on the titlebar */
    axStatus = AXUIElementCopyAttributeValue(atPoint, kAXRoleAttribute, &attr);
    if (axStatus == kAXErrorSuccess) {
      if (CFStringCompare((CFStringRef) attr, kAXWindowRole, 0)
	  == kCFCompareEqualTo) {
	CFRelease(attr);
	axStatus = AXUIElementCopyAttributeValue(atPoint, kAXPositionAttribute,
						 &attr);
	if (axStatus == kAXErrorSuccess) {
	  CGPoint position;
	  if (AXValueGetValue(attr, kAXValueCGPointType, &position)) {
	    if (point.y < (position.y + 22.0)) {
#if 0
	      printf("Point (%.0f, %.0f) in titlebar (%.0f, %.0f)\n",
		     point.x, point.y, position.x, position.y);
#endif
	      return false; /* in the titlebar */
	    }
	  }
	  CFRelease(attr);
	}
      } else { /* Not a window AXUIElement */
	CFRelease(attr);
      }
    }
  }
  axStatus = AXUIElementGetPid(atPoint, &pidAtPoint);
  if (axStatus != kAXErrorSuccess) {
    errorCode = (int) axStatus;
    if (atPoint != NULL) {
      CFRelease(atPoint);
      atPoint = NULL;
    }
#if PROBLEM_OUTPUT
    NSLog(@"Couldn't get PID for AXUIElement at point (%d)", (int) axStatus);
#endif
    return false;
  }
  if (pidAtPoint == pid) {
    /* It's in the right application, so clean up after ourselves and send
     * the event
     */
    if (atPoint != NULL) {
      CFRelease(atPoint);
      atPoint = NULL;
    }
    return true;
  } else {
    /* Still need to check if the element belongs to the target application */
    /* I need to climb up the AXUIElement tree from atPoint until I reach
     * the element with the application role, then get its title and compare
     * to processName
     */
    AXUIElementRef parent = NULL, child = NULL;
    BOOL found = false; /* application found? */
    NSString *parentTitle = nil;
    NSString *role = nil;
    int consecutive_errors = 0;

    axStatus = AXUIElementCopyAttributeValue(atPoint, kAXParentAttribute,
					     (CFTypeRef *) &parent);
    if (axStatus != kAXErrorSuccess) {
      errorCode = (int) axStatus;
#if PROBLEM_OUTPUT
      NSLog(@"FuzzTarget -isPointInTarget: Error climbing tree: %d", axStatus);
#endif
      if (atPoint != NULL) {
	CFRelease(atPoint);
      }
      return false;
    }
    while (false == found) {
      axStatus = AXUIElementCopyAttributeValue(parent, kAXRoleAttribute,
					       (CFTypeRef *) &role);
      if (axStatus != kAXErrorSuccess) {
	/* FIXME: Anything else I need to do here? */
	errorCode = (int) axStatus;
#if PROBLEM_OUTPUT
	NSLog(@"FuzzTarget -isPointInTarget: Error climbing tree: %d",
	      (int) axStatus);
#endif
	consecutive_errors++;
      } else consecutive_errors = 0;
      if ((role != nil)
	  && [role isEqualToString: (NSString *) kAXApplicationRole]) {
	found = true;
	axStatus = AXUIElementCopyAttributeValue(parent, kAXTitleAttribute,
						 (CFTypeRef *) &parentTitle);
	if (axStatus != kAXErrorSuccess) {
	  /* FIXME: Anything else I need to do here? */
	  errorCode = (int) axStatus;
#if PROBLEM_OUTPUT
	  NSLog(@"FuzzTarget -isPointInTarget: Error climbing tree: %d",
		(int) axStatus);
#endif
	  consecutive_errors++;
	} else consecutive_errors = 0;
	if (parent != NULL) {
	  CFRelease(parent);
	  parent = NULL;
	}
	if (child != NULL) {
	  CFRelease(child);
	  child = NULL;
	}
	if (role != nil) {
	  [role release];
	  role = nil;
	}
      } else {
	if (child != NULL) {
	  CFRelease(child);
	}
	if (role != nil) {
	  [role release];
	  role = nil;
	}
	child = parent;
	axStatus = AXUIElementCopyAttributeValue(child, kAXParentAttribute,
						 (CFTypeRef *) &parent);
	if (axStatus != kAXErrorSuccess) {
	  /* FIXME: Anything else I need to do here? */
	  errorCode = (int) axStatus;
#if PROBLEM_OUTPUT
	  NSLog(@"FuzzTarget -isPointInTarget: Error climbing tree: %d",
		(int) axStatus);
#endif
	  consecutive_errors++;
	} else consecutive_errors = 0;
      }
      if(consecutive_errors >= 30) {
	printf("%d consecutive errors in while loop!\n", consecutive_errors);
	return false;
      }
    }
    /* Now I've found the application object, and have its name in parentTitle.
     * So it's time to check whether it matches processName.  If so, return
     * true, otherwise, return false
     */
    status = [parentTitle isEqualToString: processName];
    /* clean up */
    [parentTitle release];
    if (atPoint) CFRelease(atPoint);

    return status;
  }
} /* end -isPointInTarget:allowingTitlebar: */

- (CGPoint) randomPoint {
  CGPoint point;
  point.x = (float) randint(maxX);
  point.y = (float) randint(maxY);
  return point;
}

- (CGPoint) findValidPoint {
  return [self findValidPointAllowingTitlebar: true];
} /* -findValidPoint */

- (CGPoint) findValidPointAllowingTitlebar: (BOOL) allowed {
  CGPoint point;

  do {
    point.x = (float) randint(maxX);
    point.y = (float) randint(maxY);
  } while (![self isPointInTarget: point allowingTitlebar: allowed]);
  return point;
} /* -findValidPointAllowingTitlebar */

- (int) keysDown {
  return numKeysDown;
} /* -keysDown */

- (BOOL) postKeyEvent: (CGKeyCode) code
		state: (BOOL) state {
//   CGEventRef ev;

  if (![self goToFront]) {
    NSLog(@"Unable to foreground process (%d)\n", errorCode);
    return false;
  }
  return [self postKey: code state: state];
  /*
  ev = CGEventCreateKeyboardEvent(source, code, state);
  if(ev) {
    CGEventPostToPSN(&psn, ev);
    CFRelease(ev);
  }
  return true;
  */
}

- (BOOL) postKeyDown: (CGKeyCode) code {
  return [self postKeyEvent: code state: true];
}

- (BOOL) postKeyUp: (CGKeyCode) code {
  return [self postKeyEvent: code state: false];
}

- (BOOL) postKeyBag: (NSArray *) bag {
  NSMutableArray *unused;
  NSMutableArray *keystate;
  int i;
  
  unused = [NSMutableArray arrayWithArray: bag];
  if (nil == unused) {
    errorCode = 0; /* Don't know what to use for out of memory */
    return false;
  }
  keystate = [NSMutableArray arrayWithCapacity: [unused count]];
  if (nil == keystate) {
    errorCode = 0; /* Don't know what to use for out of memory */
    return false;
  }

  for (i = 0; i < [unused count]; i++) {
    [keystate addObject: [NSNumber numberWithBool: false]];
  }

  while ([unused count] > 0) {
    i = randint([unused count]);
    if (![[keystate objectAtIndex: i] boolValue]) {
      [self postKeyDown: (CGKeyCode) [[unused objectAtIndex: i] intValue]];
      [keystate replaceObjectAtIndex: i
		          withObject: [NSNumber numberWithBool: true]];
    } else {
      [self postKeyUp: (CGKeyCode) [[unused objectAtIndex: i] intValue]];
      [unused removeObjectAtIndex: i];
      [keystate removeObjectAtIndex: i];
    }
    usleep(1); /* Don't send the events too quickly */
  }
    
  return true;
} /* -postKeyBag: */

- (int) buttonsDown {
  return numButtonsDown;
} /* -buttonsDown */

/* 
 * passed in button value are expected to be either 0, 1 or 2. 
 * 1 - left mouse button
 * 2 - right mouse button
 * 3 - middle mouse button
 * Handles all updating of buttonStates and numButtonsDown.
 */
- (BOOL) postMouseButton: (int) button
		   state: (BOOL) state
		 atPoint: (CGPoint) point {
  BOOL prevstate = buttonStates[button];
  if(prevstate == state) {
    /* stupid-sounding error message */
    NSLog(@"Requested button state (%d %s) already holds.",
	  button, state?"down":"up");
    return true;
  }

  // check if the button given is valid
  if ((button < 0) || (button >= 3)) {
    errorCode = 0; /* Don't know what to use for invalid argument */
    return false;
  }

  // compute CGEventType for the mouse event
  CGEventType mouseType = kCGEventNull;
  CGMouseButton mouseButton = kCGMouseButtonLeft;

  if (button == 0) {// left mouse key
    mouseButton = kCGMouseButtonLeft;

    if (state) mouseType = kCGEventLeftMouseDown;
    else mouseType = kCGEventLeftMouseUp;

  } else if (button == 1) { // right mouse key
    mouseButton = kCGMouseButtonRight;

    if (state) mouseType = kCGEventRightMouseDown;
    else mouseType = kCGEventRightMouseUp;

  } else { // middle mouse key
    mouseButton = kCGMouseButtonCenter;

    if (state) mouseType = kCGEventOtherMouseDown;
    else mouseType = kCGEventOtherMouseUp;
  }

  /* Assume that the point has already been checked and is within the target
   * application.
   */
  /* Assume that the target application has already been made the foreground
   * process.
   */
  CGEventRef mouseEvent = CGEventCreateMouseEvent(NULL, mouseType, point, mouseButton);
  CGEventPost((CGEventTapLocation)kCGHIDEventTap, mouseEvent);
  buttonStates[button] = state;
  CFRelease(mouseEvent);// release the event

  // TODO how to check event status using this????
  // assume successful for now 
  numButtonsDown += state ? 1 : -1;
  return true;
}

/* Handles all updating of keyStates and numKeysDown. */
- (BOOL) postKey: (CGKeyCode) code
           state: (BOOL) state {
  if(keyStates[code] == state) {
    NSLog(@"Requested key state (%d %s) already holds.",
	  code, state?"down":"up");
    return true;
  }
  CGEventRef ev = CGEventCreateKeyboardEvent(source, code, state);
  if(ev) {
    CGEventPostToPSN(&psn, ev); /* void function */
    CFRelease(ev);
    numKeysDown += state ? 1 : -1;
    keyStates[code] = state;
    return true;
  } else {
    NSLog(@"Couldn't create CGEvent for key %d (%s)", code, state?"down":"up");
  }
  return false;
}

- (BOOL) postMouseButton: (int) button downAtPoint: (CGPoint) point {
  return [self postMouseButton: button state: true atPoint: point];
}

- (BOOL) postMouseButton: (int) button upAtPoint: (CGPoint) point {
  return [self postMouseButton: button state: false atPoint: point];
}

- (BOOL) postRandomMouseClick {
  CGPoint point = [self findValidPoint];
  /* point.x >= 0 */
//   if(point.x < 0) return false;
  return [self postClickAtPoint: point];
} /* end postRandomMouseClick */

- (BOOL) postClicks: (int) count
	 withButton: (int) button
	    atPoint: (CGPoint) point {
  int i;

  /* sanity checking */
  if (count < 1) {
    return false;
  }

  if ([self goToFront] == false) {
    NSLog(@"FuzzTarget -postClicks..: Unable to foreground process (%d)",
	  errorCode);
    return false;
  }

  /* Check window bounds */
  if (![self isPointInTarget: point]) {
    return false;
  }

  for (i = 0; i < count; i++) {
    if (![self postMouseButton: button downAtPoint: point] ||
	![self postMouseButton: button upAtPoint: point])
      return false;
  } /* end for loop */

  return true;
} /* end -postClicks:withButton:atPoint: */

- (BOOL) postClickAtPoint: (CGPoint) point {
  return [self postClicks: 1 withButton: kCGMouseButtonLeft atPoint: point];
}

- (BOOL) postDoubleClickAtPoint: (CGPoint) point {
  return [self postClicks: 2 withButton: kCGMouseButtonLeft atPoint: point];
}

- (BOOL) postRightClickAtPoint: (CGPoint) point {
  return [self postClicks: 1 withButton: kCGMouseButtonRight atPoint: point];
}

- (BOOL) postMouseMoveTo: (CGPoint) point isDragged: (BOOL) isDragged {
  // compute CGEventType for the mouse event
  CGEventType mouseType = kCGEventNull;

  if (isDragged && buttonStates[0]) mouseType = kCGEventLeftMouseDragged;
  else if (isDragged && buttonStates[1]) mouseType = kCGEventRightMouseDragged;
  else mouseType = kCGEventMouseMoved;

  /* Assume that the point has already been checked and is within the target
   * application.
   */
  /* Assume that the target application has already been made the foreground
   * process.
   */
  CGEventRef mouseEvent = CGEventCreateMouseEvent(
            NULL, mouseType, point, (CGMouseButton) kCGMouseButtonLeft);
  CGEventPost((CGEventTapLocation)kCGHIDEventTap, mouseEvent);
  CFRelease(mouseEvent);// release the event

  // TODO how to check event status using this????
  // assume successful for now 
  currentMousePosition = point;
  return true;
} /* -postMouseMoveTo: */

- (BOOL) postScrollWheelDelta1: (int) delta1
			delta2: (int) delta2
			delta3: (int) delta3 {
  CGError cg_status;
  
  cg_status = CGPostScrollWheelEvent((CGWheelCount) 3, delta1, delta2,
				     delta3);
  if (cg_status != kCGErrorSuccess) {
    errorCode = (int) cg_status;
    NSLog(@"Error posting scroll wheel event (%d)\n", (int) cg_status);
    return false;
  }
  return true;
} /* -postScrollWheelDelta1:delta2:delta3: */

- (BOOL) postScrollWheel1Delta: (int) delta {
  return [self postScrollWheelDelta1: delta delta2: 0 delta3: 0];
} /* -postScrollWheel1Delta: */

- (BOOL) postToggleEvent: (FuzzToggleEvent *) event {
  int button;
  BOOL state;

  if(![self goToFront]) return false;
  switch([event type]) {
  case fteKeypress:
    return [self postKey: [event keyCode] state: keyStates[[event keyCode]]];
  case fteMouseClick:
    button = [event button];
    state = buttonStates[button];
    if(!state && ![self isPointInTarget: currentMousePosition])
      currentMousePosition = [self findValidPoint];
    return [self postMouseButton: button
		 state: !state
		 atPoint: currentMousePosition];
  case fteMouseMove:
    return [self postMouseMoveTo: [event point] isDragged: false];
  case fteScrollWheel:
    return [self postScrollWheelDelta1: [event delta1]
		                delta2: [event delta2]
		                delta3: [event delta3]];
  }
  return true;
}

- (BOOL) postToggleEventBag: (NSArray *) bag
		      delay: (int) delay {
  NSMutableArray *unused;
  int i;
  BOOL status;

  unused = [NSMutableArray arrayWithArray: bag];
  if (nil == unused) {
    errorCode = 0;
    return false;
  }

  while ([unused count] > 0) {
    i = randint([unused count]);
    status = [self postToggleEvent: [unused objectAtIndex: i]];
    if (status == false) {
      return false;
    }
    [unused removeObjectAtIndex: i];
    usleep(delay);
  }

  return true;
} /* -postToggleEventBag: */

- (BOOL) postAllUpDelay: (int) delay {
  int i = 0, j = 0;
  int numEvents = numKeysDown + numButtonsDown; /* Is this right? */
  id events[numEvents];
  for(i = MAX_KEYS; --i;)
    /* If this key is down, add a toggle event for it to the array. */
    if(keyStates[i])
      events[j++] = [FuzzToggleEvent fuzzToggleEventWithKeyCode: (CGKeyCode)i];

  for(i = MAX_MOUSE_BUTTONS; --i;)
    /* If this key is down, add a toggle event for it to the array. */
    if(buttonStates[i])
      events[j++] = [FuzzToggleEvent fuzzToggleEventWithMouseButton: (CGButtonCount)i];

  if(j != numEvents)
    fprintf(stderr, "Something is very wrong with my arithmetic! j = %d; keys = %d; buttons = %d\n", j, numKeysDown, numButtonsDown);

  [self postToggleEventBag: [NSArray arrayWithObjects: events
				     count: numEvents]
	delay: delay];

  return true;
}

/* Determine the location and dimensions of the target window (without
 * the title bar), starting from an initial guess point.  If the guess
 * is wrong, poke around randomly until we hit the window.  Use binary
 * search to get from the guess point to each edge.
 */
- (BOOL) printWindowGeometry {
  const int MBAR_HEIGHT = 22/*, TBAR_HEIGHT = 18*/;
  int x1, y1, x2, y2; /* known "good" points */
  int w1, z1, w2, z2; /* known "bad" points */
  CGPoint guess; /* initial starting point of exploration */
  /* obviously bogus init values */
  w1 = x1 = y1 = z1 = -1;
  w2 = x2 = maxX + 1;
  y2 = z2 = maxY + 1;

  /* Try to kick it to the foreground */
  if([self goToFront] == false) {
    NSLog(@"Unable to foreground application\n");
    return false;
  }
  /* LOCATE BOTTOM OF MENU BAR
  CGPoint p; p.x = 195; p.y = 0;
  for(; [self isPointInTarget: p]; p.y++) {
    printf("y value %lf is in the menu bar.\n", p.y);
  }
  */

  /* If guess misses, give up */
  /*if(![self isPointInTarget: guess]) { NSLog(@"Initial guess (%lf, %lf) did not hit window\n", guess.x, guess.y); return false; }*/

  /* If guess misses, start guessing randomly.  This phase is kind of like
   * taking the ACT (the SAT and GRE penalize more for wrong answers than for
   * unanswered questions).
   */
  do {
    guess.x = ((float) random() / (float) INT32_MAX) * maxX;
    guess.y = MBAR_HEIGHT +
      ((float) random() / (float) INT32_MAX) * (maxY-MBAR_HEIGHT);
  } while(![self isPointInTarget: guess]);

  /* Update known good points */
  x1 = x2 = guess.x;
  y1 = y2 = guess.y;

  /* Find left edge */
  for(guess.x = 0; x1 > 0 && x1 - w1 > 1; guess.x = w1 + (x1 - w1)/2)
    if([self isPointInTarget: guess]) x1 = guess.x;
    else w1 = guess.x;

  /* sanity check */
  guess.x = x1;
  if(x1 < 0 || x1 <= w1 || ![self isPointInTarget: guess]) {
    NSLog(@"Found left edge of window at %d but non-window point at %d\n",
	  x1, w1);
    return false;
  }

  /* Find right edge */
  for(guess.x = maxX-1; x2 < maxX-1 && w2 - x2 > 1; guess.x = x2 + (w2 - x2)/2)
    if([self isPointInTarget: guess]) x2 = guess.x;
    else w2 = guess.x;

  /* sanity check */
  guess.x = x2;
  if(x2 >= maxX || w2 <= x2 || ![self isPointInTarget: guess]) {
    NSLog(@"Found right edge of window at %d but non-window point at %d\n",
	  x2, w2);
    return false;
  }

  /* Find top edge */
  guess.x = x1 + (x2 - x1)/2; /* make our x guesses be in the middle */
  /* Something stupid appears to happen when checking points in the title bar,
   * so to find y1, we'll just do a linear search from the bottom of the menu
   * bar.
   */
  for(guess.y = MBAR_HEIGHT; ![self isPointInTarget: guess]; guess.y++);
  y1 = guess.y;

  /* Brain-dead but effective way to figure out value for TBAR_HEIGHT */
  /*for(; guess.y++ < y1 + 30;) { printf("Checking y=%d: %s\n", (int)(guess.y-y1), [self isPointInTarget: guess] ? "yes" : "no"); }*/

  /* Note that we need to make sure we aren't trying to click the menu bar */
  /*for(guess.y = MBAR_HEIGHT; y1 > MBAR_HEIGHT && y1 - z1 > 1; guess.y = z1 + (y1 - z1)/2) { printf("y1 = %d; z1 = %d; guess.y = %.1lf\n", y1, z1, guess.y); if([self isPointInTarget: guess]) y1 = guess.y; else z1 = guess.y; } */

  /* sanity check */
  /*guess.y = y1; if(y1 < MBAR_HEIGHT || y1 <= z1 || ![self isPointInTarget: guess]) { NSLog(@"Found top edge of window at %d but non-window point at %d\n", y1, z1); return false; }*/

  /* Find bottom edge */
  for(guess.y = maxY-1; y2 < maxY-1 && z2 - y2 > 1; guess.y = y2 + (z2 - y2)/2)
    if([self isPointInTarget: guess]) y2 = guess.y;
    else z2 = guess.y;

  /* sanity check */
  guess.y = y2;
  if(y2 >= maxX || z2 <= y2 || ![self isPointInTarget: guess]) {
    NSLog(@"Found bottom edge of window at %d but non-window point at %d\n",
	  y2, z2);
    return false;
  }

  /* Set all the relevant member variables */
  winX = x1;
  winY = y1;
  width = x2 - x1 + 1;
  height = y2 - y1 + 1;
  /* Note that winX + width or winY + height will actually put you one pixel
   * outside the window, but if r is chosen randomly from [0, 1),
   *   winX + r*width
   * and
   *   winY + r*height
   * should always give you values inside the window.
   */

  /* Print out the results */
  printf("Window located at (%d, %d) with dimensions %d x %d\n", winX, winY, width, height);

  return true;
} /* -exploreTargetGeometry: */

/* @end signals the end of this class */
@end
