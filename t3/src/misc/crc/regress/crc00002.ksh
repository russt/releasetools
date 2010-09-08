#!/bin/sh
#crc00002 - set up some data for remaining tests

TESTNAME=crc00002
echo TESTNAME is $TESTNAME
. ./regress_defs.ksh

#get some data:
cp $SRCROOT/t3/src/apache/ant1_6/ant16.btz $TSTROOT/data.btz

cd $TSTROOT
#1.5GB file from compressed test data:
gzip -dc $BIGFILEGZ > 100M
cat 100M 100M 100M 100M 100M 100M 100M 100M 100M 100M 100M 100M 100M 100M 100M > bigfile

echo CREATE $TSTROOT/dirA
mkdir dirA
cd dirA
tar xzf ../data.btz
walkdir -qq -unjar
walkdir -qq -unjar
echo CREATE file list FOR $TSTROOT/dirA
cd ..
walkdir -f dirA > toc.dirA
wc -l toc.dirA

echo CREATE $TSTROOT/dirB
mkdir dirB
cd dirB
tar xzf ../data.btz
walkdir -qq -unjar
walkdir -qq -unjar
echo CREATE file list FOR $TSTROOT/dirB
cd ..
walkdir -f dirB > toc.dirB
wc -l toc.dirB
