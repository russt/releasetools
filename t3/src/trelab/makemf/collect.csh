#!/bin/csh -f
#script to collect the output of the build into a staging area.

set SRCMODE=0444
set BINMODE=0555
set PROJMODE=0775
set projname=makemfdev
set projdir=`wherepj $projname`
if ($status != 0) then
	echo "you must have a VSPMS project named $projname to use this script"
	exit  1
endif

set SRCFILES="makemf.c"
set PJFILES="docompiles .projectrc"
set BINFILES="makemf"

set STAGEDIR=/tmp/makemfdev

rm -rf $STAGEDIR
mkdir -p $STAGEDIR

#first, collect the source code:
cd $projdir
chmod $PROJMODE $PJFILES
chmod $SRCMODE $SRCFILES
tar czf $STAGEDIR/makemf.stz $SRCFILES
tar czf $STAGEDIR/cmn.stz $PJFILES

#now collect the binaries:
foreach port (*)
	if (! -d $port) then
		continue
	endif
	echo $port
	(cd $port; chmod $BINMODE $BINFILES; tar czf $STAGEDIR/$port.btz $BINFILES)
end

echo output in $STAGEDIR
exit 0
