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
# @(#)rj.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
#
# END_HEADER - DO NOT EDIT
#

# rj - script to run a java command

usage()
{
    status=$1

    cat << EOF

Usage:  $p [options] javacmd javaargs

Looks for a java class named <javacmd>.class
in each directory defined in \$JAVACOMMANDPATH.

Options:
 -help        Display this help screen.
 -verbose     show informational messages.
 -update      recompile if <javacmd>.class is out of date (default).
 -f           force recompile
 -noupdate    do not recompile.

Environment:
 JAVACOMMANDPATH    semi-colon separated list of places to look for java classes

Example:
 setenv JAVACOMMANDPATH "~/bin;."
 $p foo fooargs

EOF

    exit $status
}


#################################### MAIN #####################################

p=`basename $0`

#parse_args()
#NOTE - this is not a subroutine, because we need to adjust the global $@ arg vector
#{
    DOHELP=0
    VERBOSE=0
    COMPILE=1
    FORCECOMPILE=0

    # Set the default command path if none specified
    if [ -z "$JAVACOMMANDPATH" ] ; then
        export JAVACOMMANDPATH
        JAVACOMMANDPATH="."
    fi

    while [ $# -gt 0 -a "$1" != "" ]
    do
        arg=$1

        case $arg in
        -h* )
            shift
            usage 0
            ;;
        -u* )
            COMPILE=1
            shift
            ;;
        -f* )
            FORCECOMPILE=1
            COMPILE=1
            shift
            ;;
        -n* )
            COMPILE=0
            shift
            ;;
        -v* )
            VERBOSE=1
            shift
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

    #next arg is the command to run:

    if  [ $# -gt 0 -a "$1" != "" ]; then
        javacmd=$1
        shift
    else
        usage 1
    fi

#   echo "AFTER PARSE args are '$@'"
#}

### foreach directory in PATH variable...
for dd in `echo $JAVACOMMANDPATH | tr ';' ' '`
do
    ### note - we eval the directory name to expand tilde (~).
    dd=`eval echo $dd`

    ff=$dd/${javacmd}.class
    src=$dd/${javacmd}.java
    [ $VERBOSE -eq 1 ] && echo looking for $ff  1>&2

    if [ -z "$CLASSPATH" ]; then
        export CLASSPATH; CLASSPATH=$dd
    else
        CLASSPATH="${dd}:$CLASSPATH"
    fi

    #if we are on cygwin, convert path:
    if [ -x /bin/cygpath ]; then
        CLASSPATH=`cygpath -m "$CLASSPATH"`
    fi

    if [ $FORCECOMPILE -eq 1 ]; then
        (cd $dd; rm -f ${javacmd}.class)
    fi

    if [ $COMPILE -eq 1 -a -f $src ]; then
        uptodate=1
        if [ ! -f $ff ]; then
            uptodate=0
        else
            #have to compare timestamps
            for xx in `\ls -t $ff $src`
            do
                if [ $xx = $src ]; then
                    uptodate=0
                fi
                break;
            done
        fi

        if [ $uptodate -eq 0 ]; then
            echo "Compiling $src" 1>&2
            (cd $dd; rm -f ${javacmd}.class; javac ${javacmd}.java)
        else
            [ $VERBOSE -eq 1 ] && echo $ff is up to date 1>&2
        fi
    fi

    if [ -f $ff ]; then
        [ $VERBOSE -eq 1 ] && echo "executing $ff with args '$@' CLASSPATH='$CLASSPATH'"  1>&2
        [ $VERBOSE -eq 1 ] && echo "java $javacmd $@"  1>&2
        exec java $javacmd "$@"
    fi
done

echo "${p}: ${javacmd}.class not found in JAVACOMMANDPATH '$JAVACOMMANDPATH'"  1>&2
exit 1
