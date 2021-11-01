/* Utility functions used by other fuzz-osx files. */

#ifndef FUZZ_OSX_UTIL
#define FUZZ_OSX_UTIL

#ifndef INT32_MAX
#define INT32_MAX 2147483647
#endif

/* Return a float in the range [0, 1) */
float randf();

/* Generate a random integer between 0 and max - 1 inclusive */
int randint(int max);

/* Get an integer in [0, max - 1] from percentage f, assuming f is in [0, 1) */
int getint(int max, float f);

#endif
