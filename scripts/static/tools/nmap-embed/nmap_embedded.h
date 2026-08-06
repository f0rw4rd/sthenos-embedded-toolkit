#ifndef NMAP_EMBEDDED_H
#define NMAP_EMBEDDED_H

#include <stdio.h>

/* Path prefix used as a sentinel for data files served from memory.
   nmap_fetchfile() returns "<prefix><logical-name>" when a data file is not
   found on disk but is compiled into the binary; nmap_data_fopen() recognizes
   it and returns an in-memory stream. A real path can never begin with this. */
#define NMAP_EMBEDDED_PREFIX "[embedded]/"

#ifdef __cplusplus
extern "C" {
#endif

/* Returns 1 if a data file named `name` is compiled into the binary. */
int nmap_embedded_available(const char *name);

/* If `path` is an embedded sentinel (see NMAP_EMBEDDED_PREFIX), returns a
   read-only FILE* backed by the decompressed in-memory contents. Otherwise
   behaves like fopen(path, "r"). Returns NULL on failure. */
FILE *nmap_data_fopen(const char *path);

#ifdef __cplusplus
}
#endif

#endif /* NMAP_EMBEDDED_H */
