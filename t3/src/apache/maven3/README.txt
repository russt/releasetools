To prepare distribution for toolsdist, just untar and eliminate top-level directory, e.g.:
    % tar tf apache-maven-3.0.4-bin.tar.gz |head -1
    apache-maven-3.0.4/boot/plexus-classworlds-2.4.jar
Eliminate apache-maven-3.0.4 and then re-tar as maven.btz.

NOTE:  universal mvn.sh is in tl/src/cmn/maven-util.  this will drive mvn 2.0.5, 2.0.9, 2.0.11, 2.2.1, or 3.0.4.
RT 8/29/13
