#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdatomic.h>
/* Diagnostic-only clock bridge for unmodified Godot. Other getenv calls are forwarded. */
char *getenv(const char *name) {
    typedef char *(*getenv_fn)(const char *);
    static _Atomic(getenv_fn) original = NULL;
    getenv_fn next_getenv = atomic_load(&original);
    static _Thread_local char value[32];
    if (strcmp(name, "SPACE_IDLE_DIAG_THREAD_CPU_US") == 0) {
        struct timespec t;
        if (clock_gettime(CLOCK_THREAD_CPUTIME_ID, &t) != 0) return NULL;
        snprintf(value, sizeof(value), "%lld", (long long)t.tv_sec * 1000000 + t.tv_nsec / 1000);
        return value;
    }
    if (!next_getenv) { next_getenv = dlsym(RTLD_NEXT, "getenv"); atomic_store(&original, next_getenv); }
    return next_getenv ? next_getenv(name) : NULL;
}
