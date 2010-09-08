/*
 * copyright (c) 2006 Michael Niedermayer <michaelni@gmx.at>
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <inttypes.h>

#ifndef CRC_TABLE_SIZE
#    define CRC_TABLE_SIZE 1024
#endif

#define av_always_inline inline
#define av_const

typedef uint32_t AVCRC;

typedef enum {
    CRC_8_ATM,
    CRC_16_ANSI,
    CRC_16_CCITT,
    CRC_32_IEEE,
    CRC_32_IEEE_LE,  /*< reversed bitorder version of CRC_32_IEEE */
    CRC_MAX,         /*< Not part of public API! Do not use outside libavutil. */
}uint32_tId;

#ifndef av_bswap32
static av_always_inline av_const uint32_t av_bswap32(uint32_t x)
{
    x= ((x<<8)&0xFF00FF00) | ((x>>8)&0x00FF00FF);
    x= (x>>16) | (x<<16);
    return x;
}
#endif

// be2ne ... big-endian to native-endian
// le2ne ... little-endian to native-endian

#if AV_HAVE_BIGENDIAN
#define av_le2ne32(x) av_bswap32(x)
#else
#define av_le2ne32(x) (x)
#endif

#define FF_ARRAY_ELEMS(a) (sizeof(a) / sizeof((a)[0]))

static struct {
    uint8_t  le;
    uint8_t  bits;
    uint32_t poly;
} av_crc_table_params[CRC_MAX] = {
    [CRC_8_ATM]      = { 0,  8,       0x07 },
    [CRC_16_ANSI]    = { 0, 16,     0x8005 },
    [CRC_16_CCITT]   = { 0, 16,     0x1021 },
    [CRC_32_IEEE]    = { 0, 32, 0x04C11DB7 },
    [CRC_32_IEEE_LE] = { 1, 32, 0xEDB88320 },
};

/* the global table used by this program: */
uint32_t CRCTable[CRC_TABLE_SIZE];
uint32_t *ctx = CRCTable;

//force the input buffer to be aligned on a 32-bit boundry:
#define BUFSIZE 64*1024
uint32_t bufstor[(BUFSIZE)/4];  //warning:  BUFSIZE must be divisible by 4 with 0 remainder.
uint8_t *buffer = (uint8_t *) bufstor;

#ifdef TEST
#define LOOPCOUNTS 1
#endif

#ifdef LOOPCOUNTS
long CASEA = 0;
long CASEB = 0;
#endif

/**
 * Initialize a CRC table.
 * @param ctx must be an array of size sizeof(uint32_t)*257 or sizeof(uint32_t)*1024
 * @param le If 1, the lowest bit represents the coefficient for the highest
 *           exponent of the corresponding polynomial (both for poly and
 *           actual CRC).
 *           If 0, you must swap the CRC parameter and the result of av_crc
 *           if you need the standard representation (can be simplified in
 *           most cases to e.g. bswap16):
 *           av_bswap32(crc << (32-bits))
 * @param bits number of bits for the CRC
 * @param poly generator polynomial without the x**bits coefficient, in the
 *             representation as specified by le
 * @param ctx_size size of ctx in bytes
 * @return <0 on failure
 */
int av_crc_init(uint32_t *ctx, int le, int bits, uint32_t poly, int ctx_size){
    int i, j;
    uint32_t c;

    if (bits < 8 || bits > 32 || poly >= (1LL<<bits))
        return -1;
    if (ctx_size != sizeof(uint32_t)*257 && ctx_size != sizeof(uint32_t)*1024)
        return -1;

    for (i = 0; i < 256; i++) {
        if (le) {
            for (c = i, j = 0; j < 8; j++)
                c = (c>>1)^(poly & (-(c&1)));
            ctx[i] = c;
        } else {
            for (c = i << 24, j = 0; j < 8; j++)
                c = (c<<1) ^ ((poly<<(32-bits)) & (((int32_t)c)>>31) );
            ctx[i] = av_bswap32(c);
        }
    }
    ctx[256]=1;
    if(ctx_size >= sizeof(uint32_t)*1024)
        for (i = 0; i < 256; i++)
            for(j=0; j<3; j++)
                ctx[256*(j+1) + i]= (ctx[256*j + i]>>8) ^ ctx[ ctx[256*j + i]&0xFF ];

    return 0;
}

/**
 * Calculate the CRC of a block, in 4-byte blocks.
 * WARNING:  we assume that you have declared input buffer to be aligned on 32-bit boundry.
 * WARNING:  we assume that crc table has 1024 entries.
 * @param crc CRC of previous blocks if any or initial value for CRC
 * @return CRC updated with the data from the given block
 *
 * @see av_crc_init() "le" parameter
 */
uint32_t av_crc(const uint32_t *ctx, uint32_t crc, const uint8_t *buffer, size_t length)
{
    const uint8_t *end= buffer+length;

    while(buffer<end-3){
#ifdef LOOPCOUNTS
++CASEA;
#endif
        crc ^= av_le2ne32(*(const uint32_t*)buffer);
        crc =  ctx[3*256 + ( crc     &0xFF)]
              ^ctx[2*256 + ((crc>>8 )&0xFF)]
              ^ctx[1*256 + ((crc>>16)&0xFF)]
              ^ctx[0*256 + ((crc>>24)     )];
        buffer+=4;
    }

    while(buffer<end) {
#ifdef LOOPCOUNTS
++CASEB;
#endif
        crc = ctx[((uint8_t)crc) ^ *buffer++] ^ (crc >> 8);
    }

    return crc;
}

/*
* BEGIN_HEADER - DO NOT EDIT
*
* The contents of this file are subject to the terms
* of the Common Development and Distribution License
* (the "License").  You may not use this file except
* in compliance with the License.
*
* You can obtain a copy of the license at
* https://open-esb.dev.java.net/public/CDDLv1.0.html.
* See the License for the specific language governing
* permissions and limitations under the License.
*
* When distributing Covered Code, include this CDDL
* HEADER in each file and include the License file at
* https://open-esb.dev.java.net/public/CDDLv1.0.html.
* If applicable add the following below this CDDL HEADER,
* with the fields enclosed by brackets "[]" replaced with
* your own identifying information: Portions Copyright
* [year] [name of copyright owner]
*
*
*
* @(#)crc.c - ver 1.1 - 01/04/2006
*
* Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
* Copyright 2010 Russ Tremain. All Rights Reserved.
*
* END_HEADER - DO NOT EDIT
*
*/

/*
 * crc
 * Cyclic Redundancy Check 32-bit
 * An algorithm to map a string into a 32-bit number, so that the
 * total number of strings that map to one number are about the same
 * as the total number of strings that map to another number; ie, the
 * curve is flat or well distributed.
 * Taken from Dr. Dobbs Journal.
 * -cliffwd
 *
 * Compiling on unix:
 *    gcc -O crc.c -o crc
 * Compiling on NT:
 *    cl -O -D__WIN32__ crc.c -o crc
 *
 *  08-Sep-2010 (russt)
 *    Re-written to incorporate faster 4-byte crc calculation, condensed from
 *    ffmpeg libavutil version.
 */

static int globalErrorCount = 0;
/* If unixAscii is true, then generate a crc first converting to a
   standard (unix) ascii format; this let's us do cross platform crc's
   better. */
static int unixAscii = 1;

unsigned char ebsidic2ascii[] = {
          0,  1,  2,  3,156,  9,134,127,151,141,142, 11, 12, 13, 14,
         15, 16, 17, 18, 19,157, 10,  8,135, 24, 25,146,143, 28, 29,
         30, 31,128,129,130,131,132,133, 23, 27,136,137,138,139,140,
          5,  6,  7,144,145, 22,147,148,149,150,  4,152,153,154,155,
         20, 21,158, 26, 32,160,226,228,224,225,227,229,231,241,162,
         46, 60, 40, 43,124, 38,233,234,235,232,237,238,239,236,223,
         33, 36, 42, 41, 59, 94, 45, 47,194,196,192,193,195,197,199,
        209,166, 44, 37, 95, 62, 63,248,201,202,203,200,205,206,207,
        204, 96, 58, 35, 64, 39, 61, 34,216, 97, 98, 99,100,101,102,
        103,104,105,171,187,240,253,254,177,176,106,107,108,109,110,
        111,112,113,114,170,186,230,184,198,164,181,126,115,116,117,
        118,119,120,121,122,161,191,208, 91,222,174,172,163,165,183,
        169,167,182,188,189,190,221,168,175, 93,180,215,123, 65, 66,
         67, 68, 69, 70, 71, 72, 73,173,244,246,242,243,245,125, 74,
         75, 76, 77, 78, 79, 80, 81, 82,185,251,252,249,250,255, 92,
        247, 83, 84, 85, 86, 87, 88, 89, 90,178,212,214,210,211,213,
         48, 49, 50, 51, 52, 53, 54, 55, 56, 57,179,219,220,217,218,
        159
};

uint32_t
CalculateBufferCRC(const uint32_t *ctx, uint32_t crc, const uint8_t *buffer, int count)
{
    int index;
    unsigned char *p;
    unsigned long temp1, temp2;

    p = (unsigned char *) buffer;
    while (count-- > 0) {
        if (unixAscii && (*p == 0x0d && *(p+1) == 0x0a)) {
          /* printf("doing ascii translation for nt\n"); */
          ++p;
          continue;
        }
        /* printf("crc = %x p = '%x'\n", crc, *p); */
        temp1 = (crc >> 8) & 0x00FFFFFFL;
        index = ((int) crc ^ *p++) & 0xff;
        temp2 = ctx[index];
        crc = temp1 ^ temp2;
    }
    return(crc);
}

unsigned long CalculateFileCRC(FILE *fp)
{
    unsigned long crc;

    int count;
    int i;

    crc = 0xFFFFFFFFL;
    //crc = 0L;
    i = 0;
    while (1) {
        count = fread(buffer, 1, BUFSIZE, fp);
        if (count == 0)
            break;
        if (unixAscii) {
          if (count == BUFSIZE && buffer[BUFSIZE-1] == 0x0d) {
            count += fread(&buffer[BUFSIZE], 1, 1, fp);
          }
#ifdef __MVS__
          /* printf("doing ascii translation\n"); */
          for (i = 0; i < count; ++i) {
            buffer[i] = ebsidic2ascii[buffer[i]];
          }
#endif
            crc = CalculateBufferCRC(ctx, crc, buffer, count);
        } else {
            crc = av_crc(ctx, crc, buffer, count);
        }
    }
    return (crc ^= 0xFFFFFFFFL);
}

unsigned long CalculateFileNameCRC(char *filename)
{
  FILE  *fp;
  unsigned long crc;
  
  fp = fopen(filename, "rb");
  if (!fp) {
    fprintf(stderr, "unable to open '%s' for read\n", filename);
    ++globalErrorCount;
    return 0;
  }
  crc = CalculateFileCRC(fp);
  fclose(fp);
  return crc;
}

void CRCFromFile(FILE *fin)
     /* read a list of file names from fin, get their crc's, and prin them */
{
  unsigned long crc;
  char filename[1024];
  
  while (!feof(fin)) {
    if (!fgets(filename, 1024, fin)) {
      /* some sort of condition caused it to not read anymore in
         (EOF, etc). */
      break;
    }
    /* get rid of the trailing newline */
    filename[strlen(filename) - 1] = '\0';

    if (strcmp(filename, "-binary") == 0) {
      unixAscii = 0;
      printf("Switched to binary mode.\n");
      fflush(stdout);
      continue;
    } else if (strcmp(filename, "-unixascii") == 0) {
      unixAscii = 1;
      printf("Switched to text mode.\n");
      fflush(stdout);
      continue;
    }
    
    crc = CalculateFileNameCRC(filename);
    printf("%s %lx\n", filename, crc);
    fflush(stdout);
  }
}

char *
crcIdStr(uint32_tId id)
//return string for type
{
    switch (id) {
    case CRC_8_ATM:         return "CRC_8_ATM";
    case CRC_16_ANSI:       return "CRC_16_ANSI";
    case CRC_16_CCITT:      return "CRC_16_CCITT";
    case CRC_32_IEEE:       return "CRC_32_IEEE";
    case CRC_32_IEEE_LE:    return "CRC_32_IEEE_LE";
    default:                return "NULL";
    }
}

#ifdef TEST
#undef printf
int
main(void)
{
    //force the buffer to be aligned on a long boundry:
    int bufsize = 1999;
    uint32_t dummy[(bufsize+1)/4];
    uint8_t *buf = (uint8_t *) dummy;
    int i;

    dummy[0] = 0;

    //initialize buffer:
    for(i=0; i<bufsize; i++)
        buf[i]= i+i*i;

    for(i=0; i<CRC_MAX; i++)
    {
        av_crc_init(ctx, av_crc_table_params[i].le,  av_crc_table_params[i].bits, av_crc_table_params[i].poly, sizeof(CRCTable));
        printf("crc for %-15s (le,bits,poly): (%d, %2d, %9X) is %9X",
            crcIdStr(i),
            av_crc_table_params[i].le,
            av_crc_table_params[i].bits,
            av_crc_table_params[i].poly,
            av_crc(ctx, 0, (uint8_t *) buf, bufsize));
#ifdef LOOPCOUNTS
            printf("\tCASEA=%ld CASEB=%ld\n", CASEA, CASEB);
            CASEA = CASEB = 0;
#endif
    }
    return 0;
}
#else
int 
main(int argc, char *argv[])
{
    int             i;
    unsigned long   crc;

    if (argc < 2 || strcmp(argv[1], "-help") == 0) {
        fprintf(stderr, "Calculate the CRC of a file.\n");
        fprintf(stderr, "It's better than a checksum, it's a crc!\n");
        fprintf(stderr, "ASCII translation on by default, use -binary to turn off.\n");
        fprintf(stderr, "usage: %s [-help] [-unixascii] [-binary] [-f <file_to_go_thru>] [-cont] <filenames...>\n", argv[0]);
        exit(1);
    }
    globalErrorCount = 0;

    av_crc_init(ctx,
        av_crc_table_params[CRC_32_IEEE_LE].le,
        av_crc_table_params[CRC_32_IEEE_LE].bits,
        av_crc_table_params[CRC_32_IEEE_LE].poly,
        sizeof(CRCTable));

    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "-ascii") == 0) {
            /* ignore this arg */
        } else if (strcmp(argv[i], "-unixascii") == 0) {
            unixAscii = 1;
        } else if (strcmp(argv[i], "-binary") == 0) {
            unixAscii = 0;
        } else if (strcmp(argv[i], "-cont") == 0) {
            CRCFromFile(stdin);
        } else if (strcmp(argv[i], "-f") == 0) {
            FILE           *in;
            ++i;
            in = fopen(argv[i], "r");
            if (!in) {
                fprintf(stderr, "unable to open '%s' for read\n", argv[i]);
                exit(1);
            }
            CRCFromFile(in);
            fclose(in);
        } else {
            crc = CalculateFileNameCRC(argv[i]);
            printf("%s %lx\n", argv[i], crc);
        }
    }
#ifdef LOOPCOUNTS
    fprintf(stderr, "CASEA=%ld CASEB=%ld\n", CASEA, CASEB);
#endif
    exit(globalErrorCount);
}
#endif
