#ifndef DOOM_EMBED_H
#define DOOM_EMBED_H

/* Sentinel "path" the WAD loader recognizes as the embedded IWAD. It begins
   with a byte no real filename contains, so it can never collide with a file
   on disk. */
#define DOOM_EMBED_SENTINEL "\x01" "embedded:doom1.wad"

/* Returns a pointer to the decompressed embedded IWAD (inflated once, cached),
   and sets *out_len to its byte length. Returns NULL on failure. */
const unsigned char *doom_embed_get_wad(unsigned int *out_len);

#endif /* DOOM_EMBED_H */
