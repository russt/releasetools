#!/bin/csh -f
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
# @(#)inherit.csh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# Bring over a file from another path.

if ("$1" == "-h" || "$1" == "-help" || $#argv < 2) then
	echo Usage: inherit [path] [source file]
	exit
endif

set srcPath = $1
set srcFile = $2

set srcDir=`pwd`
set srcDir=`echo $srcDir | sed -e "s/^\/..*\/$SRCPATH\///"`

setenv OTHERSRCROOT "$1"
if (! -e "$OTHERSRCROOT") then
	# Pick up the srcPath's OTHERSRCROOT
	eval `usePathDef $1 | grep SRCROOT | sed -e "s/SRCROOT/OTHERSRCROOT/"`

	if ($status) then
		echo usePathDef $1 failed
		exit 1
	endif
endif

# echo OTHERSRCROOT is $OTHERSRCROOT
# echo srcDir is $srcDir
# echo srcFile is $srcFile

# Get the proper source path aliases
set fortepj=$TOOLROOT/lib/cmn/fortepj.rc
if (-r $fortepj) then
	source $fortepj
else
	echo ERROR: Unable to read $fortepj
	exit 1
endif

if (! -r $srcFile) then
	cp $OTHERSRCROOT/$srcDir/$srcFile .
	newfile $srcFile <<EOF
inherited from $OTHERSRCROOT
EOF
	exit
endif

echo y | pco $srcFile
if ($status) then
	echo Failed to pco $srcFile properly.
	exit 1
endif

echo /bin/cp $OTHERSRCROOT/$srcDir/$srcFile .
/bin/cp $OTHERSRCROOT/$srcDir/$srcFile .

pci $srcFile <<EOF
y
inherited from $OTHERSRCROOT
EOF
