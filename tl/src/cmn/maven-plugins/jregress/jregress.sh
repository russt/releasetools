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
# Copyright 2004-2007 Sun Microsystems, Inc. All Rights Reserved.
#
# END_HEADER - DO NOT EDIT
#

################################ USAGE ROUTINES ################################

usage()
{
    status=$1

    cat << EOF
Usage:  $p [options...] [tests...]

 Driver for java regression tool, jregress.

Options:
 -help            Display this message.
 -H               Display detailed jregress tool help.
 -n               Show the jregress command line, but do not execute it.

 -loglevel level  Set jregress log level to <level>, which must be one of:
                    {OFF, SEVERE, WARNING, INFO, CONFIG, FINE, FINER, FINEST, ALL}
                  Default loglevel is $loglevel

 -timeout n       Set jregress timeout to <n> seconds.  Current value is $JREGRESS_TIMEOUT seconds.

Files:
 jregress.includes   File containing sorted list of tests to include.  If this file is
                     present but contains no valid test names, then no tests will run.
                     Lines starting with comment char (#) will be ignored.
 jregress.excludes   File containing sorted list of tests to skip. Lines starting
                     with comment char (#) will be ignored.

 NOTE:  If both jregress.includes and jregress.excludes are present, then the list
        of tests named by the exclude file will be subtracted from the include file.
 NOTE:  The jregress.includes and jregress.excludes must live in the current directory
        that $p is run from, or in an immediate sub-directory named "regress".
        
Environment:
 JV_SRCROOT          Root of the checked-out sources.
 JV_TOOLROOT         Where the tools live
 JREGRESS_TIMEOUT    How long to wait for a single test.  Default is $JREGRESS_TIMEOUT seconds.
 JREGRESS_OUTPUT_DIR The output directory for jregress results, including regress.log summary.

Outputs:
 For each failed test, <test>.out, <test.err>, <test.dif>, showing stdout, stderr, and
 diff results, respectively.  These files normally appear in $JREGRESS_OUTPUT_DIR, and
 normally only appear when a test fails (but see jregress -H for exceptions).

 The jregress internal log files appear in /tmp.  If you increase the log-level, look for
 the log messages in the system tmp dir.  File name will be of the form: "jregress_g0_nnn_u0.log".

Examples:
 $p -n
   Show the command-line generated to execute the jregress tool.  This is a good
   way to verify the jregress properties, and test the parsing of the
   jregress.includes/jregress.excludes files:
 $p -H
   Show a more detailed help message from the jregress tool.
 $p
   Run all regression tests found in the current directory hierarchy.
   This should normally be run in a directory named 'regress'.

EOF

    exit $status
}

parse_args()
{
    DOHELP=0
    TESTMODE=0
    JREGRESS_ARGS=
    JREGRESS_TEST_LIST=
    SHOW_JREGRESS_HELP=0

    while [ $# -gt 0 -a "$1" != "" ]
    do
        arg=$1; shift

        case $arg in
        -h* )
            usage 0
            ;;
        -n )
            TESTMODE=1
            ;;
        -loglevel )
            if [ $# -gt 0 ]; then
                loglevel=$1; shift
            else
                echo "${p}: -loglevel requires an argument" 2>&1
                usage 1
            fi
            ;;
        -timeout )
            if [ $# -gt 0 ]; then
                JREGRESS_TIMEOUT=$1; shift
            else
                echo "${p}: -timeout requires an argument" 2>&1
                usage 1
            fi
            ;;
        -* )
            #pass along any unkown args to jregress:
            if [ -z "$JREGRESS_ARGS" ]; then
                JREGRESS_ARGS="'$arg'"
            else
                JREGRESS_ARGS="$JREGRESS_ARGS '$arg'"
            fi
            case $arg in
            -H|--help|--help-detailed|-u|--usage|-x|--examples )
                SHOW_JREGRESS_HELP=1
                ;;
            esac
            ;;
        * )
            #we assume any remaining arguments are test names:
            if [ -z "$JREGRESS_TEST_LIST" ]; then
                JREGRESS_TEST_LIST="'$arg'"
            else
                JREGRESS_TEST_LIST="$JREGRESS_TEST_LIST '$arg'"
            fi
            ;;
        esac
    done

#echo parse_args:  JREGRESS_ARGS=">$JREGRESS_ARGS<"
#echo parse_args:  JREGRESS_TEST_LIST=">$JREGRESS_TEST_LIST<"
}

################################ UTIL ROUTINES #################################

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

init()
{
    p=`basename $0`

    #these variables reak havoc with the JDK under mks:
    unset TMP
    unset tmp
    pkg=com.sun.jbi.internal.tools

    [ -z "$JV_SRCROOT" ] && JV_SRCROOT=$SRCROOT
    [ -z "$JV_TOOLROOT" ] && JV_TOOLROOT=$TOOLROOT
    [ -z "$JREGRESS_TIMEOUT" ] && JREGRESS_TIMEOUT=400
    [ -z "$JREGRESS_OUTPUT_DIR" ] && JREGRESS_OUTPUT_DIR=../bld

    #default log-level:
    loglevel=SEVERE

    JREGRESS_PROPS="$JREGRESS_OUTPUT_DIR/jregress.properties"
}

##################################### MAIN #####################################

init
parse_args "$@"

showcmd=
[ $TESTMODE -eq 1 ] && showcmd="echo "

###
#if we are just asking for help, avoid generating prop file and output dir:
###
if [ $SHOW_JREGRESS_HELP -eq 1 ]; then
    cmd="${showcmd}java -D${pkg}.jregress.LogLevel=$loglevel -D${pkg}.jregress.TYPES= -D${pkg}.jregress.DIFF_CMD= -classpath $JV_TOOLROOT/java/maven/plugins/jregress-1.0.jar ${pkg}.jregress.Tool $JREGRESS_ARGS"

    eval $cmd
    exit $?
fi

# if we are in the parent of the regress dir, cd to regress:
PWD=`pwd`
thisDir=`basename "$PWD"`
if [ "$thisDir" != "regress" -a -d regress ]; then
    echo "WARNING:  will run from 'regress' sub-directory." 2>&1
    cd regress
fi

reffiles=`echo *.ref`
if [ "$reffiles" = '*.ref' ]; then
    havetests=0
else
    havetests=1
fi

#if no args supplied...
if [ -z "$JREGRESS_TEST_LIST" ]; then
    #... then calculate test list:
    testlist=`gettestlist`
    if [ -z "$testlist" -a $havetests -eq 1 ]; then
        if [ -r jregress.excludes -o -r jregress.includes ]; then
            #then we have tests, but they have all been excluded.  Do no run jregress
            #with an empty test list, as this will run all tests instead of none.
            echo ${p}: WARNING: all tests excluded, `pwd` 2>&1
            exit 0
        fi
    fi
else
    testlist=$JREGRESS_TEST_LIST
fi

######
#NOTE: jregress log messages are logged to a file in /tmp, e.g., /tmp/jregress_g0_1196128771204_u0.log
######

#############
#check/create output dir:
#############
thisDir=`basename "$PWD"`
if [ "$thisDir" != "regress" ]; then
    echo "WARNING:  not running in a 'regress' dir." 2>&1
fi

if [ ! -d "$JREGRESS_OUTPUT_DIR" ]; then
    mkdir -p "$JREGRESS_OUTPUT_DIR"
    if [ -d "$JREGRESS_OUTPUT_DIR" ]; then
        echo "WARNING:  created jregress output directory: '$JREGRESS_OUTPUT_DIR'." 2>&1
    else
        echo "ERROR:  cannot create jregress output directory: '$JREGRESS_OUTPUT_DIR'." 2>&1
        exit 1
    fi
fi

#########
#generate properties file:
#NOTE:  all test file suffixes jregress.TYPES must be 3 characters in length.
#       (i.e., "cgt", but not "cg").  RT 11/27/07
#########

rm -f "$JREGRESS_PROPS"
cat << EOF > "$JREGRESS_PROPS"
*
* Properties required by ${pkg}.jregress.Tool (a.k.a. jregress)
* note that beanshell support only works if maven downloads it.  RT 2/14/08
*
${pkg}.jregress.TYPES=ant,bsh,cgt,gvy,ksh
${pkg}.jregress.CMD_ANT=sh ${JV_TOOLROOT}/bin/cmn/ant -f
${pkg}.jregress.CMD_BSH=java -classpath ${JV_SRCROOT}/m2/repository/bsh/bsh/1.3.0/bsh-1.3.0.jar bsh.Interpreter
${pkg}.jregress.CMD_CGT=sh ${JV_TOOLROOT}/bin/cmn/codegen -u
${pkg}.jregress.CMD_GVY=sh ${JV_TOOLROOT}/java/groovy/bin/groovy
${pkg}.jregress.CMD_KSH=sh
*
${pkg}.jregress.DIFF_CMD=java -D${pkg}.jdiff.IGNORE=yes -Djbi.srcroot=$JV_SRCROOT -classpath $JV_TOOLROOT/java/maven/plugins/jregress-1.0.jar ${pkg}.jdiff.Tool %ref% %out% IGNORE
${pkg}.jregress.SRCROOT=$JV_SRCROOT
*
*document properties passed on command line:
*  ${pkg}.jregress.TIMEOUT_SECS=$JREGRESS_TIMEOUT
*  ${pkg}.jregress.LogLevel=$loglevel
*  ${pkg}.jregress.properties=$JREGRESS_PROPS
*
EOF

#start with a clean test result log:
rm -f "$JREGRESS_OUTPUT_DIR"/regress.log

#if we are running from build harness, reset the deadman timer if it exists:
[ "$RUNBLD_PIDFILE" != "" ] && touch "$RUNBLD_PIDFILE"

cmd="${showcmd}java -D${pkg}.jregress.LogLevel=$loglevel -D${pkg}.jregress.properties='$JREGRESS_PROPS' -D${pkg}.jregress.TIMEOUT_SECS=$JREGRESS_TIMEOUT -classpath '$JV_TOOLROOT'/java/maven/plugins/jregress-1.0.jar ${pkg}.jregress.Tool --output-dir='$JREGRESS_OUTPUT_DIR' $JREGRESS_ARGS $testlist"

eval $cmd
exit $?
