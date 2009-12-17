#!/bin/csh
#
#you must define a project called "makemfdev", in the diff source dir.
#HINT: create your src dir in /forte1/tmp - all build
#hosts have /forte1 mounted.
#

#g=rwx, o=r-x
umask 002

#this is the name of our project:
set projname=xmlindent
set projdir=`wherepj $projname`
if ($status != 0) then
    echo "docompiles - project $projname not defined - no can compile"
    exit 1
endif

#ASSERT:  project dir must be available on this machine.
if (! -d $projdir) then
    echo "docompiles - project $projname directory not available"
    exit 1;
endif

#ON this host, chpj to the project dir:
chpj $projname

#echo argc=$#argv argv=$argv[*]

if ( $#argv >= 1 ) then 
    foreach arg ($argv[*])
        if ($arg == "-help") then
            echo "Usage:  docompiles [compile_hosts...]"
            echo "Prerequisite:  VSPMS project named $projname on common NFS mount"
            exit 0
        endif
    end

    if ($#argv > 0) then
        set COMPILE_HOSTS=$argv[*]
    else
        set COMPILE_HOSTS=`bldhost -unix -aux`
    endif
else if ( -r .compile_hosts ) then
    set COMPILE_HOSTS=`grep -v '^#' .compile_hosts`
else
    echo ${0}:  please specify compile hosts on command line or in $projdir/.compile_hosts
    exit 1
endif

#echo TESTING -  hosts=.$COMPILE_HOSTS.
#exit

set exit_status = 0

foreach uhost ($COMPILE_HOSTS)
    set port=`ssh $uhost whatport`
    if ($status != 0) then
        echo "docompile - ssh failed to get port info for $uhost"
        continue
    endif
    echo "========================================"
    bldmsg -markbeg COMPILING for $port on $uhost

    cd $projdir

    rm -f $port.btz

    if ( -d $port) then
        echo REMOVE
        rm -rf $port
    endif

    mkdir $port
    cd $port
    echo UNTAR
    tar xzf ../xmlindent-0.2.17.tar.gz
    cd xmlindent-0.2.17

    set MAKE='make -f $PROJECT/makefile.local CC=$CC CCFLAGS="$CCFLAGS"'
    echo make command .$MAKE. pwd=`pwd`

    ssh $uhost "(chpj $projname; cd $port/xmlindent-0.2.17; $MAKE; ./xmlindent -help)"
    set remotestat = $status

    if ($remotestat == 0) then
        subpj $port/xmlindent-0.2.17
        bldmsg create tar file $PROJECT/$port.btz
        tar czf $PROJECT/$port.btz xmlindent
        if ($status != 0) then
            set exit_status = 1
            bldmsg -error TAR failed for $port on $uhost
        endif
    else
        set exit_status = 1
        bldmsg -error COMPILE failed for $port on $uhost
    endif


    bldmsg -markend -status $remotestat COMPILING for $port on $uhost
    echo "########################################"
end

echo -n "FINISHED ALL COMPILES "; date

pjclean

if ( $exit_status != 0 ) then
    bldmsg -error -p $0 failed on one or more platforms
endif

exit $exit_status
