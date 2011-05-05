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
# @(#)comparejars.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# Copyright 2010-2011 Russ Tremain. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#expload two jars and use ddiff to compare the contents

dumpvars()
{
    echo tmpdir=$tmpdir

    echo jarA=$jarA
    echo jardirA=$jardirA
    echo fulljarA=$fulljarA
    echo suffixA=$suffixA

    echo jarB=$jarB
    echo jardirB=$jardirB
    echo fulljarB=$fulljarB
    echo suffixB=$suffixB

	echo using $jarcmd $jararg to explode archive
	echo "ddiff is '$ddiffarg'"
}

################################### USAGE #####################################

usage()
{
    status=$1

    cat << EOF

Usage:  $p [options] archive1 archive2

Compares two jar or tar archives by exploding the archives,
and then running ddiff on the resulting directories.

$p can handle the following suffixes:  $SUFFIX_LIST

Files with .jar, .war, and .zip suffixes are assumed to
be jar archives.

Files with .tgz, .bgz, and .gz suffixes are assumed to
be gzipped tar archives.  Files with .tar suffixes are
assumed to be standard tar archives.

Note that even if the contents of the archives are 
the same, there may be differences in file attributes
(ownership, permission bits, etc) that are not detected.

Options:
 -help        Display this help screen.
 -verbose     show informational messages.
 -f           ignore directories in compare
 -noscm       eliminate CVS, SVN, RCS, SCCS, and git meta-directories from compare.
 -exclude pat exclude files or directories matching pattern, which is a perl RE.
 -tmpdir dir  create temp files and directories relative to <dir> instead of /tmp.

Example:
 $p foo.jar ../foo.jar
 $p -exclude '(tmp.*|.*\.swp)' a.jar b.jar

EOF

    exit $status
}

parse_args()
{
    VERBOSE=0
	ddiffarg=-fdiff
	SUFFIX_LIST="zip,jar,war,tar,tgz,btz,gz"
	TEMPDIR=/tmp

    while [ $# -gt 0 -a "$1" != "" ]
    do
        arg=$1

        case $arg in
        -h* )
            shift
            usage 0
            ;;
        -noscm|-nocvs )
			ddiffarg="$ddiffarg -noscm"
            shift
            ;;
        -v* )
            VERBOSE=1
			ddiffarg="$ddiffarg -v"
            shift
            ;;
        -f )
			ddiffarg="$ddiffarg -f"
            shift
            ;;
        -ex* )
            shift
            if [ $# -gt 0 ]; then
				ddiffarg="$ddiffarg -exclude $1"
                shift
            else
                echo "${p}: -exclude requires a perl regular expression parameter."
                usage 1
            fi
            ;;
        -tmpdir )
            shift
            if [ $# -gt 0 ]; then
				TEMPDIR="$1"
                shift
            else
                echo "${p}: -tmpdir requires a directory name."
                usage 1
            fi
            ;;
        -* )
            echo "${p}: unknown option, $arg"  1>&2
            usage 1
            ;;
        * )
            #preserve remaining args
            break
            ;;
        esac
    done

    #next arg is the first jar:
    if  [ $# -gt 0 -a "$1" != "" ]; then
		fulljarA="$1"
		shift
    else
		bldmsg -error -p $p  missing first archive name
        usage 1
    fi

    #next arg is the second jar:
    if  [ $# -gt 0 -a "$1" != "" ]; then
		fulljarB="$1"
		shift
    else
		bldmsg -error -p $p  missing second archive name
        usage 1
    fi
}

#################################### MAIN #####################################

p=`basename $0`

parse_args "$@"

tmpdir="$TEMPDIR"/$p.$$
mkdir -p $tmpdir

jarA=`basename $fulljarA`
jarB=`basename $fulljarB`

jardirA=$tmpdir/${jarA}
jardirB=$tmpdir/${jarB}

#if the jar names are the same, distinguish the output dirs:
if [ "$jardirA" = "$jardirB" ]; then
	jardirA=$tmpdir/${jarA}_A
	jardirB=$tmpdir/${jarB}_B
fi

#get suffix:
suffixA=`echo $jarA | sed -e 's/.*\.\([^\.]*\)$/\1/g' `
suffixB=`echo $jarB | sed -e 's/.*\.\([^\.]*\)$/\1/g' `

if [ "$suffixA" = "" -o "$suffixB" = "" ] ; then
	bldmsg -error -p $p "arguments must have one of the following suffixes: $SUFFIX_LIST"
	exit 1
fi

if [ "$suffixA" != "$suffixB" ] ; then
	bldmsg -error -p $p "both files must have the same suffix ($suffixA != $suffixB)"
	exit 1
fi

case $suffixA in
jar|zip|war )
	jarcmd=jar; jararg=xf
	;;
tar )
	jarcmd=tar; jararg=xf
	;;
tgz|btz|gz )
	jarcmd=tar; jararg=xzf
	;;
* )
	bldmsg -error -p $p "arguments must have one of the following suffixes: $SUFFIX_LIST"
	exit 1
	;;
esac

[ $VERBOSE -eq 1 ] && dumpvars

#check to see if the archives exist before proceeding:
jarerrs=0
for theJar in $fulljarA $fulljarB
do
	if [ ! -r "$theJar" ]; then
		bldmsg -error -p $p  cannot open $theJar
		jarerrs=1
	fi
done
[ $jarerrs -ne 0 ] && usage 1

rm -rf $jardirA; mkdir -p $jardirA; cp $fulljarA $jardirA
(cd $jardirA; $jarcmd $jararg $jarA; rm -f $jarA)

rm -rf $jardirB; mkdir -p $jardirB; cp $fulljarB $jardirB
(cd $jardirB; $jarcmd $jararg $jarB; rm -f $jarB)

(cd $tmpdir; ddiff $ddiffarg $jardirA $jardirB)

rm -rf $tmpdir
