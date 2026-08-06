/* In-memory fallback for nmap's flat data files.

   nmap normally loads nmap-services, nmap-service-probes, nmap-os-db, etc.
   from disk. When those files are embedded into the binary (see
   gen_embedded_data.py) this serves them from memory via fmemopen(), so a
   standalone static nmap still does version detection (-sV), OS detection
   (-O), UDP payloads, and service/protocol/MAC lookups with no data files
   present. Disk copies still take precedence: nmap_fetchfile() checks
   --datadir/$NMAPDIR/./ first and only falls back to embedded data. */

#include "nmap_embedded.h"
#include "nmap_embedded_data.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

extern "C" int nmap_embedded_available(const char *name) {
  for (int i = 0; i < g_nmap_embedded_count; i++) {
    if (strcmp(g_nmap_embedded[i].name, name) == 0)
      return 1;
  }
  return 0;
}

static FILE *open_embedded(const char *name) {
  for (int i = 0; i < g_nmap_embedded_count; i++) {
    if (strcmp(g_nmap_embedded[i].name, name) != 0)
      continue;

    uLongf rawlen = g_nmap_embedded[i].rawlen;
    unsigned char *buf = (unsigned char *) malloc(rawlen ? rawlen : 1);
    if (buf == NULL)
      return NULL;

    if (uncompress(buf, &rawlen, g_nmap_embedded[i].data,
                   g_nmap_embedded[i].gzlen) != Z_OK) {
      free(buf);
      return NULL;
    }

    FILE *fp = fmemopen(buf, rawlen, "r");
    if (fp == NULL) {
      free(buf);
      return NULL;
    }
    /* buf is intentionally not freed: fmemopen keeps referencing it until
       fclose, and each data file is opened once per run. */
    return fp;
  }
  return NULL;
}

extern "C" FILE *nmap_data_fopen(const char *path) {
  const size_t plen = strlen(NMAP_EMBEDDED_PREFIX);
  if (strncmp(path, NMAP_EMBEDDED_PREFIX, plen) == 0)
    return open_embedded(path + plen);
  return fopen(path, "r");
}
