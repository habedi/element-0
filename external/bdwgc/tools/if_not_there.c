/*
 * A build-time utility used by `Makefile.direct` file.  Conditionally
 * execute the command `argv[2]` if the file `argv[1]` does not exist.
 * If the command is omitted (and the file does not exist), then just
 * exit with a nonzero code.
 */

#define NOT_GCBUILD
#include "private/gc_priv.h"

#include <unistd.h>

#ifdef __DJGPP__
#  include <dirent.h>
#endif

#ifdef __cplusplus
#  define EXECV_ARGV_T char **
#else
/* See the comment in `if_mach.c` file. */
#  define EXECV_ARGV_T void *
#endif

int
main(int argc, char **argv)
{
  FILE *f;
#ifdef __DJGPP__
  DIR *d;
#endif
  const char *fname;

  if (argc < 2 || argc > 3)
    goto Usage;

  fname = TRUSTED_STRING(argv[1]);
  f = fopen(fname, "rb");
  if (f != NULL) {
    fclose(f);
    return 0;
  }
  f = fopen(fname, "r");
  if (f != NULL) {
    fclose(f);
    return 0;
  }
#ifdef __DJGPP__
  if ((d = opendir(fname)) != 0) {
    closedir(d);
    return 0;
  }
#endif
  printf("^^^^Starting command^^^^\n");
  fflush(stdout);
  if (argc == 2) {
    /* The file is missing, but no command is given. */
    return 2;
  }

  execvp(TRUSTED_STRING(argv[2]), (EXECV_ARGV_T)(argv + 2));
  exit(1);

Usage:
  fprintf(stderr, "Usage: %s file_name [command]\n", argv[0]);
  return 1;
}
