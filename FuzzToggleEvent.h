/* A FuzzToggleEvent abstractly represents an atomic fuzz event to be sent to a
 * FuzzTarget.  The "Toggle" part of its name is there because some important
 * user-input events (keypresses and mouse clicks) consist of two atomic actions
 * (down and up) that must occur in order but can have other events in between
 * them.  Thus, a FTE doesn't try to capture key or button state, but expects
 * the FuzzTarget to toggle the state of the corresponding key/button.  This
 * allows the FuzzTarget to keep state information about each key and button
 * autonomously and frees its user from needing to keep such state, and (best of
 * all), a stream of FTEs sent to a FuzzTarget will represent valid user input
 * (unless the target application has closed).
 */

#include <Carbon/Carbon.h>

#import <Foundation/Foundation.h>

typedef enum {
  fteKeypress,
  fteMouseClick,
  fteMouseMove,
  fteScrollWheel
} FTEType;

@interface FuzzToggleEvent : NSObject {
  FTEType type;
  CGKeyCode myKeyCode;
  CGButtonCount myButton;
  CGPoint myPoint;
  CGWheelCount myWheelCount;
  int delta1, delta2, delta3;
}

+ (id) fuzzToggleEventWithKeyCode: (CGKeyCode) code;

+ (id) fuzzToggleEventWithMouseButton: (CGButtonCount) button;

+ (id) fuzzToggleEventWithPoint: (CGPoint) point;

+ (id) fuzzToggleEventWithScrollWheel: (CGWheelCount) wheel
			       delta1: (int) d1
			       delta2: (int) d2
			       delta3: (int) d3;

- (id) initWithType: (FTEType) inittype;
- (id) initWithKeyCode: (CGKeyCode) code;
- (id) initWithMouseButton: (CGButtonCount) button;
- (id) initWithPoint: (CGPoint) point;
- (id) initWithWheel: (CGWheelCount) wheels
		  d1: (int) d1
		  d2: (int) d2
		  d3: (int) d3;

- (FTEType) type;

- (CGKeyCode) keyCode;

- (CGButtonCount) button;

- (CGPoint) point;

- (CGWheelCount) wheelCount;

- (int) delta1;

- (int) delta2;

- (int) delta3;

@end
