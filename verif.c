#include <stdlib.h>
#include "vpi_user.h"


const char *get_plusargs(void) {

    static s_vpi_vlog_info info;
    static int i = 0;

    if (i == 0)
        vpi_get_vlog_info(&info);

    return (i >= info.argc) ? NULL : info.argv[i++];
}


const char *get_env(const char *name) {
    return getenv(name);
}


void set_env(const char *name, const char *val) {
    setenv(name, val, 1);
}