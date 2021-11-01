/* Experimental testing program for fuzz-osx.  Can I send events to another
 * program?  And how do I want to identify the program I'm sending events
 * to?
 */
/* First, I'll just try to connect to a process and read the keyboard input
 * events that it receives.
 */

#include <Carbon/Carbon.h>

#include <stdio.h>
#include <stdlib.h>

/* Globals.  Learn how to code, Greg. */
CFMachPortRef tap_port; /* Mach port object for the event tap I'm installing
                         * in the target */
#define KEYCODE_LIST_LENGTH 128
char *keycodeList[KEYCODE_LIST_LENGTH];

/* Unnecessary function prototypes */
CGEventRef tapCallback(CGEventTapProxy proxy, CGEventType type,
                       CGEventRef event, void *refcon);
void populateKeycodeList();
 
/* Puts strings describing the keycodes in the keycodeList array */ 
void populateKeycodeList() {
  bzero(keycodeList, sizeof(keycodeList));

  keycodeList[0] = "A";
  keycodeList[1] = "S";
  keycodeList[2] = "D";
  keycodeList[3] = "F";
  keycodeList[4] = "H";
  keycodeList[5] = "G";
  keycodeList[6] = "Z";
  keycodeList[7] = "X";
  keycodeList[8] = "C";
  keycodeList[9] = "V";
  keycodeList[10] = "Unknown";
  keycodeList[11] = "B";
  keycodeList[12] = "Q";
  keycodeList[13] = "W";
  keycodeList[14] = "E";
  keycodeList[15] = "R";
  keycodeList[16] = "Y";
  keycodeList[17] = "T";
  keycodeList[18] = "1";
  keycodeList[19] = "2";
  keycodeList[20] = "3";
  keycodeList[21] = "4";
  keycodeList[22] = "6";
  keycodeList[23] = "5";
  keycodeList[24] = "=";
  keycodeList[25] = "9";
  keycodeList[26] = "7";
  keycodeList[27] = "-";
  keycodeList[28] = "8";
  keycodeList[29] = "0";
  keycodeList[30] = "]";
  keycodeList[31] = "O";
  keycodeList[32] = "U";
  keycodeList[33] = "[";
  keycodeList[34] = "I";
  keycodeList[35] = "P";
  keycodeList[36] = "Return";
  keycodeList[37] = "L";
  keycodeList[38] = "J";
  keycodeList[39] = "'";
  keycodeList[40] = "K";
  keycodeList[41] = ";";
  keycodeList[42] = "\\";
  keycodeList[43] = ",";
  keycodeList[44] = "/";
  keycodeList[45] = "N";
  keycodeList[46] = "M";
  keycodeList[47] = ".";
  keycodeList[48] = "Tab";
  keycodeList[49] = "Space";
  keycodeList[50] = "`";
  keycodeList[51] = "Backspace";
  keycodeList[52] = "Enter";
  keycodeList[53] = "Esc";
  keycodeList[54] = "Unknown";
  keycodeList[55] = "Unknown (Command?)";
  keycodeList[56] = "(Left?) Shift";
  keycodeList[57] = "Unknown (Caps Lock?)";
  keycodeList[58] = "Unknown (Option?)";
  keycodeList[59] = "Unknown (Control?)";
  keycodeList[60] = "(Right?) Shift";
  keycodeList[61] = "Unknown (Right Option?)";
  keycodeList[62] = "Unknown (Right Control?)";
  keycodeList[63] = "Unknown";
  keycodeList[64] = "Unknown";
  keycodeList[65] = "Num pad .";
  keycodeList[66] = "Unknown (Mac Plus Right Arrow?)";
  keycodeList[67] = "Num pad *";
  keycodeList[68] = "Unknown";
  keycodeList[69] = "Num pad +";
  keycodeList[70] = "Unknown (Mac Plus Left Arrow?)";
  keycodeList[71] = "Clear";
  keycodeList[72] = "Unknown (Mac Plus Down Arrow?)";
  keycodeList[73] = "Unknown";
  keycodeList[74] = "Unknown";
  keycodeList[75] = "Num pad /";
  keycodeList[76] = "Num pad Enter";
  keycodeList[77] = "Unknown (Mac Plus Up Arrow?)";
  keycodeList[78] = "Num pad -";
  keycodeList[79] = "Unknown";
  keycodeList[80] = "Unknown";
  keycodeList[81] = "Num pad =";
  keycodeList[82] = "Num pad 0";
  keycodeList[83] = "Num pad 1";
  keycodeList[84] = "Num pad 2";
  keycodeList[85] = "Num pad 3";
  keycodeList[86] = "Num pad 4";
  keycodeList[87] = "Num pad 5";
  keycodeList[88] = "Num pad 6";
  keycodeList[89] = "Num pad 7";
  keycodeList[90] = "Unknown";
  keycodeList[91] = "Num pad 8";
  keycodeList[92] = "Num pad 9";
  keycodeList[93] = "Unknown";
  keycodeList[94] = "Unknown";
  keycodeList[95] = "Unknown";
  keycodeList[96] = "F5";
  keycodeList[97] = "F6";
  keycodeList[98] = "F7";
  keycodeList[99] = "F3";
  keycodeList[100] = "F8";
  keycodeList[101] = "F9";
  keycodeList[102] = "Unknown";
  keycodeList[103] = "F11";
  keycodeList[104] = "Unknown";
  keycodeList[105] = "F13";
  keycodeList[106] = "Unknown";
  keycodeList[107] = "F14";
  keycodeList[108] = "Unknown";
  keycodeList[109] = "F10";
  keycodeList[110] = "Fn + Enter (?)";
  keycodeList[111] = "F12";
  keycodeList[112] = "Unknown";
  keycodeList[113] = "F15";
  keycodeList[114] = "Help";
  keycodeList[115] = "Home";
  keycodeList[116] = "Page Up";
  keycodeList[117] = "Delete";
  keycodeList[118] = "F4";
  keycodeList[119] = "End";
  keycodeList[120] = "F2";
  keycodeList[121] = "Page Down";
  keycodeList[122] = "F1";
  keycodeList[123] = "Left Arrow";
  keycodeList[124] = "Right Arrow";
  keycodeList[125] = "Down Arrow";
  keycodeList[126] = "Up Arrow";
  keycodeList[127] = "Unknown";
}

/* Callback function for my event tap. */
CGEventRef tapCallback(CGEventTapProxy proxy, CGEventType type,
                       CGEventRef event, void *refcon) {
  CGEventFlags flags; /* Modifier keys and such */

  switch (type) {
    int64_t val; /* stores value of an event field */
    CGPoint loc; /* location for mouse events */

  case kCGEventKeyDown:
    val = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    printf("Key down: %lld %s\n", val,
           (val < KEYCODE_LIST_LENGTH) ? keycodeList[val] : "");
    break;

  case kCGEventKeyUp:
    val = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    printf("Key up: %lld %s\n", val,
           (val < KEYCODE_LIST_LENGTH) ? keycodeList[val] : "");
    break;

  case kCGEventFlagsChanged:
    flags = CGEventGetFlags(event);
    printf("Flags changed: ");
    if (flags & kCGEventFlagMaskAlphaShift) {
      printf("caps ");
    }
    if (flags & kCGEventFlagMaskShift) {
      printf("shift ");
    }
    if (flags & kCGEventFlagMaskControl) {
      printf("control ");
    }
    if (flags & kCGEventFlagMaskAlternate) {
      printf("option ");
    } 
    if (flags & kCGEventFlagMaskCommand) {
      printf("command ");
    }
    if (flags & kCGEventFlagMaskHelp) {
      printf("help? ");
    }
    if (flags & kCGEventFlagMaskSecondaryFn) {
      printf("fn ");
    }
    if (flags & kCGEventFlagMaskNumericPad) {
      printf("numeric ");
    }
    printf("\n");
    break;

  case kCGEventLeftMouseDown:
    loc = CGEventGetLocation(event);
    printf("Mouse down at (%.0f, %.0f) ev#%lld\n", loc.x, loc.y,
	   CGEventGetIntegerValueField(event, kCGMouseEventNumber));
    break;

  case kCGEventLeftMouseUp:
    loc = CGEventGetLocation(event);
    printf("Mouse up at (%.0f, %.0f) ev#%lld\n", loc.x, loc.y,
	   CGEventGetIntegerValueField(event, kCGMouseEventNumber));
    break;

  case kCGEventMouseMoved:
    loc = CGEventGetLocation(event);
    printf("Mouse moved at (%.0f, %.0f) delta (%lld, %lld)\n",
	   loc.x, loc.y,
	   CGEventGetIntegerValueField(event, kCGMouseEventDeltaX),
	   CGEventGetIntegerValueField(event, kCGMouseEventDeltaY));
    break;

  case kCGEventScrollWheel:
    loc = CGEventGetLocation(event);
    printf("Scroll wheel event at (%.0f, %.0f) delta (%lld, %lld, %lld)\n",
	   loc.x, loc.y,
	   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1),
	   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2),
	   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis3));
    break;

  case kCGEventNull:
    /* Let's get to the bottom of this! */
    loc = CGEventGetLocation(event);
    printf("null event at (%.0f, %.0f) type:%d\n", loc.x, loc.y,
	   CGEventGetType(event));
    break;
    
  default:
    printf("Other event received: %d\n", type);
  }

  return event;
}

int main(int argc, char *argv[]) {
  pid_t target_pid; /* target PID, obtained from command line */
  ProcessSerialNumber target_psn; /* PSN, obtained by converting target_pid */
  OSStatus status; /* return code */
  CGEventMask mask; /* Mask to specify which events I want to watch */
  CFRunLoopSourceRef tap_source; /* tap_port goes in here */
  CFRunLoopRef myRunLoop; /* tap_source goes in here */

  populateKeycodeList();

  /* First thing I need to do is parse the command line and decode
   * target_pid
   */
  if (argc < 2) {
    printf("Usage: monitor <pid>\n");
    return 0;
  }
  target_pid = atol(argv[1]);
  printf("Target PID: %d\n", target_pid);

  /* Now find the PSN correcponding to that PID */
  status = GetProcessForPID(target_pid, &target_psn);
  if (status != noErr) {
    fprintf(stderr, "Error converting PID to PSN: %d\n", (int) status);
    return -1;
  }
  printf("Target PSN: %0#10x%08x\n", (unsigned int) target_psn.highLongOfPSN,
         (unsigned int) target_psn.lowLongOfPSN);

  mask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp)
         | CGEventMaskBit(kCGEventFlagsChanged)
         | CGEventMaskBit(kCGEventLeftMouseDown)
         | CGEventMaskBit(kCGEventLeftMouseUp)
         | CGEventMaskBit(kCGEventNull)
         | CGEventMaskBit(kCGEventMouseMoved)
         | CGEventMaskBit(kCGEventScrollWheel);
  tap_port = CGEventTapCreateForPSN(&target_psn, kCGHeadInsertEventTap,
                                    kCGEventTapOptionListenOnly,
				    mask,
                                    tapCallback, NULL);
  if (NULL == tap_port) {
    fprintf(stderr, "Error creating event tap\n");
    return -1;
  }

  /* Create a run loop source from the tap port, add it to my run loop
   * and start executing the loop
   */
  tap_source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault,
                                             tap_port, 0);
  if (NULL == tap_source) {
    fprintf(stderr, "Error converting port to run loop source\n");
    if (tap_port != NULL) {
      CFRelease(tap_port);
    }
    return -1;
  }

  myRunLoop = CFRunLoopGetCurrent();
  CFRunLoopAddSource(myRunLoop, tap_source, kCFRunLoopCommonModes);
  CFRunLoopRun();

  return 0;
}
