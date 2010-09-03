#!/bin/sh
#crc00004 - calculate crcs on bigfile

TESTNAME=crc00004
echo TESTNAME is $TESTNAME
. ./regress_defs.ksh

cd $TSTROOT

echo TIMES FOR crc bigfile with ascii translation > crctime.bigfile1
echo crc bigfile with ascii translation:
time (crc bigfile) 2>> crctime.bigfile1
echo "#####"
cat crctime.bigfile1

echo " "
echo TIMES FOR crc -binary bigfile without ascii translation > crctime.bigfile2
echo crc bigfile without ascii translation:
time (crc -binary bigfile) 2>> crctime.bigfile2
echo "#####"
cat crctime.bigfile2
