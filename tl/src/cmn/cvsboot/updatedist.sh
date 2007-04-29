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
# @(#)updatedist.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#this script is not mean to ever be changed.
#It's sole purpose is to update the updateDist2.sh, and then run that.

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

export CVSROOT
CVSROOT=NULL
if [ -r boot/CVS/Root ]; then
    CVSROOT=`cat boot/CVS/Root`
fi

if [ "$CVSROOT" = "NULL" ]; then
    echo "Sorry, I cannot find the $TOOLROOT/boot directory - ABORT."
    exit 1
fi

#Update the real update script, and then run it.
cvs update "boot/updateDist2.sh"
sh "$TOOLROOT/boot/updateDist2.sh"
exit $?
