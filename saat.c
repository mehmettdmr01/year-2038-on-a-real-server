#include <stdio.h>
#include <time.h>
#include <errno.h>
#include <string.h>
int main(void) {
  errno = 0;
  time_t t = time(NULL);
  int e = errno;
  char buf[32] = "(gmtime NULL)";
  struct tm *g = gmtime(&t);
  if (g) strftime(buf, sizeof buf, "%Y-%m-%d %H:%M:%S", g);
  printf("time_t %zu bayt, time()=%lld, %s, errno=%s", sizeof(time_t), (long long)t, buf, e ? strerror(e) : "yok");
  return 0;
}
