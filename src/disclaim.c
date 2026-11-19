// disclaim: run a program as its own TCC-responsible process, the way a
// terminal does for its shells.
//
// grant.sh uses it to (re)grant the installed launcher its Removable Volumes
// access. A launchd job cannot show a TCC prompt, and a command run from a
// terminal or Claude Code is attributed to that app instead of the launcher,
// so neither context ever asks on the launcher's behalf.

#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>

extern char **environ;
extern int responsibility_spawnattrs_setdisclaim(posix_spawnattr_t *attrs, int disclaim);

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s program [args...]\n", argv[0]);
        return 64;
    }

    posix_spawnattr_t attrs;
    posix_spawnattr_init(&attrs);
    responsibility_spawnattrs_setdisclaim(&attrs, 1);

    pid_t pid;
    int err = posix_spawn(&pid, argv[1], NULL, &attrs, &argv[1], environ);
    if (err != 0) {
        fprintf(stderr, "%s: %s: %s\n", argv[0], argv[1], strerror(err));
        return 127;
    }

    int status;
    waitpid(pid, &status, 0);
    return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
}
