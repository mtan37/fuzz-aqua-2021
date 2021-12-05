/* This file defines the interface to the FuzzTarget class. */

/* Objective-C programs can use normal C header files and functions */
#include <Cocoa/Cocoa.h>

/* They also use Objective-C headers, with the #import statement.  I'm not sure
 * what all the differences are between #include and #import, but for one thing,
 * #import will only include the file once in the compile so I don't need to
 * bracket the whole thing with #ifndef FUZZ_TARGET_H or whatever.
 *
 * The Foundation framework declares all kinds of useful stuff for Objective-C.
 * It's where the definition of NSObject is.  All Objective-C programs will need
 * to use the Foundation framework as far as I can tell.  Think of it as the
 * equivalent of Java.lang.
 */
#import <Foundation/Foundation.h>
/* FuzzToggleEvent represents an atomic user-input event.  See FuzzToggleEvent.h
 * for a more pedantic explanation.
 */
#import "FuzzToggleEvent.h"

/* Apparently enums are the proper way to declare constants */
enum _FuzzTargetConstants {
  MAX_MOUSE_BUTTONS = 3,
  MAX_KEYS = 128
};

/* The @interface keyword tells the compiler that it's about to see the
 * declaration of a class.
 */ 
@interface FuzzTarget : NSObject {
  /* All my instance variables go within the braces here.  I don't
   * remember how to declare their access type (public/private, etc.).
   * I also don't remember how to declare class variables (like static
   * in Java).  We should be okay without those features, but I'm sure
   * we can look them up if we need them.
   */
  pid_t pid;
  ProcessSerialNumber psn;
  /* The name of the application, as provided by the Process Manager */
  NSString* processName;
  CGEventSourceRef source;
  int maxX; /* Maximum x-coordinate for mouse events */
  int maxY; /* Maximum y-coordinate for mouse events */
  /* Minimum x and y are assumed to be 0.  This will only work for one
     display.
   */

  /*
   * Window position and dimensions: initialize to -1 so we know
   * whether we've found out the window geometry.  I'm going to use
   * x,y,width,height semantics, unless I decide x1,x2,y1,y2 semantics
   * turn out to be easier.  That is, the upper-left corner of the
   * window should be at (winX, winY), and the window should have
   * dimensions (width, height).
   */
  int winX, winY, width, height;

  /* Keeps track of what mouse button states we're simulating */
  BOOL buttonStates[MAX_MOUSE_BUTTONS];
  int numButtonsDown;

  /* Keeps track of which keys are depressed */
  BOOL keyStates[MAX_KEYS];
  int numKeysDown;

  /* More state: we'll maintain a mouse position state, and use it to try to
   * make mouse movement, etc. events that make sense.
   *   typedef struct { double x, double y } CGPoint
   * I think (as determined by Fred).
   */
  CGPoint currentMousePosition;

  /* Stores an error code from various system calls.  Check it if one of the
   * methods that returns false on error returns false.
   */
  int errorCode;
}

/* Instance methods are declared like so:
 * - (returnType) nameAndFirstParameter: (parameterType) param;
 * Methods with more than one parameter are defined like so:
 * - (type) nameAndFirst: (type) param second: (type) param third: (type) param;
 * etc.  If you want to declare a class method (like Java's static) then you
 * just replace the - with a +
 */
/* By default we'll push our target application to the foreground before sending
 * it an event
 */
- (FuzzTarget *) initWithPID: (pid_t) target_pid;

/* Initialize the target with the bounds of your display.  Doesn't support
 * multiple displays yet.
 */
- (FuzzTarget *) initWithPID: (pid_t) target_pid
		     screenX: (int) xSize
		     screenY: (int) ySize;

- (void) dealloc;

- (ProcessSerialNumber) psn;

/* Makes the target the foreground process.
 * Returns true on success, false on error.
 * Throws FuzzApplicationMissingException if the system cannot find the target
 * application.
 */
- (BOOL) goToFront;

/* Checks whether a point is within the bounds of the target application */
- (BOOL) isPointInTarget: (CGPoint) point;

/* Checks whether a point is within the bounds of the target application,
 * possibly disallowing the titlebar.
 */
- (BOOL) isPointInTarget: (CGPoint) point allowingTitlebar: (BOOL) allowed;

/* Generate a random point inside the application */
- (CGPoint) findValidPoint;

/* Generate a random point inside the application, possibly disallowing the
 * titlebar for a window.
 */
- (CGPoint) findValidPointAllowingTitlebar: (BOOL) allowed;

/* Generate a random point somewhere on the screen */
- (CGPoint) randomPoint;

/* Return the number of keys that are currently down. */
- (int) keysDown;

/* Post the occurrence of key <code> changing to <state> ? down : up.
 * Suppress the event if that key already has that state (may need to
 * modify this to provide highly invalid input. Handles all updating
 * of keyStates and numKeysDown.
 */
- (BOOL) postKey: (CGKeyCode) code
	   state: (BOOL) state;

/* As postKey: state:, but brings application to front first.
 */
- (BOOL) postKeyEvent: (CGKeyCode) code
		state: (BOOL) state;

/* Convenience wrappers to postKeyEvent: state:
 */
- (BOOL) postKeyDown: (CGKeyCode) code;
- (BOOL) postKeyUp: (CGKeyCode) code;

/* Simulates key mashing: posts a bunch of keypresses in random order with
 * random overlap.
 * Parameter is an NSArray.  They can be created from a normal array of ids by
 * using the +arrayWithObjects:count: method of NSArray.  The array passed in
 * should be an array of NSNumbers representing the keycodes to send.  Create
 * those NSNumbers with the +numberWithInt: method of NSNumber.  Returns true on
 * success, false on error.
 */
- (BOOL) postKeyBag: (NSArray *) bag;

/* Return the number of buttons that are currently down. */
- (int) buttonsDown;

/* Mouse button down and up primitive.
 * They post a mouse event to the system with the current simulated mouse
 * button state as specified in buttonStates, plus whatever modification is
 * made by pressing or releasing the specified button.  And the event is
 * sent at the specified point.
 * state == true -> mouse down
 * state == false -> mouse up
 * Return true on success, false on failure.
 */
- (BOOL) postMouseButton: (int) button
		   state: (BOOL) state
		 atPoint: (CGPoint) point;

/* Convenience methods for mouse down and up */
- (BOOL) postMouseButton: (int) button downAtPoint: (CGPoint) point;
- (BOOL) postMouseButton: (int) button upAtPoint: (CGPoint) point;

/* Posts a random mouse click (primary button) to the application */
- (BOOL) postRandomMouseClick;

/* It appears we don't use this method any more */
// - (BOOL) postMouseToggleButton: (int) button;

/* Posts the specified number of clicks with the specified button to the
 * target application at the specified position, abiding by the
 * constrainMouseEvents flag.  Returns true if successful, false if
 * unsuccessful.
 * button parameter: 0 - primary button (left)
 *                   1 - secondary button (right)
 *                   2 - middle button/scroll wheel
 *                   + - other button (max 31)
 */
- (BOOL) postClicks: (int) count
	 withButton: (int) button
	    atPoint: (CGPoint) point;

/* Posts a single left click at the specified point as long as the point is
 * within the bounds of the application.  Returns true on success, false on
 * failure.
 */
- (BOOL) postClickAtPoint: (CGPoint) point;

/* Posts a double left click at the specified point, as long as it's within
 * the bounds of the target.  Returns true on success, false on failure.
 */
- (BOOL) postDoubleClickAtPoint: (CGPoint) point;

/* Posts a mouse move to the specified point.
 * Returns true on success, false on failure.
 */
- (BOOL) postMouseMoveTo: (CGPoint) point isDragged: (BOOL) isDragged;

/* Posts a single right click at the specified point, as long as it's within
 * the bounds of the target.  Returns true on success, false on failure.
 */
- (BOOL) postRightClickAtPoint: (CGPoint) point;

/* Posts a scroll wheel event to the system */
- (BOOL) postScrollWheelDelta1: (int) delta1
			delta2: (int) delta2
			delta3: (int) delta3;

/* Convenience method for first scroll wheel */
- (BOOL) postScrollWheel1Delta: (int) delta;

/* Post event from FTE */
- (BOOL) postToggleEvent: (FuzzToggleEvent *) event;

/* Post a lot of FTEs in random order with delay (useconds) between each pair
 * of primitive events
 */
- (BOOL) postToggleEventBag: (NSArray *) bag delay: (int) delay;

/* Release all currently-down buttons and keys in random order, separating each
 * release with a delay of <delay> microseconds.
 */
- (BOOL) postAllUpDelay: (int) delay;

/* Print the location and dimensions of the target window. Poke around randomly
 * to find a starting point in the window.  Use binary search to get from guess
 * point to each edge.  Note that this will do any good only when the
 * application being tested has a single, rectangular window.
 */
- (BOOL) printWindowGeometry;

/* The @end keyword tells the compiler that we're done with this class */
@end
