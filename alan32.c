#include <stdio.h>
#include <stdint.h>
#include <time.h>
int main(void) {            /* a timestamp kept in a 32-bit field, like old code, file formats and DB columns */
  time_t now = time(NULL);
  int32_t stored = (int32_t)now;
  time_t back = stored;
  char a[32], b[32];
  strftime(a, sizeof a, "%Y-%m-%d %H:%M:%S", gmtime(&now));
  strftime(b, sizeof b, "%Y-%m-%d %H:%M:%S", gmtime(&back));
  printf("gercek %s, int32 alanda %s (%d)", a, b, stored);
  return 0;
}
