ARCH="-DARCH=x86"
ARCH=
#CPPFLAGS="-D_ISOC99_SOURCE -D_POSIX_C_SOURCE=200112 -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE"
CFLAGS="-std=c99 -mdynamic-no-pic -fomit-frame-pointer -g -Wdeclaration-after-statement -Wall -Wno-parentheses -Wno-switch -Wdisabled-optimization -Wpointer-arith -Wredundant-decls -Wno-pointer-sign -Wcast-qual -Wwrite-strings -Wundef -Wmissing-prototypes -O3 -fno-math-errno -fno-tree-vectorize"
CFLAGS="-std=c99"
AV_HAVE_BIGENDIAN="-DAV_HAVE_BIGENDIAN=1"
AV_HAVE_BIGENDIAN="-DAV_HAVE_BIGENDIAN=0"

aout=crc1024
rm -f $aout
gcc -I.. -DTEST $CRC_TABLE_SIZE $ARCH $AV_HAVE_BIGENDIAN $CPPFLAGS $CFLAGS -o $aout crc.c
./$aout
