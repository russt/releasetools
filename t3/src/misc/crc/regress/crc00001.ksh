#!/bin/sh
#crc00001 - set up downstream tests.

TESTNAME=crc00001
echo TESTNAME is $TESTNAME
. ./regress_defs.ksh

#initialize TSTROOT:
rm -rf "$TSTROOT"
mkdir -p "$TSTROOT/bin"

PATH="$TSTROOT/bin${PS}$PATH"

#compile the source and install in TSTROOT:
echo compiling crc.c:
$CC -o $TSTROOT/bin/crc ../crc.c

#verify that we have the correct binary in our path:
which crc

#test the help message:
2>&1 $TSTROOT/bin/crc -help
status=$?

echo crc -help returned status=$status

