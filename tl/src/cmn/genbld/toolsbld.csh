#!/bin/tcsh
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
# @(#)toolsbld.csh - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
#toolsBuild - script to run tools build in a standard way, combining
#             tools build from multiple projects into a single distribution.
#
#NOTE - requires a login with VSPMS (chpj aliases) installed.
#NOTE - requires tcsh.
#
#WARNING:  tools distributions have to be partitioned amoung projects.
#          i.e., cannot have multiple projects populating a common distribution
#          directory.
#
# ENVIRONMENT:
#   TARGET_OS_LIST - builds tools for these platforms if defined,
#       otherwise, uses bldhost command to determine.
#
#   AUX_TOOLS_PJLIST - space-separated list of tools projects to build,
#       in addition to the local tools build (in bdb/$LOCAL_MMF_CMN).
#
#   bdb/projects    - each project referenced in AUX_TOOLS_PJLIST must be
#       defined in this projects file.  (becomes $MYPROJECTS file for VSPMS)
#
#   bdb/<pj>.cmn    - bdb to build each <pj> listed in AUX_TOOLS_PJLIST.
#       this bdb is defined for the local $SRCROOT.
#
#   Environment required by tooldist2git:
#       CVS_TOOLDIST_PATH - base of cvs tools distribution repository, eg. $DISTROOT
#       GIT_TOOLDIST_PATH - base of git tools distribution repository
#       GIT_TOOLDIST_WORK - base of git working directories, used to sync the cvs tools modules to git branches
#

set p=`basename $0`
unset noclobber
set exit = 1

#########
# options:
set TESTMODE = 0
set DOCLEAN = 0
set DOPULL = 0
set DOCVSUPDATE = 0
set LOCALONLY = 0
set NONLOCALONLY = 0
set DOPRINTMAP = 1
set DOPRINTMAPONLY = 0
set DOREADYFILE = 0
set READYFILE = ""
set CLEANDIST = 1
set DOLOCALCVSUPDATE = 1
set DOGITSYNC = 1
#########

if (! $?LOCAL_MMF_CMN ) then
    set local_mmf_cmn = mmf.cmn
else
    set local_mmf_cmn = "$LOCAL_MMF_CMN"
    bldmsg -p $p "BUILD_INFO: will use bdb $local_mmf_cmn for local tools build."
endif

set TMP_BDBDIR = /tmp/bdb.$p.$$
set TMP_BDBFN = $TMP_BDBDIR/$p.cmn
set TMPA = /tmp/${p}_A.$$
mkdir -p $TMP_BDBDIR

while ( $#argv > 0 )
    set arg=$1; shift

    switch ($arg)
        case -h*:
            set exit = 0
            goto USAGE
        case -test:
            set TESTMODE = 1
            breaksw
        case -skip_local_update:
            set DOLOCALCVSUPDATE = 0
            breaksw 
        case -clean:
            #NOTE - this is currently not safe.  re-enable when I figure out
            #how cvs clients can detect re-initialized repositories.  RT 10/25/00
            bldmsg -warn -p $p "-clean not implemented for CVS distributions"
            set DOCLEAN = 0
            breaksw
        case -dopull:
            set DOPULL = 1
            breaksw
        case -update:
        case -cvsupdate:
            set DOCVSUPDATE = 1
            breaksw
        case -localonly:
            set LOCALONLY = 1
            set NONLOCALONLY = 0
            breaksw
        case -nonlocalonly:
            set LOCALONLY = 0
            set NONLOCALONLY = 1
            breaksw
        case -noprintmap:
            set DOPRINTMAP = 0
            breaksw
        case -readyfile
            set DOREADYFILE = 1
            if ( $#argv > 0 ) then
                set READYFILE=$1; shift
            else
                echo "${p}:  -readyfile option requires a file name parameter"
                goto USAGE
            endif
            breaksw
        case -printmaponly:
            set DOPRINTMAPONLY = 1
            breaksw
        case -gitsync:
            set DOGITSYNC = 1
            breaksw
        case -nogitsync:
            #git sync is on by default if tooldist2git env. variables are defined.
            set DOGITSYNC = 0
            breaksw
        case -*:
            echo "${p}:  unrecognized option, $arg"
            goto USAGE
            breaksw
        default:
            echo $arg >> $TMP_BDBFN
            breaksw
    endsw
end

goto ARGSOK

USAGE:
cat << EOF
Usage:  $p [-help] [-test]  [-clean] [-dopull] [-readyfile flagfile]
                   [-localonly] [-nonlocalonly] [-noprintmap]
                   [-printmaponly] [-readyfile flagfile] [-update]
                   [-gitsync] [-nogitsync]
                   directories...

 Build a tools distribution from one or more projects.

Options:

 -help         display this usage message.
 -test         Run $p in non-destructive test mode.
               Don't actually build anything.
 -clean        Remove the current DISTROOT & rebuild.
 -dopull       Update tools after building distribution.
               Tools must live in \$SRCROOT/tools.
 -localonly    do not build the tools named in \$AUX_TOOLS_PJLIST.
 -nonlocalonly only build the tools named in \$AUX_TOOLS_PJLIST.
 -noprintmap   do not build SRCROOT/tlmap.txt (wheresrc map).
 -printmaponly build printmap only.
 -readyfile flagfile
               remove/create <flagfile> at beginning/end of build.
 -update       perform a cvs update in local tools path and then
               in each \$AUX_TOOLS_PJLIST.
 -cvsupdate    same as -update
 -gitsync      sync cvs tooldist to git (on by default)
 -nogitsync    do not sync cvs tooldist to git
 directories...
              only build these directories in each project.

Environment:

 local_mmf_cmn - name of the local tools bdb (default is $local_mmf_cmn).

 AUX_TOOLS_PJLIST - space-separated list of tools projects to build,
       in addition to the local tools build (in bdb/$local_mmf_cmn).

 CVS_BRANCH_NAME  -
       The CVS branch name you want to use to update the tools
       source code in all projects.

 CVS_CO_ROOT
       If sources are checked into a sub-dir of CVSROOT, then this is the
       root cvs directory relative to SRCROOT.

 CVS_SRCROOT_PREFIX -
       If sources are checked into a sub-dir of CVSROOT, then this is the prefix
       to use.

 DISTROOT -  the distribution area for tools. (removed if -clean).

 GIT_TOOLDIST_PATH
       The base of git tools distribution repository.
       Must be defined for -gitsync option.

 GIT_TOOLDIST_WORK
       The base of git working directories, used to sync the cvs tools modules to git branches
       Must be defined for -gitsync option.

 SRCROOT  -  the root directory of the working source repository.

 TARGET_OS_LIST - build tools for this comma-separated list of platforms.
       If not defined, then use bldhost command to determine list.

 bdb/projects    - each project referenced in \$AUX_TOOLS_PJLIST must be
       defined in this projects file.  (becomes \$MYPROJECTS file for VSPMS)

 bdb/<pj>.cmn    - bdb to build each <pj> listed in \$AUX_TOOLS_PJLIST.
       this bdb is defined for the local \$SRCROOT.

Note:
 The -dopull option requires that the tools
 resides in the standard location:  \$SRCROOT/tools.
 This is to prevent you from accidently updating
 someone else's tools.

EOF
exit $exit

ARGSOK:

#ASSERT environment:
if (! $?SRCROOT || ! $?DISTROOT ) then
    echo "${p}:  BUILD_ERROR: \$SRCROOT and \$DISTROOT must be defined.  HALT."
    exit 1
endif

#ASSERT VSPMS
if (! $?VSPMS_REVISION) then
    echo "${p}:  BUILD_ERROR: VSPMS/chpj aliases not installed.  HALT."
    exit 1
endif

if (! $?CVS_BRANCH_NAME ) then
    echo "${p}:  BUILD_ERROR: \$CVS_BRANCH_NAME must be defined.  HALT."
    exit 1
endif

if ($DOGITSYNC) then
    if (! $?GIT_TOOLDIST_PATH || ! $?GIT_TOOLDIST_WORK ) then
        echo "${p}:  BUILD_WARNING: GIT_TOOLDIST_PATH or GIT_TOOLDIST_WORK is not defined, setting -nogitsync"
        set DOGITSYNC = 0
    endif
endif

if ( $?CVS_OPTS) then
    set cvsopts="$CVS_OPTS"
    echo INFO: setting cvs options from CVS_OPTS environment variable
else
    set cvsopts="-f -q -z6"
endif
echo INFO: cvsopts=$cvsopts

set cvs_srcroot_prefix=""
if ( $?CVS_SRCROOT_PREFIX) then
    if ( "$CVS_SRCROOT_PREFIX" != "" ) then
        set cvs_srcroot_prefix="$CVS_SRCROOT_PREFIX/"
    endif
endif
echo INFO: cvs_srcroot_prefix="'$cvs_srcroot_prefix'"

set checkoutopts="-A"
if ($CVS_BRANCH_NAME != trunk && $CVS_BRANCH_NAME != main ) then
    set checkoutopts="-A -r $CVS_BRANCH_NAME"
endif
set CVSSTATUS = 0

cat << EOF
PROJECT_ENV is $PROJECT_ENV
PJHOME_ENV is $PJHOME_ENV
PJCURR_ENV is $PJCURR_ENV
PJHOME_ALIAS is $PJHOME_ALIAS
PJCURR_ALIAS is $PJCURR_ALIAS
EOF

#######
#create a temporary project file, and add this_project:
#######
newpjenv $TMP_BDBDIR/projects
echo this_project $SRCROOT > $MYPROJECTS

bldmsg -p $p "MYPROJECTS is set to '$MYPROJECTS'"

#is our home project already init'd?
if ( -r "$PJHOME_ENV" ) then
    #this is really a bug in VSPMS - PJHOMEINITD should be an env. var. RT 6/1/06
    set PJHOMEINITD = 1
else
    #initialize home project env:
    pjhomeinit
endif

#remove SRCROOT from PJHOME if it is defined.  this is for jobs that are
#called from cron that add SRCROOT to PJHOME_ENV, which screws up buildenv.csh:
rm -f $TMPA
grep -v "^SRCROOT=" "$PJHOME_ENV" > $TMPA
rm -f "$PJHOME_ENV"
cp $TMPA "$PJHOME_ENV"
rm -f $TMPA

#####
#save local SRCROOT:
#####
set localsrcroot=$SRCROOT

##########
#re-source the local SRCROOT project env:
##########
chpj this_project

########
#WE have tools, and VSPMS is installed.
# TO HALT:
# set exit = $status
# goto HALT
########

set exit = 0
bldmsg -markbeg $p

#save enough setup for makedrv to use this project's environment:
set localdist=$DISTROOT
set localreleasedist=$RELEASE_DISTROOT
set localproduct=$PRODUCT
if ($?BUILDTIME_LOG) then
    set bldtimelog=$BUILDTIME_LOG
    set blddate=$BUILD_DATE
else
    set bldtimelog=""
endif

if ($?TARGET_OS_LIST) then
    set localtargets="$TARGET_OS_LIST"
else
    set localtargets="`bldhost -a -psuedo -port -comma`"
endif

set toolspj_list=""

bldmsg -p $p "Building for targets: $localtargets"

if ($LOCALONLY) then
    bldmsg -p $p "-localonly selected, skipping AUX_TOOLS_PJLIST tools build."
else
    # make sure we have the relevant defs:
    if (! $?AUX_TOOLS_PJLIST) then
        bldmsg -p $p -warn AUX_TOOLS_PJLIST not defined - will build local tools only
        set LOCALONLY = 1
    else
        set toolspj_list="$AUX_TOOLS_PJLIST"
    endif
endif

########
# set up custom bdb files if directories provided on command line:
########
if (-f $TMP_BDBFN) then
    set localbdb="$TMP_BDBDIR"
    cp $SRCROOT/bdb/projects $TMP_BDBDIR

    #set up mmf file to be our list of dirs:
    cp $TMP_BDBFN $TMP_BDBDIR/$local_mmf_cmn

    #set up each remote build mmf file to be our list of dirs:
    foreach pj ($toolspj_list)
        if (-f $SRCROOT/bdb/$pj.cmn) then
            cp $TMP_BDBFN $TMP_BDBDIR/$pj.cmn
        endif
    end
else
    set localbdb=$SRCROOT/bdb
endif

#note - we assume that makedrv is compatible in all the ref paths
#first, build tools/release in local path:

#take us to $SRCROOT:
subpj .

if ($DOREADYFILE) then
    if (! $TESTMODE) then
        \rm -f $READYFILE
    endif
endif

if ($DOCLEAN) then
    bldmsg -p $p -markbeg CLEAN of $DISTROOT
    if ($TESTMODE) then
        echo TESTING - clean
    else
        mv $DISTROOT $DISTROOT.$$
        \rm -rf $DISTROOT.$$
    endif
    bldmsg -p $p -markend CLEAN of $DISTROOT
endif

if (! $NONLOCALONLY) then
    setenv BDB_LIBPATH $localbdb
    if (! $DOPRINTMAPONLY ) then
        bldmsg -p $p -markbeg local tools build
        if ($TESTMODE) then
            echo TESTING - local build
        else
            #note - must do bdb only, as mmf requires services:
            if ( $DOCVSUPDATE ) then
                if ( $DOLOCALCVSUPDATE == 1 ) then
                    bldmsg -mark -p $p bootstrap local bdb from branch $CVS_BRANCH_NAME
                    echo cvs $cvsopts checkout $checkoutopts -d bb ${cvs_srcroot_prefix}bb
                    cvs $cvsopts checkout $checkoutopts -d bb ${cvs_srcroot_prefix}bb
                    if ( $status ) set CVSSTATUS = 1
                endif

                #now install bdb's:
                bldmsg -mark -p $p update local bdb
                makedrv -auto -c bdb

                if ( $DOLOCALCVSUPDATE == 1 ) then
                    bldmsg -mark -p $p checkout local tools source from branch $CVS_BRANCH_NAME
                    echo makedrv -auto -b $local_mmf_cmn -c cvsupdate
                    makedrv -auto -b $local_mmf_cmn -c cvsupdate
                    if ( $status ) then
                        bldmsg -error -p $p CVS MAKEDRV UPDATE FAILED in $SRCROOT, perhaps you want -nonlocalonly\?
                        set CVSSTATUS = 1
                    endif
                endif 

                if ( $CVSSTATUS ) then
                    bldmsg -error -p $p CVS UPDATE FAILED in $SRCROOT
                    set exit=1
                endif
            else
                bldmsg -mark -p $p update local bdb
                makedrv -auto -c bdb
                if ( $status ) set exit=1
            endif

            #run ant if we have an ant bdb:
            if ( -r $SRCROOT/bdb/ant.cmn ) then
                makedrv -auto -b ant.cmn -c ant
                if ( $status ) set exit=1
            endif

            makedrv -auto -b $local_mmf_cmn -c mmf
            if ( $status ) set exit=1
        endif
        bldmsg -p $p -markend local tools build
    endif
endif

if ( -r $SRCROOT/bdb/projects ) then
    #append new projects to our project list:
    cat $SRCROOT/bdb/projects >> $MYPROJECTS
else
    bldmsg -p $p -error "$SRCROOT/bdb/projects not found - did you build local tools yet?"
    set exit = 1
    goto HALT
endif

if ($DOPRINTMAP) then
    bldmsg -p $p -markbeg local printmap
    if ($TESTMODE) then
        echo TESTING - local printmap
    else
        \rm -f $SRCROOT/tlmap.raw
        makedrv -auto -b $local_mmf_cmn -c printmap -q > $SRCROOT/tlmap.raw
        if ( $status ) set exit=1
    endif
    bldmsg -p $p -markend local printmap
endif

if ($LOCALONLY) then
    goto WHERESRC
endif

foreach pj ($toolspj_list)

    set pdir=`wherepj $pj`
    if ($pdir == "NULL") then
        bldmsg -p $p -error "no such project, $pj."
        set exit=1
        continue
    endif
    if (! -d $pdir) then
        bldmsg -p $p -error "$pj directory $pdir does not exist on this machine."
        set exit=1
        continue
    endif

    pushpj $pj


    set checkoutopts="-A"
    if ($CVS_BRANCH_NAME != trunk && $CVS_BRANCH_NAME != main ) then
        set checkoutopts="-A -r $CVS_BRANCH_NAME"
    endif

    set cvs_srcroot_prefix=""
    if ( $?CVS_SRCROOT_PREFIX) then
        if ( "$CVS_SRCROOT_PREFIX" != "" ) then
            set cvs_srcroot_prefix="$CVS_SRCROOT_PREFIX/"
        endif
    endif
    echo "INFO: cvs_srcroot_prefix for project '$pj' is '$cvs_srcroot_prefix'"

    if ( $DOCVSUPDATE ) then
        #always check out bb service
        bldmsg -mark -p $p bootstrap bdb in $pdir from branch $CVS_BRANCH_NAME
        echo cvs $cvsopts checkout $checkoutopts -d bb ${cvs_srcroot_prefix}bb
        cvs $cvsopts checkout $checkoutopts -d bb ${cvs_srcroot_prefix}bb
        if ( $status ) then
            bldmsg -error -p $p BDB CVS UPDATE FAILED in $SRCROOT
            set CVSSTATUS = 1
        endif
    endif

    #NOTE - have to set these vars to point back to us:
    setenv BDB_LIBPATH $localbdb
    setenv DISTROOT $localdist
    setenv RELEASE_DISTROOT $localreleasedist
    setenv PRODUCT  $localproduct
    setenv TARGET_OS_LIST "$localtargets"
    if ("$bldtimelog" != "") then
        setenv BUILDTIMELOG "$bldtimelog"
        setenv BUILD_DATE "$blddate"
    endif

    cat << EOF
PROJECT $pj build environment:
    SRCROOT is  $SRCROOT
    BDB_LIBPATH is  $BDB_LIBPATH
    DISTROOT is $DISTROOT
    RELEASE_DISTROOT is $RELEASE_DISTROOT
    PRODUCT is  $PRODUCT
    TARGET_OS_LIST is   $TARGET_OS_LIST
    Local SRCROOT is    $localsrcroot
    PERL_LIBPATH is $PERL_LIBPATH
    CVS_BRANCH_NAME is $CVS_BRANCH_NAME
    Using `fwhich makedrv`
    Using `whereperl makedrv.pl`
    Using `whereperl mmfdrv.pl`
EOF

    if (! $DOPRINTMAPONLY ) then
        bldmsg -p $p -markbeg $pj tools build
        if ($TESTMODE) then
            echo TESTING - aux build
        else
            if ( $DOCVSUPDATE ) then
                bldmsg -mark -p $p update bdb in $pdir from branch $CVS_BRANCH_NAME
                echo cvs $cvsopts checkout $checkoutopts -d bb ${cvs_srcroot_prefix}bb
                cvs $cvsopts checkout $checkoutopts -d bb ${cvs_srcroot_prefix}bb
                if ( $status ) then
                    bldmsg -error -p $p BDB cvsupdate FAILED in $SRCROOT
                    set CVSSTATUS = 1
                endif

                bldmsg -mark -p $p checkout tools source in $pdir from branch $CVS_BRANCH_NAME
                makedrv -auto -b $pj.cmn -c cvsupdate
                if ( $status ) then
                    bldmsg -error -p $p makedrv cvsupdate FAILED in $SRCROOT
                    set CVSSTATUS = 1
                endif
            endif
            #update the bdb's before building remote project:
            makedrv -auto -c bdb
            if ( $status ) set exit=1

            #run ant if we have an ant bdb:
            if ( -r $localsrcroot/bdb/${pj}_ant.cmn ) then
                makedrv -auto -b ${pj}_ant.cmn -c ant
                if ( $status ) set exit=1
            endif

            makedrv -auto -b $pj.cmn -c mmf
            if ( $status ) set exit=1
        endif
        bldmsg -p $p -markend $pj tools build
    endif

    if ($DOPRINTMAP) then
        # append printmap:
        bldmsg -p $p -markbeg $pj printmap
        if ($TESTMODE) then
            echo TESTING - aux printmap
        else
            makedrv -auto -b $pj.cmn -c printmap -q >> $localsrcroot/tlmap.raw
            if ( $status ) set exit=1
        endif
        bldmsg -p $p -markend $pj printmap
    endif

    poppj
end

WHERESRC:

####### return to local $SRCDIR
chpj this_project

#exit non-zero if cvs update failed:
if ($CVSSTATUS) set exit=1

#update BLDPARMS if it is set and we had a successful cvs update
if ($?BLDPARMS && $DOCVSUPDATE ) then
    if ( $CVSSTATUS == 0 ) then
        bldmsg -mark -p $p "Setting devtools_last_update to '$UBLDSTARTTIME' in '$BLDPARMS'"
        shprops -set $BLDPARMS devtools_last_update=$UBLDSTARTTIME
    else
        bldmsg -warn -p $p "Not setting devtools_last_update in '$BLDPARMS' because the CVS update failed"
    endif
endif

if ($DOPRINTMAP) then
    bldmsg -p $p -markbeg wheresrc map

    if ($TESTMODE) then
        echo TESTING - wheresrc map
    else
        wheresrc -gen -f tlmap.raw > tlmap.new
        if (-e tlmap.txt) mv tlmap.txt tlmap.old
        mv tlmap.new tlmap.txt

        ### install the printmap in $DISTROOT/lib/cmn
        minstall -f 0775 -m 0444 -cvsdest -base $DISTROOT -udiff tlmap.txt $DISTROOT/lib/cmn
        minstall -f 0775 -m 0444 -cvsdest -base $DISTROOT -udiff tlmap.txt $DISTROOT/lib/ntcmn
    endif

    bldmsg -p $p -markend wheresrc map
endif

if ( $CLEANDIST && ! $DOCLEAN && ! $NONLOCALONLY && ! $LOCALONLY) then
    bldmsg -p $p -markbeg execute cleandist
    cleandist
    if ($status) then
        bldmsg -p $p -error "cleandist failed."
        set exit=1
    endif

    #remove any empty dirs in $DISTROOT (do it a few times, to remove empty hierarchies):
    rm -rf `walkdir -e $DISTROOT | grep -v Emptydir`
    rm -rf `walkdir -e $DISTROOT | grep -v Emptydir`
    rm -rf `walkdir -e $DISTROOT | grep -v Emptydir`

    bldmsg -p $p -markend execute cleandist
endif

#####
#sync to git distribution only after cvs distribution is fully updated.
#####
if ($DOGITSYNC) then
    if ( ! $?CVS_TOOLDIST_PATH ) then
        setenv CVS_TOOLDIST_PATH "$DISTROOT"
    endif
    tooldist2git -verbose
endif

#######
#create tools.rdy semaphore:
#######
if ($DOREADYFILE) then
    bldmsg -p $p -mark creating $READYFILE
    if ($TESTMODE) then
        echo TESTING - ready file
    else
        mkdir -p `dirname $READYFILE`
        date > $READYFILE
        if (! -f $READYFILE) then
            bldmsg -p $p -error "$READYFILE was not created successfully"
            set exit=1
        endif
    endif
endif

if ($DOPULL) then
    set updateDist=$SRCROOT/tools/boot/updateDist
    if (-x $updateDist ) then
        $updateDist
        if ($status) then
            bldmsg -p $p -error "$updateDist failed."
            set exit=1
        endif
    else
        bldmsg -p $p -error "cannot find $updateDist - tools not updated."
        set exit=1
    endif
endif

####
HALT:
####

bldmsg -markend $p
\rm -rf $TMP_BDBDIR

exit $exit
