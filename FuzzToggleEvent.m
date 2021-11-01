#include <Carbon/Carbon.h>

#import "FuzzToggleEvent.h"

@implementation FuzzToggleEvent

+ (id) fuzzToggleEventWithKeyCode: (CGKeyCode) code {
  id fte = [[FuzzToggleEvent alloc] initWithKeyCode: code];
  if (fte != nil) {
    [fte autorelease];
  }
  return fte;
} /* +fuzzToggleEventWithKeyCode: */

+ (id) fuzzToggleEventWithMouseButton: (CGButtonCount) button {
  id fte = [[FuzzToggleEvent alloc] initWithMouseButton: button];
  if (fte != nil) {
    [fte autorelease];
  }
  return fte;
} /* +fuzzToggleEventWithMouseButton: */

+ (id) fuzzToggleEventWithPoint: (CGPoint) point {
  id fte = [[FuzzToggleEvent alloc] initWithPoint: point];
  if (fte != nil) {
    [fte autorelease];
  }
  return fte;
} /* +fuzzToggleEventWithPoint: */

+ (id) fuzzToggleEventWithScrollWheel: (CGWheelCount) wheel
			       delta1: (int) d1
			       delta2: (int) d2
			       delta3: (int) d3 {
  id fte = [[FuzzToggleEvent alloc] initWithWheel: wheel d1: d1 d2: d2 d3: d3];
  if (fte != nil) {
    [fte autorelease];
  }
  return fte;
} /* +fuzzToggleEventWithScrollWheel:delta1:delta2:delta3: */

- (id) initWithType: (FTEType) inittype {
  self = [super init];
  if(self) {
    type = inittype;
    myKeyCode = -1;
    myButton = -1;
    myPoint.x = myPoint.y = -1;
    myWheelCount = -1;
    delta1 = delta2 = delta3 = 0;
  }
  return self;
} /* -initWithType: */

- (id) initWithKeyCode: (CGKeyCode) code {
  self = [self initWithType: fteKeypress];
  if (self != nil) {
    myKeyCode = code;
  }
  return self;
} /* -initWithKeyCode: */

- (id) initWithMouseButton: (CGButtonCount) button {
  self = [self initWithType: fteMouseClick];
  if (self != nil) {
    myButton = button;
  }
  return self;
} /* -initWithMouseButton: */

- (id) initWithPoint: (CGPoint) point {
  self = [self initWithType: fteMouseMove];
  if (self != nil) {
    myPoint = point;
  }
  return self;
} /* -initWithPoint: */

- (id) initWithWheel: (CGWheelCount) wheels
		  d1: (int) d1
		  d2: (int) d2
		  d3: (int) d3 {
  self = [self initWithType: fteMouseClick];
  if (self != nil) {
    myWheelCount = wheels;
    delta1 = d1;
    delta2 = d2;
    delta3 = d3;
  }
  return self;
} /* -initWithWheel:d1:d2:d3: */

- (FTEType) type {
  return type;
}

- (CGKeyCode) keyCode {
  return myKeyCode;
}

- (CGButtonCount) button {
  return myButton;
}

- (CGPoint) point {
  return myPoint;
}

- (CGWheelCount) wheelCount {
  return myWheelCount;
}

- (int) delta1 {
  return delta1;
}

- (int) delta2 {
  return delta2;
}

- (int) delta3 {
  return delta3;
}

@end
