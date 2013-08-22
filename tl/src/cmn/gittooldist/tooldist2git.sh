#tooldist2git.sh - sync cvs tools dist to git.
#definitions:
# INPUTS:
#    CVS_TOOLDIST_PATH - base of cvs tools distribution repository, eg. /scm/cvs/tooldist/rtproj/main/rttl
#    GIT_TOOLDIST_PATH - base of git tools distribution repository, e.g. /scm/git/public/tooldist/rtproj/main/rttl
# 
# TODO: allow syncs to be incremental. NOTE:  cannot destroy master git repo and recreate, will screw up clients.
# TODO: hook up to toolsBuild script (if GIT_TOOLDIST_PATH is defined)
#

createGitToolDistRepo()
{
    bldmsg -p $p -mark create git tools dist repository in $GIT_TOOLDIST_PATH
    mkdir -p "$GIT_TOOLDIST_PATH"
    git init --bare "$GIT_TOOLDIST_PATH"
}

createGitWorking()
#INPUTS:  TMPWORKROOT, GIT_TOOLDIST_PATH, module
#OUTPUT:  new clone from $GIT_TOOLDIST_PATH in $TMPWORKROOT/$module, with proper ignores.
{
    cd $TMPWORKROOT

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

##################################### MAIN #####################################

p=`basename $0`

CLEAN_DIST=1
CLEAN_DIST=0

#this project:
GITROOT=/scm/gitroot

CVS_TOOLDIST_PATH=/scm/cvs/tooldist/rtproj/main/rttl
GIT_TOOLDIST_PATH=$GITROOT/public/tooldist/rtproj/main/rttl

TMPWORKROOT=$GITROOT/tmp/gitsync
if [ $CLEAN_DIST -eq 1 ]; then
    bldmsg -p $p -warn Cleaning git tools repository and working directories - clients should re-clone
    rm -rf $TMPWORKROOT
    rm -rf $GIT_TOOLDIST_PATH
fi

#initialize git tools dist repository if not present:
[ ! -d $GIT_TOOLDIST_PATH ] && createGitToolDistRepo

#create work-dir root if not present:
mkdir -p "$TMPWORKROOT"

cvsmodules=`cvs -d $CVS_TOOLDIST_PATH co -c | grep tools | sed -e 's/[ ].*//'`

cvsmodules=linuxtools
echo TESTING cvsmodules=$cvsmodules

# git co -b linuxtools
# cvs -f -d /scm/cvs/tooldist/rtproj/main/rttl co linuxtools
# git add --all
# git commit -m "add to branch linuxtools"
# git push origin linuxtools

for module in $cvsmodules
do
    gitworkdir=$TMPWORKROOT/$module

    cd $TMPWORKROOT
    [ ! -d $gitworkdir/.git ] && createGitWorking
    cd $gitworkdir

echo BEFORE:  `cat .git/info/exclude`

    echo working on $module in `pwd`

    #if this module branch already exists...
    if [ -r .git/refs/heads/$module ]; then
	#switch to branch and update (should be a no-op!):
	git co $module
    else
	#otherwise, create & switch to branch:
	git co -b $module
    fi

echo AFTER:  `cat .git/info/exclude`
    #update from cvs tools dist:
    bldmsg -p $p -markbeg getting cvs updates from $CVS_TOOLDIST_PATH
    cvs -Q -f -r -d $CVS_TOOLDIST_PATH co $module
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

exit 0
