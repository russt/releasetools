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
# @(#)jregress.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
#
# END_HEADER - DO NOT EDIT
#


gettestlist()
#echo a list of tests to run, based on the content of:
#  jregress.includes - jregress.excludes
#warning:  include/exclude files must be sorted
{

    if [ ! -r jregress.includes -a ! -r jregress.excludes ]; then
        echo ""
        return
    fi

    if [ -r jregress.includes -a -r jregress.excludes ]; then
        #return includes - excludes (files must be sorted!):
        echo `comm -23 jregress.includes jregress.excludes | grep -v '^#'`
        return
    fi

    if [ -r jregress.includes ]; then
        echo `grep -v '^#' jregress.includes`
        return
    fi

    #otherwise, we have jregress.excludes only - calculate include set:
    if [ $havetests -eq 0 ]; then
        #no reference files:
        echo ""
        return
    fi

    #otherwise, we have ref files - generate a tmp file:
    tmpA=jregress_testlist.$$
    ls *.ref | sed -e 's/\.ref//' > $tmpA
    echo `comm -23 $tmpA jregress.excludes`
    rm -f $tmpA
}

#these variables reak havoc with the JDK under mks:
unset TMP
unset tmp

pkg=com.sun.jbi.internal.tools

[ -z "$JV_SRCROOT" ] && JV_SRCROOT=$SRCROOT
[ -z "$JV_TOOLROOT" ] && JV_TOOLROOT=$TOOLROOT
[ -z "$JREGRESS_TIMEOUT" ] && JREGRESS_TIMEOUT=400
[ -z "$JREGRESS_OUTPUT_DIR" ] && JREGRESS_OUTPUT_DIR=../bld

# if we are in the parent of the regress dir, cd to regress:
PWD=`pwd`
thisDir=`basename "$PWD"`
[ "$thisDir" != "regress" -a -d regress ] && cd regress

thisDir=`basename "$PWD"`
if [ "$thisDir" != "regress" ]; then
    echo "WARNING:  jregress results will be written to '$PWD/$JREGRESS_OUTPUT_DIR'"
fi
rm -f "$JREGRESS_OUTPUT_DIR"/regress.log

rm -f $SRCROOT/jregress.properties
cat << EOF > $SRCROOT/jregress.properties
*
* Properties required by ${pkg}.jregress.Tool (a.k.a. jregress)
*
${pkg}.jregress.CMD_ANT=sh $JV_TOOLROOT/bin/cmn/ant -f
${pkg}.jregress.CMD_BSH=java -classpath $JV_TOOLROOT/java/bsh/lib/bsh-1.2b3.jar bsh.Interpreter
${pkg}.jregress.CMD_KSH=sh
${pkg}.jregress.DIFF_CMD=java -D${pkg}.jdiff.IGNORE=yes -Djbi.srcroot=$JV_SRCROOT -classpath $JV_TOOLROOT/java/maven/plugins/jregress-1.0.jar ${pkg}.jdiff.Tool %ref% %out% IGNORE
${pkg}.jregress.SRCROOT=$JV_SRCROOT
${pkg}.jregress.TYPES=ant,bsh,ksh
*
EOF

reffiles=`echo *.ref`
if [ "$reffiles" = '*.ref' ]; then
    havetests=0
else
    havetests=1
fi

#if no args supplied...
if [ -z "$1" ]; then
    #... then calculate test list:
    testlist=`gettestlist`
    if [ -z "$testlist" -a $havetests -ne 0 -a -r jregress.excludes ]; then
        #then we have tests, but they have all been excluded.  Do no run jregress
        #with an empty test list, as this will run all tests instead of none.
        echo `basename ${0}`: Warning: all tests excluded
        exit 0
    fi
else
    testlist=
fi

#if we are running from build harness, reset the deadman timer if it exists:
[ "$RUNBLD_PIDFILE" != "" ] && touch "$RUNBLD_PIDFILE"

exec java -D${pkg}.jregress.LogLevel=SEVERE -D${pkg}.jregress.properties=$JV_SRCROOT/jregress.properties -D${pkg}.jregress.TIMEOUT_SECS=$JREGRESS_TIMEOUT -classpath $JV_TOOLROOT/java/maven/plugins/jregress-1.0.jar ${pkg}.jregress.Tool --output-dir="$JREGRESS_OUTPUT_DIR" "$@" $testlist
