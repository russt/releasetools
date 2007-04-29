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
# @(#)jartoc.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
#
# END_HEADER - DO NOT EDIT
#

usage()
{
    status=$1

    cat << EOF

Usage:  $p [options] jarfile...

Display the contents of a list of jar files,
and optionally dump the manifest for each file.

Options:
 -help     Display this help screen.
 -verbose  show informational messages.
 -m        display manifest of each jar.
 -t        display table-of-contents of each jar (DEFAULT)

Notes:
 -m option requires that you run $p in a directory where we can
    write-over the META-INF sub-directory.

Example:
 Display manifest of foo.jar:
     $p -m foo.jar

 Display verbose manifest and table of contents of jars in local directory:
     $p -v -m -t *.jar

EOF

    exit $status
}

parse_args()
{
    DOHELP=0
    DOTOC=1
    DOMANIFEST=0
    VERBOSE=0

    while [ $# -gt 0 -a "$1" != "" ]
    do
        arg=$1

        case $arg in
        -h* )
            shift
            usage 0
            ;;
        -t )
            DOTOC=1
            shift
            ;;
        -m )
            DOMANIFEST=1
            DOTOC=0
            shift
            ;;
        -v* )
            VERBOSE=1
            shift
            ;;
        -* )
            1>&2 echo "${p}: unknown option, $arg"
            usage 1
            ;;
        * )
            #preserve remaining args
            break
            ;;
        esac
    done

    if [ $DOMANIFEST -eq 1 -a -d META-INF ]; then
        1>&2 echo "${p}: you must run from dir without META-INF sub-dir when using -m option"
        usage 1
    fi

    if  [ $# -gt 0 -a "$1" != "" ]; then
        JARFILES="$@"
    else
        usage 1
    fi
}

#################################### MAIN #####################################

p=`basename $0`

parse_args "$@"

for jar in $JARFILES
do
    if [ $DOMANIFEST -eq 1 ]; then
        jar xf $jar META-INF/MANIFEST.MF
        if [ $? -eq 0 ]; then
            [ $VERBOSE -eq 1 ] && echo ------------- $jar/META-INF/MANIFEST.MF -------------
            cat META-INF/MANIFEST.MF
            [ $VERBOSE -eq 1 ] && echo -------------
        else
            2>&1 echo ${p}: error extracting META-INF/MANIFEST.MF from $jar
        fi
        rm -rf META-INF
    fi
    if [ $DOTOC -eq 1 ]; then
        jar tf $jar | sed -e "s|^|$jar  |"
    fi
done
