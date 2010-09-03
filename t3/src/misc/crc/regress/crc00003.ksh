#!/bin/sh
#crc00003 - test file-list version of crc

TESTNAME=crc00003
echo TESTNAME is $TESTNAME
. ./regress_defs.ksh

# usage: crc [-help] [-unixascii] [-binary] [-f <file_to_go_thru>] [-cont] <filenames...>

cd $TSTROOT

time (crc -f toc.dirA > crcs.dirA) 2> crctime.A1
wc -l crcs.dirA

#now calculate binary crc's:
time (crc -binary -f toc.dirB > crcs.dirB) 2> crctime.B1
wc -l crcs.dirB
