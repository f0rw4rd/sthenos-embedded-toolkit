/* Embedded shareware IWAD: the WAD is stored raw-DEFLATE compressed in
   doom_wad_deflated.h (generated at build time) and inflated once into a heap
   buffer via puff (zlib's public-domain reference inflater, no external deps).
   The rest of the engine reads it through fmemopen -- see the W_StdC_OpenFile
   patch in w_file_stdc.c. */

#include <stdlib.h>

#include "doom_embed.h"
#include "puff.h"
#include "doom_wad_deflated.h"   /* doom_wad_deflated[], _len, doom_wad_orig_len */

const unsigned char *doom_embed_get_wad(unsigned int *out_len)
{
    static unsigned char *wad = NULL;
    static unsigned long   wad_len = 0;

    if (wad == NULL)
    {
        unsigned long destlen = doom_wad_orig_len;
        unsigned long srclen  = doom_wad_deflated_len;
        unsigned char *buf = (unsigned char *) malloc(destlen);

        if (buf == NULL)
            return NULL;

        if (puff(buf, &destlen, doom_wad_deflated, &srclen) != 0
            || destlen != doom_wad_orig_len)
        {
            free(buf);
            return NULL;
        }

        wad = buf;
        wad_len = destlen;
    }

    if (out_len != NULL)
        *out_len = (unsigned int) wad_len;

    return wad;
}
