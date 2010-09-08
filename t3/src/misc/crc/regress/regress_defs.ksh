#common set-up for codegen regression suite.

#set path-separator:
unset PS; PS=':' ; _doscnt=`echo $PATH | grep -c ';'` ; [ $_doscnt -ne 0 ] && PS=';' ; unset _doscnt

export TSTSRC TSTBASE BIGFILE
TSTSRC=`pwd -P`
TSTBASE=`(cd ../bld && pwd -P)`

BIGFILEGZ=$TSTSRC/data/enwik8.gz

export TSTROOT
TSTROOT=$TSTBASE/crctests

PATH="$TSTROOT/bin${PS}$PATH"

#set up compiler, based on platform.  (for now, assume gcc):
export CC LC_CTYPE CCFLAGS
CC=gcc

#this makes compiler error messages more readable for later versions of gcc:
LC_CTYPE="POSIX"

#note:  c99 is not strictly necessary.  I was getting errors from <inttypes.h> earlier.
#note:  removing -O slows the non-binary calculation down considerably (half the speed!).
#       strangely, it has little effect on the -binary calculation.
CCFLAGS="-O -std=c99"
