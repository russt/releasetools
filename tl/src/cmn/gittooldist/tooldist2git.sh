#tooldist2git.sh - sync cvs tools dist to git.

#definitions:
# INPUTS:
#    CVS_TOOLDIST_PATH - base of cvs tools distribution repository, eg. /scm/cvs/tooldist/rtproj/main/rttl
#    GIT_TOOLDIST_PATH - base of git tools distribution repository, e.g. /scm/git/public/tooldist/rtproj/main/rttl
# 

#this project:
GITROOT=/scm/gitroot

CVS_TOOLDIST_PATH=/scm/cvs/tooldist/rtproj/main/rttl
GIT_TOOLDIST_PATH=$GITROOT/public/tooldist/rtproj/main/rttl

cvsmodules=`cvs -d $CVS_TOOLDIST_PATH co -c | grep tools | sed -e 's/[ ].*//'`

#if git public tooldist repository does not exist, then initialize it:
echo TESTING rm -rf $GIT_TOOLDIST_PATH
rm -rf $GIT_TOOLDIST_PATH
if [ ! -d "$GIT_TOOLDIST_PATH" ]; then
    mkdir -p "$GIT_TOOLDIST_PATH"
    bldmsg -mark create git tools dist repository in $GIT_TOOLDIST_PATH
    git init --bare "$GIT_TOOLDIST_PATH"
fi


TMPWORKROOT=$GITROOT/tmp/gitsync
echo TESTING rm -rf $TMPWORKROOT
rm -rf $TMPWORKROOT
mkdir -p "$TMPWORKROOT"

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
    if [ ! -d $gitworkdir/.git ]; then
	#create subdir as part of clone
	git clone $GIT_TOOLDIST_PATH $module
    fi

    cd $gitworkdir

    echo working on $module in `pwd`

    #create & switch to branch named after module:
    git co -b linuxtools

    #update from cvs tools dist:
    cvs -f -d $CVS_TOOLDIST_PATH co $module

    git add --all
    git commit -m "add to branch $module"
    git push origin $module

done
