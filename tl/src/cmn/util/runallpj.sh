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
# @(#)runallpj.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# runinallpj
# rsh to all of the unix bldhosts and runinpj on them


rcmd="$1"
proj=`grep $PROJECT $MYPROJECTS | awk '{print $1}'`

if [ "$rcmd" = "-help" -o "$rcmd" = "-h" -o "$rcmd" = "" ]
then
	echo 'Usage: runinallpj <command>'
	echo '   eg: runinallpj /bld/tools/updateDist'
	exit 0
fi

if [ "$proj" = "" ]
then
	echo "BUILD_ERROR: Unable to figure out what your project is.  (Have you run chpj yet?)"
	exit 1
fi

for m in `bldhost -unix`
do
	echo $m
	rsh -n $m runinpj $proj "$@" &
done

wait
