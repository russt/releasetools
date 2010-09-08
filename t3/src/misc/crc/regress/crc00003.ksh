#!/bin/sh
#crc00003 - test file-list version of crc

TESTNAME=crc00003
echo TESTNAME is $TESTNAME
. ./regress_defs.ksh

# usage: crc [-help] [-unixascii] [-binary] [-f <file_to_go_thru>] [-cont] <filenames...>

cd $TSTROOT

echo TIMES FOR crc dirA WITH ascii translation > crctime.A1
time (crc -f toc.dirA > crcs.dirA) 2>> crctime.A1
cat crctime.A1
wc -l crcs.dirA
head -5 crcs.dirA
egrep '\.bat$|META-INF' crcs.dirA
tail -5 crcs.dirA

#now calculate binary crc's:
echo TIMES FOR crc -binary dirB without ascii translation > crctime.B1
time (crc -binary -f toc.dirB > crcs.dirB) 2>> crctime.B1
cat crctime.B1
wc -l crcs.dirB
head -5 crcs.dirB
egrep '\.bat$|META-INF' crcs.dirB
tail -5 crcs.dirB
