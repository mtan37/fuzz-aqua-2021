#include <stdlib.h>
#include <math.h>
#include "util.h"

/* Return a float in the range [0, 1) */
float randf() {
  float f;
  do f = (float) random() / (float) (INT32_MAX);
  while(f == 1.0);
  return f;
}

/* Generate a random integer between 0 and max - 1 inclusive */
int randint(int max) {
  return (int)trunc(((float) random() / ((float) INT32_MAX + 1)) * max);
}

/* Get an integer in [0, max - 1] from percentage f, assuming f is in [0, 1) */
int getint(int max, float f) {
  return (int)trunc(f * (float)max);
}
