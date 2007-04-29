#!/bin/sh
#
# BEGIN_HEADER - DO NOT EDIT
# 
# The contents of this file are subject to the terms
# of the Common Development and Distribution License
# (the "License").  You may not use this file except
# in compliance with the License.
#
# You can obtain a copy of the license at
# https://open-esb.dev.java.net/public/CDDLv1.0.html.
# See the License for the specific language governing
# permissions and limitations under the License.
#
# When distributing Covered Code, include this CDDL
# HEADER in each file and include the License file at
# https://open-esb.dev.java.net/public/CDDLv1.0.html.
# If applicable add the following below this CDDL HEADER,
# with the fields enclosed by brackets "[]" replaced with
# your own identifying information: Portions Copyright
# [year] [name of copyright owner]
#

#
# @(#)updatedist2.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


#split up $PATH and see if I can find me

#am I on NT or unix?
foo=`echo $PATH | tr ';' ' '`
if [ "$PATH" = "$foo" ]; then
    #I'm on UNIX, assuming that the path has at least one delimiter
    PS=':'
    suf=""
else
    #I'm on NT
    PS=';'
    suf=".ksh"
fi

me=`basename $0`

#echo me is $me, but arg0 is $0

if [ $me = $0 ]; then
    for dir in `echo $PATH | tr "$PS" " "`
    do
#echo $dir, $dir/$me 

        if [ -x $dir/$me$suf -a -f $dir/$me$suf ]; then
#echo I FOUND ME in $dir
            #I'm in boot, so go up one:
            cd $dir/..
            break
        fi
    done
else
    #was called with full or partial path name:
    cd `dirname $0`/..
fi

TOOLROOT=`pwd`

echo TOOLROOT is $TOOLROOT
echo TOOLS CVSROOT is `cat $TOOLROOT/boot/CVS/Root`

CVSROOT=NULL
if [ -r boot/CVS/Root ]; then
    CVSROOT=`cat boot/CVS/Root`
    export CVSROOT
fi

if [ "$CVSROOT" = "NULL" ]; then
    echo "Sorry, I cannot find the $TOOLROOT/boot directory - ABORT."
    exit 1
fi

PATH="$TOOLROOT/boot${PS}$PATH"
#echo PATH is $PATH

FORTE_PORT=`whatport`
status=$?

if [ $status -ne 0 ]; then
    echo "Sorry, I cannot find the $TOOLROOT/boot/whatport utility - ABORT."
    exit 1
fi

errs=0

echo "##### cvs co -P ${FORTE_PORT}tools"
cvs co -P ${FORTE_PORT}tools
status=$?

if [ $status -ne 0 ]; then
    echo "ERROR:  'cvs -d $CVSROOT co ${FORTE_PORT}tools' FAILED"
    errs=1
fi

exit $status

#WARNING:  if we update the cvs binary, then some platforms may have trouble.
#TODO:  copy cvs binary somewhere else, before running the real update.
