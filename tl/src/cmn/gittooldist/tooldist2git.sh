#!/bin/sh
#
# BEGIN_HEADER - DO NOT EDIT
# @(#)tooldist2git.sh
# 
# Author:  Russ Tremain
# 
# Copyright (c) 2013-2013 Russ Tremain. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1.  Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
# 
# 2.  Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL PERFORCE 
# SOFTWARE, INC. BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON 
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR 
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
# THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH 
# DAMAGE.
# 
# END_HEADER - DO NOT EDIT
#


#tooldist2git - sync cvs tools dist to git.
#
# INPUT:
#    CVS_TOOLDIST_PATH - base of cvs tools distribution repository, eg. /scm/cvs/tooldist/rtproj/main/rttl
#    GIT_TOOLDIST_PATH - base of git tools distribution repository, e.g. /scm/git/public/tooldist/rtproj/main/rttl
# 
# OUTPUT:
#    git repository in GIT_TOOLDIST_PATH, one branch per cvs tools module definition
#

##################################### USAGE ####################################

usage()
{
    status=$1

    cat << EOF
Usage:  $p [options] [var=def...] [platforms]

 Sync cvs tools distribution to corresponding git repository.

 Each cvs tools module (linuxtools, osxtools, etc) is synced to a git branch
 of the same name.

Options:
 -help        Display this help screen.
 -verbose     show informational messages.
 -clean       initalize a new git repository and working directories.
              NOTE: -clean should be used sparingly, as it requires git
              clients of distribution to reclone their tools.

Environment:
 CVS_TOOLDIST_PATH - base of cvs tools distribution repository, eg. /scm/cvs/tooldist/rtproj/main/rttl
 GIT_TOOLDIST_PATH - base of git tools distribution repository, e.g. /scm/gitroot/public/tooldist/rtproj/main/rttl
 GIT_TOOLDIST_WORK - base of git working directories, used to sync the cvs tools modules to git branches

Example:
 Sync the current CVS tools distribution to git:
   $p -clean GIT_TOOLDIST_PATH=/scm/gitroot/public/tooldist/rtproj/main/rttl GIT_TOOLDIST_WORK=/scm/gitroot/tmp/gitsync

 Checkout the git tools distribution for linux:
   git clone --branch linuxtools git://localhost/tooldist/rtproj/main/rttl linuxtools

 Checkout the git tools distribution for macosx:
   git clone --branch macosxtools git://localhost/tooldist/rtproj/main/rttl macosxtools

EOF

    exit $status
}

parse_args()
{
    init_defaults

    while [ $# -gt 0 -a "$1" != "" ]
    do
        arg=$1; shift

        case $arg in
        -help )
            usage 0
            ;;
        -v* )
            #verbose messages
            VERBOSE=1
            ;;
        -clean )
            CLEAN_DIST=1
            ;;
        *=* )
            tmp=`echo $arg|sed -e 's/"/\\\\"/g'`
            #echo A arg=.$arg. tmp is .$tmp.
            tmp=`echo $tmp|sed -e 's/^\([^=][^=]*\)=\(.*\)/\1="\2"; export \1/'`
            #echo B tmp is .$tmp.
            eval $tmp
            ;;
        -* )
            echo "${p}: unknown option, $arg"
            usage 1
            ;;
        * )
            if [ -z "$PLATFORM_ARGS" ]; then
                PLATFORM_ARGS="$arg"
            else
                PLATFORM_ARGS="$PLATFORM_ARGS $arg"
            fi
            ;;
        esac
    done
${SH_PARSE_ARGS_EPILOG:undef}
}

init_defaults()
#this routine is responsible for initializing all default parameters
{
    PLATFORM_ARGS=
    CLEAN_DIST=0
    VERBOSE=0
}

################################## SUBROUTINES #################################

createGitToolDistRepo()
{
    bldmsg -p $p -mark create git tools dist repository in $GIT_TOOLDIST_PATH
    mkdir -p "$GIT_TOOLDIST_PATH"
    git init --bare "$GIT_TOOLDIST_PATH"
}

createGitWorking()
#INPUTS:  GIT_TOOLDIST_WORK, GIT_TOOLDIST_PATH, module
#OUTPUT:  new clone from $GIT_TOOLDIST_PATH in $GIT_TOOLDIST_WORK/$module, with proper ignores.
{
    cd $GIT_TOOLDIST_WORK

    #create subdir as part of clone
    git clone $GIT_TOOLDIST_PATH $module

    #we want to ignore all CVS/ directories, in addition standard ignores:
    cat > $module/.git/info/exclude << 'EOF'
*~
.*.swp
.DS_Store
CVS/
EOF
    #Note - normally wouldn't have to worry about vi tmp files, etc., but since working dirs
    #can persist between runs, they may get browsed.
}

check_set_env()
#check that needed environment is provided. return 0 if okay.
{
    _ckenv_err=0

    [ -z "$CVS_TOOLDIST_PATH" ] && _ckenv_err=1 && bldmsg -error -p $p CVS_TOOLDIST_PATH must be defined.
    [ -z "$GIT_TOOLDIST_PATH" ] && _ckenv_err=2 && bldmsg -error -p $p GIT_TOOLDIST_PATH must be defined.
    [ -z "$GIT_TOOLDIST_WORK" ] && _ckenv_err=2 && bldmsg -error -p $p GIT_TOOLDIST_WORK must be defined.

    return $_ckenv_err
}

##################################### MAIN #####################################

p=`basename $0`
exit_status=0

parse_args "$@"

check_set_env
if [ $? -ne 0 ]; then
    bldmsg -error -p $p One or more needed environment variables are not defined, abort.
    exit 1
fi

if [ $CLEAN_DIST -eq 1 ]; then
    bldmsg -p $p -warn Cleaning git tools repository and working directories - clients should re-clone
    rm -rf $GIT_TOOLDIST_WORK
    rm -rf $GIT_TOOLDIST_PATH
fi

#initialize git tools dist repository if not present:
[ ! -d $GIT_TOOLDIST_PATH ] && createGitToolDistRepo

#create work-dir root if not present:
mkdir -p "$GIT_TOOLDIST_WORK"

if [ -z "$PLATFORM_ARGS" ]; then
    cvsmodules=`cvs -d $CVS_TOOLDIST_PATH co -c | grep tools | sed -e 's/[ ].*//'`
else
    cvsmodules="$PLATFORM_ARGS"
fi

#########
# foreach cvs module...
#########
for module in $cvsmodules
do
    gitworkdir=$GIT_TOOLDIST_WORK/$module

    cd $GIT_TOOLDIST_WORK
    [ ! -d $gitworkdir/.git ] && createGitWorking
    cd $gitworkdir

#echo BEFORE:  `cat .git/info/exclude`

    echo working on $module in `pwd`

    #if this module branch already exists...
    if [ -r .git/refs/heads/$module ]; then
        #switch to branch and update (should be a no-op!):
        git co $module
    else
        #otherwise, create & switch to branch:
        git co -b $module
    fi

#echo AFTER:  `cat .git/info/exclude`

    #update from cvs tools dist:
    bldmsg -p $p -markbeg getting cvs updates from $CVS_TOOLDIST_PATH
    cvs -q -f -r -d $CVS_TOOLDIST_PATH co $module
    bldmsg -p $p -markend -status $? getting cvs updates from $CVS_TOOLDIST_PATH

    bldmsg -p $p -markbeg adding files for $module to git
    git add --all
    bldmsg -p $p -markend -status $? adding files for $module to git

    bldmsg -p $p -markbeg commiting files for $module
    git commit -m "add to branch $module"
    bldmsg -p $p -markend -status $? commiting files for $module

    bldmsg -p $p -markbeg pushing files for $module to $GIT_TOOLDIST_PATH
    git push origin $module
    bldmsg -p $p -markend -status $? pushing files for $module to $GIT_TOOLDIST_PATH
done

exit $exit_status
