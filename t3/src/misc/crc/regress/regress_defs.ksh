#common set-up for codegen regression suite.

#set path-separator:
unset PS; PS=':' ; _doscnt=`echo $PATH | grep -c ';'` ; [ $_doscnt -ne 0 ] && PS=';' ; unset _doscnt

export TSTBASE
TSTBASE=`(cd ../bld && pwd -P)`

export TSTROOT
TSTROOT=$TSTBASE/crctests

#set up compiler, based on platform.  (for now, assume gcc):
export CC
CC=gcc
