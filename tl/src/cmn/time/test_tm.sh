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
# @(#)test_tm.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#q & d script to test the tx time lib

prlskel -eval -q << 'EOF'
$prlskel::echoLine = 0;
$prlskel::filterOutput = 's/ ->.*//';

require "./txtm.pl";

$thetime =  time;
$mytxtime = &txtm::to_gmtxtm($thetime);
if (&txtm::to_systime($mytxtime) == $thetime) { print "Test 1: PASS\n"; } else { print "Test 1: FAILED\n" ;}
exit
EOF
