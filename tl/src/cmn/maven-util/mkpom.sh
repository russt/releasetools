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
# @(#)mkpom.sh - ver 1.1 - 01/04/2006
#
# Copyright 2006-2009 Sun Microsystems, Inc.  All Rights Reserved.
# Copyright 2010 Russ Tremain.  All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#mkpom - create an maven 1.x or 2.x  pom using cado templates

############################### USAGE ROUTINES ################################

usage()
{
    status=$1

    cat << EOF

Usage:  $p [options...] [pom.defs ...]

 Create an maven 1.x project.xml pom or a maven 2.x pom.xml file
 from declarative specification in <pom.defs>.

 If pom.defs is missing, generate a full maven pom.

Options:
 -help           Display this message.
 -verbose        Run cado in verbose mode.
 -debug          Run cado in debug mode.
 -doc            Show documentation for pom.defs declarations.
 -e              Pass environment to cado.
 -m1             Generate maven 1.x project.xml file
 -m2             Generate maven 2.x pom.xml file (default)
 arg=value       Add an environment definition to pass to cado (can be repeated).
                 Implies -e option.

Environment:
 CG_TEMPLATE_PATH    location of maven templates - see: cado -help

Example:
 $p mypom.defs > pom.xml

EOF

    exit $status
}

parse_args()
{
    DOHELP=0
    VERBOSE=0
    DEBUG=0
    SHOWDOC=0
    MAVEN_TEMPLATE_DIR=maven2
    POM_DEFS=
    PASS_ENV=0

    while [ $# -gt 0 -a "$1" != "" ]
    do
        arg=$1; shift

        case $arg in
        -h* )
            usage 0
            ;;
        -doc )
            SHOWDOC=1
            ;;
        -debug )
            DEBUG=1
            ;;
        -e )
            PASS_ENV=1
            ;;
        -m1 )
            MAVEN_TEMPLATE_DIR=maven
            ;;
        -m2 )
            MAVEN_TEMPLATE_DIR=maven2
            ;;
        -v* )
            VERBOSE=1
            ;;
        -* )
            echo "${p}: unknown option, $arg"
            usage 1
            ;;
        *=* )
            tmp=`echo $arg|sed -e 's/"/\\\\"/g'`
            #echo A arg=.$arg. tmp is .$tmp.
            tmp=`echo $tmp|sed -e 's/^\([^=][^=]*\)=\(.*\)/\1="\2"; export \1/'`
            #echo B tmp is .$tmp.
            eval $tmp

            #force cado to run with -e, to avoid re-quoting problems.  RT 10/24/06
            PASS_ENV=1
            ;;
        * )
            POM_DEFS="$arg"
            break
            ;;
        esac
    done
}

################################# HOUSEKEEPING #################################

cleanup()
{
    if [ x$TMPA != x ]; then
        rm -f $TMPA
    fi
}

rec_signal()
{
    cleanup
    echo $p Interrupted

    exit 2
}

#################################### MAIN #####################################

p=`basename $0`

parse_args "$@"

cgargs=
[  $VERBOSE -eq 1 ] && cgargs="$cgargs -v"
[    $DEBUG -eq 1 ] && cgargs="$cgargs -d"
[ $PASS_ENV -eq 1 ] && cgargs="$cgargs -e"

if [ $SHOWDOC -eq 1 ]; then
    #then show variable documentation:
cado $cgargs -u -cgroot . << EOF
%readtemplate ECHO_TXT $MAVEN_TEMPLATE_DIR/maven_lib_doc.txt
%echo \$ECHO_TXT
EOF

    exit $?
fi

TMPA=/tmp/${p}A.$$

if [ "$POM_DEFS" = "" ]; then
    POM_DEFS=null
    GENERATE_EMPTY_ELEMENTS=1
else
    GENERATE_EMPTY_ELEMENTS=0
fi

####
#run cado to generate maven files:
####
cado $cgargs -u -cgroot . << EOF
#use standard template to generate maven project.xml (pom) files:
%include $MAVEN_TEMPLATE_DIR/maven_lib.cg
%include $POM_DEFS

#set/clear the output accumulator
MACRO_OUTPUT_ACCUMULATOR =	ECHO_TXT
\$MACRO_OUTPUT_ACCUMULATOR =
MAVEN_GENERATE_EMPTY_ELEMENTS = $GENERATE_EMPTY_ELEMENTS

%call xml_header
%call maven_project

%echo \$ECHO_TXT
EOF

status=$?
exit $status
