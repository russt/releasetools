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
# @(#)whatport.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2007 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# whatport
#
#   figure out what port we are on. 
#
#
#

MACH=`uname -m`
status=$?
if [ $status -ne 0 ]; then
    echo NO_UNAME_CMD
    exit 1
fi

case "$MACH" in
    sun4*)
        MACH2=`uname -v`
        if [ $MACH2 -eq "Generic" ]
        then
            echo solsparc
        else
            echo sparc
        fi
        ;;
    00????????00) 
        echo rs6000
        ;;
    i?86|Linux|x86_64)
        case `uname` in
        Linux)
            echo linux
            ;;
        CYGWIN*)
            echo cygwin
            ;;
        Darwin)
            echo macosx
            ;;
        *)
            case `uname -s` in
            DYNIX/ptx)
                echo ptxi86
                ;;
            DYNIX*)
                echo sequent
                ;;
            *)
                echo unknown
                exit 1
                ;;
            esac
            ;;
        esac
        ;;
    9000*) 
        echo hp9000
        ;;
    alpha) 
        echo alphaosf
        ;;
    AViiON)
        MACH2=`uname -p`
        if [ $MACH2 = "Pentium" -o $MACH2 = "PentiumPro" ]
        then
            echo dguxi86
        else 
            echo dgux88k
        fi
        ;;
    RM?00)
        echo snimips
        ;;
    7490|9672)
        echo mvs390
        ;;
    ?86)
        MACH3=`uname -s`
        if [ $MACH3 = "Windows_NT" ]; then
            echo nt
        else
            echo unknown
            exit 1
        fi
        ;;
    i86pc)
        MACH3=`uname -s`
        if [ $MACH3 = "SunOS" ]; then
            echo solx86
        else
            echo unknown
            exit 1
        fi
        ;;
    Power*)
        MACH2=`uname -s`
        if [ $MACH2 = "Darwin" ]
        then
            echo macosx
        else
            echo unknown
            exit 1
        fi
        ;;
    *)
        echo unknown
        exit 1
        ;;
esac

exit 0
