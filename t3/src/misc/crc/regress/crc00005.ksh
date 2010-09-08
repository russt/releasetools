#!/bin/sh
#crc00005 - comment

TESTNAME=crc00005
echo TESTNAME is $TESTNAME
. ./regress_defs.ksh

cd $TSTROOT

echo TIMES FOR crc bigfile WITH ascii translation > crctime.bigfile2
echo crc bigfile WITH ascii translation:
time (crc bigfile) 2>> crctime.bigfile2
echo "#####"
cat crctime.bigfile2
