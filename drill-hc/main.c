// This is a minimal C wrapper for drill to avoid the need for a shell
// and reduce the exit code to 0 or 1.
// Dockerfile reference says that health checks should always return 0 or 1.
// Any other status code is reserved.
// See https://docs.docker.com/reference/dockerfile/#healthcheck

#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    char* DRILL_ARGS[] = {"/usr/bin/drill", NULL};
    if (argc == 0) {
        argv = DRILL_ARGS;
    }
    else {
        argv[0] = DRILL_ARGS[0];
    }

    switch (fork())
    {
    case -1:
        perror("Error calling fork()");
        return 1;

    case 0:
        execv(argv[0], argv);
        perror("Error calling execv() with drill");
        return 1;

    default:
        int status;
        if (wait(&status) == -1) {
            perror("Error calling wait()");
            return 1;
        }
        if (WIFEXITED(status)) {
            if (WEXITSTATUS(status) == 0) {
                return 0;
            }
            else {
                return 1;
            }

        } else {
            fprintf(stderr, "drill process was terminated for unknown reason\n");
            return 1;
        }
    }
}
