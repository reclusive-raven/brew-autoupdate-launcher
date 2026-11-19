// brew-autoupdate-launcher: run a program as a child of this binary.
//
// launchd makes a job's own executable the process macOS privacy checks (TCC)
// hold responsible for everything the job does. For homebrew-autoupdate that
// was /bin/sh, which has no Removable Volumes access, so every run failed on
// HOMEBREW_CACHE on an external volume. With this binary in front, it becomes the
// responsible process and it alone holds the grants. It must spawn, not exec:
// exec would turn this process back into /bin/sh as far as TCC is concerned.
//
// TCC keys the grants on the installed path plus this binary's cdhash, so any
// change to the compiled output needs the grants given again. Comment edits
// are safe; CLAUDE.md has the rest.

#include <errno.h>
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>

extern char **environ;

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s program [args...]\n", argv[0]);
        return 64;
    }

    pid_t pid;
    int err = posix_spawn(&pid, argv[1], NULL, NULL, &argv[1], environ);
    if (err != 0) {
        fprintf(stderr, "%s: %s: %s\n", argv[0], argv[1], strerror(err));
        return 127;
    }

    int status;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) {
            perror("waitpid");
            return 1;
        }
    }
    return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
}
