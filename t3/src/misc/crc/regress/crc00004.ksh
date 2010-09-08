#!/bin/sh
#crc00004 - calculate crcs on bigfile

TESTNAME=crc00004
echo TESTNAME is $TESTNAME
. ./regress_defs.ksh

cd $TSTROOT

echo TIMES FOR crc -binary bigfile without ascii translation > crctime.bigfile
echo crc bigfile without ascii translation:
time (crc -binary bigfile) 2>> crctime.bigfile
echo "#####"
cat crctime.bigfile
