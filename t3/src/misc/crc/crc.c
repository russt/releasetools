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
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFFER_SIZE 4096

static int globalErrorCount = 0;
/* If unixAscii is true, then generate a crc first converting to a
   standard (unix) ascii format; this let's us do cross platform crc's
   better. */
static int unixAscii = 1;

unsigned long CRCTable[256];

#define CRC32_POLYNOMIAL 0xEDB88320L

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

void BuildCRCTable()
{
    int i, j;
    unsigned long crc;

    for (i = 0; i <= 255; ++i) {
        crc = i;
        for (j = 8; j > 0; --j) {
            if (crc & 1)
                crc = (crc >> 1) ^ CRC32_POLYNOMIAL;
            else
                crc >>= 1;
			/* printf("i=%d j=%d crc=%lx\n", i, j, crc); */
        }
        CRCTable[i] = crc;
		/* printf("CRCTable[%d] = %lx\n", i, crc); */
    }
}

unsigned long CalculateBufferCRC(unsigned int count, unsigned long
                                 crc, void *buffer)
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
        temp2 = CRCTable[index];
        crc = temp1 ^ temp2;
    }
    return(crc);
}

unsigned long CalculateFileCRC(FILE *fp)
{
    unsigned long crc;
    int count;
    unsigned char buffer[BUFFER_SIZE+1];
    int i;

    crc = 0xFFFFFFFFL;
    i = 0;
    while (1) {
        count = fread(buffer, 1, BUFFER_SIZE, fp);
        if (count == 0)
            break;
		if (unixAscii) {
		  if (count == BUFFER_SIZE && buffer[BUFFER_SIZE-1] == 0x0d) {
			count += fread(&buffer[BUFFER_SIZE], 1, 1, fp);
		  }
#ifdef __MVS__
		  /* printf("doing ascii translation\n"); */
		  for (i = 0; i < count; ++i) {
			buffer[i] = ebsidic2ascii[buffer[i]];
		  }
#endif
		}
        crc = CalculateBufferCRC(count, crc, buffer);
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

int main(int argc, char *argv[])
{
  int i;
  unsigned long crc;
    
  if (argc < 2 || strcmp(argv[1], "-help") == 0) {
    fprintf(stderr, "Calculate the CRC of a file.\n");
    fprintf(stderr, "It's better than a checksum, it's a crc!\n");
	fprintf(stderr, "ASCII translation on by default, use -binary to turn off.\n");
    fprintf(stderr, "usage: %s [-help] [-unixascii] [-binary] [-f <file_to_go_thru>] [-cont] <filenames...>\n", argv[0]);
    exit(1);
  }

  globalErrorCount = 0;
  BuildCRCTable();

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
	  FILE  *in;
	  ++i;
      in = fopen(argv[i], "r");
      if (! in) {
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
  exit(globalErrorCount);
}
