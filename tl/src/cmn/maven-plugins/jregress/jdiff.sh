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
# @(#)jdiff.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

pkg=com.sun.jbi.internal.tools

[ -z "$JV_SRCROOT" ] && JV_SRCROOT=$SRCROOT
[ -z "$JV_TOOLROOT" ] && JV_TOOLROOT=$TOOLROOT

exec java -D${pkg}.jdiff.IGNORE=yes -Djbi.srcroot=$JV_SRCROOT -classpath $TOOLROOT/java/maven/plugins/jregress-1.0.jar ${pkg}.jdiff.Tool "$@"
