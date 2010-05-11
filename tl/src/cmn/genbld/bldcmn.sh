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
# @(#)bldcmn.sh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# bldcmn.sh - COMMON build routines that can be sourced by build scripts.
#
#  02-Feb-99 (russt)
#       Initial revision
#
# RESERVED VARIABLE NAMES:  ret, status, proc
# these vars names should be considered as volitile names by caller.
#

#DEFINE some basic system parameters, used by this
#module:

export DEVTTY DEVNUL
if [ -c /dev/tty ]; then
    DEVTTY=/dev/tty
    DEVNULL=/dev/null
else
    #mks nt/axpnt/win95 only
    DEVTTY='CONOUT$'
    DEVNULL=nul
fi

#if [ "$p" = "" ]; then
#   p=`basename $0`
#fi
     
bld_killall()
#Usage:  bld_killall [-bg] files and/or dirs ...
#try real hard to get rid of <files and dirs>
#returns 0 if all files and dirs are sucessfully moved aside.
#if -bg, then don't wait for the rm to finish unless the move-aside fails.
{
    killall=0
    proc=bld_killall

#echo "bld_killall=$bg_killall # =$# args=$*"

    bg_killall=0
    verbose_killall=0

    while [ $# -gt 0 -a "$1" != "" ]
    do
        case $1 in
        -bg )
            bg_killall=1
            shift
            ;;
        -v* )
            verbose_killall=1
            shift
            ;;
        * )
            break
            ;;
        esac
    done

    for _kadir in "$@"
    do

        if [ $verbose_killall -eq 1 ]; then
            echo "bld_killall CONSIDERING '$_kadir'"
        fi

        _kafn="`basename $_kadir`"
        if [ "$_kafn" = "." -o "$_kafn" = ".." ]; then
            continue
        fi

        ### ignore non-existent args:
        if [ -f "$_kadir" -o -d "$_kadir" ]; then

            if [ $verbose_killall -eq 1 ]; then
                echo "  bld_killall WORKING ON '$_kadir'"
            fi

            mv "$_kadir" "$_kadir.$$" 2> $DEVNULL
            #if move didn't succeed....
            if [ -f "$_kadir" -o -d "$_kadir" ]; then
                #... then try to remove file or contents of dir:
                err=`2>&1 rm -rf "$_kadir"`
                if [ $? -ne 0 ]; then
                    bldmsg -error -p $proc "failed to fully remove '$_kadir', and could not move aside. [$err]"
                    killall=1
                fi
            else
                #move okay
                if [ $bg_killall -eq 1 ]; then
                    #detach remove job, and don't worry:
                    rm -rf "$_kadir.$$" 2> $DEVNULL &
                else
                    err=`2>&1 rm -rf "$_kadir.$$"`
                    if [ $? -ne 0 ]; then
                        bldmsg -warn -p $proc "$_kadir is gone, but '$_kadir.$$' is not empty, please remove by hand. [$err]"
                        ### note, not an error, since original dir is gone.
                    fi
                fi
            fi
        fi
    done

    return $killall
}

bld_killcontents()
#Usage:  bld_killcontents [-bg] dirs
# kill all the sub-directories and files of <dir>
{
    killcontents=0

    opt_killcontents=

    while [ $# -gt 0 -a "$1" != "" ]
    do
        case $1 in
        -bg|-v* )
            ### this may have trailing whitespace:
            opt_killcontents="$1 $opt_killcontents"
            shift
            ;;
        * )
            break
            ;;
        esac
    done

#echo "bld_killcontents args are $*"

    for _kcdir in "$@"
    do
        if [ ! -d "$_kcdir" ]; then
            bldmsg -warn -p bld_killcontents "$_kcdir is not a directory, and so has no contents."
            continue
        fi

        set "$_kcdir"/.* "$_kcdir"/*

        bld_killall $opt_killcontents "$@"
        if [ $? -ne 0 ]; then
            killcontents=1
        fi
    done

    return $killcontents
}

bld_killdirs()
#Usage:  bld_killdirs [-bg] dirs...
# (this is a now just a wrapper for bld_killall)
{
    killdirs=0

    while [ $# -gt 0 -a "$1" != "" ]
    do
        case $1 in
        -bg|-v* )
            ### this may have trailing whitespace:
            opt_killdirs="$1 $opt_killdirs"
            shift
            ;;
        * )
            break
            ;;
        esac
    done

#echo "bld_killdirs args are $*"

    if [ $# -eq 0 ]; then
        bldmsg -error -p bld_killdirs "must specify one or more directories."
        return 1
    fi

    for _kddir in "$@"
    do
        if [ -d "$_kddir" ]; then
            bld_killall $opt_killdirs "$_kddir"
            if [ $? -ne 0 ]; then
                killdirs=1
            fi
        fi
    done

    return $killdirs
}

bld_killfiles()
#Usage:  bld_killfile files...
#try real hard to get rid of <files>
#returns 0 if all files are sucessfully moved aside.
{
    ret=0
    proc=bld_killfiles

    while [ $# -gt 0 -a "$1" != "" ]
    do
        if [ -f "$1" ]; then
            mv "$1" "$1.$$"
            status=$?
            if [ $status -ne 0 ]; then
                bldmsg -error -p $proc move aside of $1 failed with status $status.
                ret=1
            fi

            #attempt to remove tmp file.
            #
            #NOTE - on NT, rm -f returns 0 status even if file is not removed.
            #however, file will magically disappear later when accessing process is stopped!
            #this happens, for example, when we start the nodemgr from forteboot.ksh, and
            #then call "killfiles forteboot.ksh", and then kill the nodemgr.
            #

            rm -f "$1.$$"
            if [ -f "$1.$$" ]; then
                bldmsg -warn -p $proc could not cleanup $1.$$ - please remove by hand.
            fi
        fi

        shift
    done

    return $ret
}

bld_setup_lockdir()
#set up directories where we read/write lock files.
#returns 0 if no errors
{
    export LOCKDIR
    LOCKDIR=$SRCROOT/bldlock
    export LOCK_READDIR
    LOCK_READDIR=$PATHREF/bldlock

    mkdir -p $LOCKDIR

    return 0
}

bld_setup_logdir_env()
#setup the LOGGING environment variables.
{
    if [ x$REMOTE_LOGBASE != x ]; then
        #if we are doing remote loggin (NT), then we
        #need both a local and remote logdir for regress.
        logbase=$REMOTE_LOGBASE
        if [ x$FORTE_LINKROOT != x ]; then
            local_logbase=$FORTE_LINKROOT
        else
            local_logbase=$SRCROOT
        fi
    elif [ x$FORTE_LINKROOT != x ]; then
        logbase=$FORTE_LINKROOT
    else 
        #default:
        logbase=$SRCROOT
    fi

    #set the build start time in GMT:
    export UBLDSTARTTIME
    UBLDSTARTTIME=`bld_gmttime`

    #set the local build date - used for log directory:
    yymmdd=`date  '+%y%m%d'`
    datedir=$yymmdd

    export LOGROOT LOGDIR LOGDATEFILE REGRESS_LOGDIR REMOTE_REGRESS_LOGDIR REGRESS_FORTE_PORT RUNBLD_PIDFILE
    LOGROOT=$logbase/regress/log
    LOGDATEFILE=$logbase/regress/.date
    RUNBLD_PIDFILE=$logbase/regress/.runbldpid
    LOGDIR=$LOGROOT/$datedir
    cnt=0
    while [ -d $LOGDIR ] 
    do
        cnt=`expr $cnt + 1`
        datedir=${yymmdd}_$cnt
        LOGDIR=$LOGROOT/$datedir
    done

    #for now, continue to use the logdir date as the build number.  RT 11/13/00
    export BUILD_DATE BLDNUM
    BUILD_DATE=$datedir
    BLDNUM=$BUILD_DATE

    #set up the persistent build parameter file names:
    export BLDPARMS LASTBLDPARMS
    BLDPARMS=$LOGDIR/bldparms.sh
    if [ -r $LOGDATEFILE ]; then
        LASTBLDPARMS="$LOGROOT/`cat $LOGDATEFILE`/bldparms.sh"
    else
        #this is the very first build, or .date file is missing:
        bldmsg -warn -p $p "Cannot set LASTBLDPARMS file because $LOGDATEFILE is unreadable."
        LASTBLDPARMS=""
    fi

    #set up build measurement log file:
    export BUILDTIME_LOG
    BUILDTIME_LOG=$LOGDIR/bldtime.log

    if [ x$REGRESS_FORTE_PORT = x ]; then
        REGRESS_FORTE_PORT=$FORTE_PORT
    fi

    #set up regress log dir as well, but don't create it yet:
    if [ x$REMOTE_LOGBASE != x ]; then
        REGRESS_LOGDIR=$local_logbase/regress/$REGRESS_FORTE_PORT/$BUILD_DATE
        REMOTE_REGRESS_LOGDIR=$logbase/regress/$REGRESS_FORTE_PORT/$BUILD_DATE
    else
        REGRESS_LOGDIR=$logbase/regress/$REGRESS_FORTE_PORT/$BUILD_DATE
        REMOTE_REGRESS_LOGDIR=
    fi

    return 0
}

bld_create_logdir()
#create the logdir directory and update .date file.  you must call bld_setup_logdir_env first.
{
    mkdir -p $LOGDIR
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p  "[bld_create_logdir] could not create LOG directory, $LOGDIR"
        return 1
    fi

    rm -f $LOGDATEFILE
    echo $BUILD_DATE > $LOGDATEFILE
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p  "[bld_create_logdir] could not update $LOGDATEFILE"
        return 1
    fi

    rm -f $RUNBLD_PIDFILE
    echo $$ > $RUNBLD_PIDFILE
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p  "[bld_create_logdir] could not update $RUNBLD_PIDFILE"
        return 1
    fi

    #initialize BLDPARMS file:
    shprops -set $BLDPARMS UBLDSTARTTIME=$UBLDSTARTTIME

    if [ -r "$LASTBLDPARMS" ]; then
        #copy the repos update times from the last build parameter file.
        #these times will be possibly be updated by this build:
        grep 'last_update=' $LASTBLDPARMS >> $BLDPARMS

        #forward the last successful build time:
        grep 'ULASTGOODBLDTIME=' $LASTBLDPARMS >> $BLDPARMS
    fi

    return 0
}

bld_setup_logdir()
#set up logging so buildResults will work
#returns 0 if no errors
{
    bld_setup_logdir_env
    if [ $? -ne 0 ]; then
        return 1
    fi
    bld_create_logdir
    if [ $? -ne 0 ]; then
        return 1
    fi
    return 0
}

bld_reset_watchdog()
#just reset the time on the pid file.  the mod time on this file
#is used to determine if the build is still running or not
{
    if [ x$RUNBLD_PIDFILE = x ]; then
        bldmsg -warn -p $p "[bld_reset_watchdog] you must call bld_setup_logdir first"
        return 1
    fi

    touch $RUNBLD_PIDFILE
    if [ $? -ne 0 ]; then
        bldmsg -error -p $p  "[bld_reset_watchdog] could not reset time on $RUNBLD_PIDFILE"
        return 1
    else
        bldmsg -p $p  "[bld_reset_watchdog] reset watchdog timer file $RUNBLD_PIDFILE"
        echo `ls -l $RUNBLD_PIDFILE`
    fi

    return 0
}

bld_gmttime()
#show the GMT time.  We use perl because "date -u" doesn't always work.
{
perl -e '@T = gmtime(time); printf "%04d%02d%02d%02d%02d%02d\n",$T[5]+1900,$T[4]+1,$T[3],$T[2],$T[1],$T[0];'
}

bld_tocvstime()
{
  _UCVSTIME=$1; shift
  export _UCVSTIME _YEAR _MONTH _DAY _TIME _MONTHSTR

_YEAR=`echo $_UCVSTIME | sed -e 's|^\(....\).*|\1|'`
_MONTH=`echo $_UCVSTIME | sed -e 's|^\(....\)\(..\).*|\2|'`
_DAY=`echo $_UCVSTIME | sed -e 's|^\(....\)\(..\)\(..\).*|\3|'`
_TIME=`echo $_UCVSTIME | sed -e 's|.*\(..\)\(..\)\(..\)$|\1:\2:\3|'`

_MONTHSTR=`perl -e '@MONTH=("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ); printf "%s",$MONTH[int($ENV{"_MONTH"})-1];'`

echo "$_DAY $_MONTHSTR $_YEAR $_TIME UTC"

}

bld_get_cvs_module_defs()
# get the list of directories associated with a cvs module def.
# up to the caller to make sure the target contains only directories and not
# other module aliases.
{
    _cvsroot=$1; shift

    if [ "$_cvsroot" = "" -o "$1" = "" ]; then
        echo "Usage:  get_cvs_module_dirs cvsroot module_name [module_name ...]"
        return 1
    fi

    tmpA=/tmp/${p}_tmpA.$$
    tmpB=/tmp/${p}_tmpB.$$

    cvs -f -q -r -d $_cvsroot co -p CVSROOT/modules  > $tmpA 2> $tmpB
    status=$?

    if [ $status -ne 0 ]; then
        bldmsg -p $p/get_cvs_module_dirs -error "CANNOT RETREIVE modules file from $_cvsroot, Error is:"
        echo "    `cat $tmpB`"
        rm -f $tmpA $tmpB
        return 1
    fi

    for _module in $*
    do
        # the first edit standardizes spacing (\s+ -> ' ')
        # the grep pulls out our module_name from the modules def
        # the final edit eliminates module_name from the output
        sed -e :a -e '/\\$/N; s/\\\n//; ta' $tmpA | sed -e 's/[     ][      ]*/ /g'| grep "^$_module -a" | sed -e "s/^$_module -a //" > $tmpB

        if [ -z $tmpB ]; then
            bldmsg -p $p -error "cannot find '$_module' target in modules file from $_cvsroot"
            rm -f $tmpA $tmpB
            return 1
        fi

        cat $tmpB
    done

    rm -f $tmpA $tmpB
    return 0
}

bld_fatal_error()
{
    bldmsg -p $p -error $*

    #if we have set up the showtimes log...
    if [ -r $BUILDTIME_LOG ]; then
        bldmsg -markend -status 1 $p
    fi

    set +e
    #we expect a cleanup routine to be defined by the caller:
    cleanup

    exit 1
}

bld_fterr()
#usage:  myfortescript | bld_fterr
#return 1 if we find a forte system error in the input.
#NOTE - this routine uses local variables only.
{
    set bld_fterr
    set $1 /tmp/$1.$$
    tee $2
    grep "SYSTEM ERROR" $2 > $DEVNULL
    if [ $? -eq 0 ]; then
        rm -f $2
        return 1
    fi

    rm -f $2
    return 0
}


bld_check_usepath()
#check the usePathDef environment.
#return 0 if we're reasonably sure that usePath has been run.
{
    usepatherrs=0

    if [ x$TOOLROOT = x ]; then
        echo BUILD_ERROR:  TOOLROOT not set.
        usepatherrs=1
    fi

    if [ x$DISTROOT = x ]; then
        echo BUILD_ERROR:  DISTROOT not set.
        usepatherrs=1
    fi

    if [ x$SRCROOT = x ]; then
        echo BUILD_ERROR:  SRCROOT not set.
        usepatherrs=1
    fi

    if [ x$PATHREF = x ]; then
        echo BUILD_ERROR:  PATHREF not set.
        usepatherrs=1
    fi

    if [ x$PRIMARY_PORT = x ]; then
        echo BUILD_ERROR:  PRIMARY_PORT not set.
        usepatherrs=1
    fi

    if [ x$RELEASE_DISTROOT = x ]; then
        echo BUILD_ERROR:  RELEASE_DISTROOT not set.
        usepatherrs=1
    fi

    if [ x$RELEASE_ROOT = x ]; then
        echo BUILD_ERROR:  RELEASE_ROOT not set.
        usepatherrs=1
    fi

    if [ x$HOST_NAME = x ]; then
        echo BUILD_ERROR:  HOST_NAME not set.
        usepatherrs=1
    fi

    if [ x$KITROOT = x ]; then
        echo BUILD_ERROR:  KITROOT not set.
        usepatherrs=1
    fi

    if [ x$KIT_DISTROOT = x ]; then
        echo BUILD_ERROR:  KIT_DISTROOT not set.
        usepatherrs=1
    fi

    if [ x$REGRESS_DISPLAY = x ]; then
        echo BUILD_ERROR:  REGRESS_DISPLAY not set.
        usepatherrs=1
    fi

    if [ x$CVS_BRANCH_NAME = x ]; then
        echo BUILD_ERROR:  CVS_BRANCH_NAME not set
        usepatherrs=1
    fi

    if [ x$FORTE_LINKROOT = x ]; then
        echo BUILD_WARNING: FORTE_LINKROOT not set, build and log output will go in SRCROOT
    fi

    if [ $usepatherrs -ne 0 ]; then
        return 1
    fi

    return 0
}

bld_set_builder_profile()
{
    export DEVELOPER_BUILD RELEASE_BUILD
    if [ x$DEVELOPER_BUILD = x ]; then
        DEVELOPER_BUILD=0
    fi

    if [ x$RELEASE_BUILD = x ]; then
        RELEASE_BUILD=0
    fi

    if [ $RELEASE_BUILD -eq 1 -a $DEVELOPER_BUILD -eq 1 ]; then
        bldmsg -warn -p $p "conflicting settings for RELEASE_BUILD and DEVELOPER_BUILD (both 1)..."
        bldmsg "...defaulting to DEVELOPER_BUILD."
        RELEASE_BUILD=0
    fi

    if [ $RELEASE_BUILD -eq 0 -a $DEVELOPER_BUILD -eq 0 ]; then
        bldmsg -warn -p $p "conflicting settings for RELEASE_BUILD and DEVELOPER_BUILD (both 0 or undefined)..."
        bldmsg "...defaulting to DEVELOPER_BUILD."
        DEVELOPER_BUILD=1
    fi
}

bld_show_env()
{
    cat << EOF
BUILD ENVIRONMENT FOR $p -
    FORTE_PORT is   $FORTE_PORT
    HOST_NAME is    $HOST_NAME
    PRIMARY_PORT is $PRIMARY_PORT 
    REGRESS_FORTE_PORT is   $REGRESS_FORTE_PORT
    SRCROOT is  $SRCROOT
    PATHREF is  $PATHREF
    FORTE_LINKROOT is   $FORTE_LINKROOT
    DISTROOT (tools) is $DISTROOT
    TOOLROOT is $TOOLROOT
    RELEASE_ROOT is $RELEASE_ROOT
    RELEASE_DISTROOT is $RELEASE_DISTROOT
    KITROOT is  $KITROOT
    KIT_DISTROOT is $KIT_DISTROOT
    REGRESS_DISPLAY is $REGRESS_DISPLAY
    LOCKDIR is  $LOCKDIR

    CVSROOT is $CVSROOT
    CVS_BRANCH_NAME is $CVS_BRANCH_NAME

    BUILD_DATE is   $BUILD_DATE
    LOGDIR is   $LOGDIR
    REGRESS_LOGDIR  is  $REGRESS_LOGDIR
    REMOTE_REGRESS_LOGDIR   is  $REMOTE_REGRESS_LOGDIR
EOF
}
 
bld_is_windows_port()
# Input: one lower case FORTE_PORT parameter.
# Output: This function will print "1" if the give port is a windows port,
# "0" otherwise.
{
    case $1 in
      ntcmn|nt|axpnt)
        echo 1
        ;;
      *)
        echo 0
        ;;
    esac
}
 
bld_dated_name()
# Input: optionally give a string to prepend and append the dated name with.
# If none is given the current directory and no prefix to the date is assumed.
#
# Output: Echo a name which does not currently exist as a file or directory.
# Note that this function is not atomic and does no locking.  After
# receiving a name from this function quickly create a file or directory
# with that name to prevent another process from using it as well.
#
# Example:
#      To created a dated direcory one might execute
#      "mkdir -p `bld_dated_name  /tmp/foo/`"
#
#      "bld_dated_name" might echo "990828"
#      "bld_dated_name  '' _post" might echo "990828_post"
#      "bld_dated_name  nt_" might echo "nt_990828"
#      "bld_dated_name  /rmstage2/mailine/nt_" might echo
#          "/rmstage2/mailine/nt_990828"
#      A second run of "bld_dated_name  /rmstage2/mailine/nt_" might echo
#          " /rmstage2/mailine/nt_990828_1"
{
    # Note: head my be set to the empty string.
    bldcmn_head=$1
    bldcmn_tail=$2

    bldcmn_date=`date  '+%y%m%d'`

    bldcmn_name=${bldcmn_head}${bldcmn_date}${bldcmn_tail}
    bldcmn_date_ext_cnt=0

    #This should work but doesn't on unix: while [ -e foo${bldcmn_name} ]; do
    #This works but is hard coded: while /usr/bin/test -e ${bldcmn_name} ; do
    #This should work but doesn't on unix: while test -e foo${bldcmn_name}; do
    while [ -f ${bldcmn_name} -o -d ${bldcmn_name} ]; do
            bldcmn_date_ext_cnt=`expr $bldcmn_date_ext_cnt + 1`
        bldcmn_name=${bldcmn_head}${bldcmn_date}_${bldcmn_date_ext_cnt}${bldcmn_tail}
    done
    echo $bldcmn_name
}   

bld_check_create_tmp()
{
    if [ ! -d "/tmp" ]; then
        mkdir -p /tmp
    fi
}
