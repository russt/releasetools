package cleandist;

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
# @(#)clendist.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# cleandist - import toolinfo database and compare against file struct in 
#             DISTROOT. Delete all those files in DISTROOT that do not 
#             have coresponding tlmap
#             -test option will list the ddiff's
#    we want to combine element 4 wih 3 to produce the dist path fn

#use strict;

require "os.pl";
require "path.pl";
require "walkdir.pl";
require "wheresrc.pl";
require "listutil.pl";

&init;

################################ MAIN ###############################
# add cmd line optiion to change location of tlmap.txt - pass to wheresrc lib

sub main
{
    local(*ARGV, *ENV) = @_;
    local(@theDB) = ();
    local(%envDB) = ();
    my($nerrs) = 0;

    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    #initialize wheresrc module:
    &wheresrc'init_record_defs;

    #read TOOLDB into @theDB.  note that @theDB records retain newlines.
    &wheresrc'read_db(*theDB, *envDB, $TOOLDB);

#printf STDERR "DISTROOT='%s' tlmap DISTROOT='%s'\n", $DISTROOT, $envDB{"DISTROOT"};
    
    if (!defined($envDB{"DISTROOT"})) {
        printf STDERR "%s:  BUILD_ERROR:  could not determine DISTROOT from tlmap... ABORT..\n", $p;
        return 1;
    }
        
    if ($DISTROOT ne $envDB{"DISTROOT"} ) {
        printf STDERR "%s:  BUILD_ERROR:  env \$DISTROOT '%s' different from tlmap DISTROOT '%s' ... ABORT\n",
            $p, $DISTROOT, $envDB{"DISTROOT"};
        return 1;
    }

#foreach $element (@theDB) { printf "%s\n", $element; }; return 0;

    #we are only working on the files that go in the tools distribution -
    #eliminate bdb, release, etc records:
    @theDB = grep($_ =~ /$DISTROOT/, @theDB);

    my($cwd) = &path::pwd;
    if ($cwd eq "NULL" ) {
        printf STDERR "%s:  BUILD_ERROR: cannot determine current directory!\n", $p;
        return 1;
    }
    
    if (! -d $DISTROOT ) {
        printf STDERR "%s:  BUILD_ERROR:  DISTROOT '$DISTROOT' does not exist, aborting...\n", $p;
        return 1;
    }

    chdir $DISTROOT;

    local (%DIRDB) = ();
    $walkdir::FILEFLAG = 1;
    if (($error = &walkdir::dirTree(*DIRDB, $cwd, $DISTROOT)) != 0) {
        printf STDERR "%s: BUILD_ERROR - dirTree failed with error %d while walking %s\n",
            $p , $error, $DISTROOT;
        return 1;
    }

    #get list of files in DISTROOT:
    local @distrootList = &walkdir::file_list(*DIRDB);

    printf STDERR "\t%d file entries within DISTROOT '%s'.\n", $#distrootList + 1, $DISTROOT if ($VERBOSE);

    #get a list of full path names of the tools in tlmap:
    local @tlmapList = &generate_toolset(*theDB);

    #eliminate CVSROOT and other misc files from the inputs:
    @distrootList = grep($_ =~ "/\.#" || $_ !~ "/CVSROOT/|/tlmap.txt,v|/\.#", @distrootList);
    @tlmapList = grep($_ !~ "/CVSROOT/", @tlmapList);

    printf STDERR "%s:  Elgible DISTROOT count is %d, TLMAP count is %d\n",
        $p, $#distrootList + 1, $#tlmapList + 1 if ($VERBOSE);

    #calculate maximum number of extra files we will delete,
    #as a percentage of the DISTROOT count:
    my $MAX_EXTRA_TOOLS_TO_DELETE = $#distrootList / 4;

    printf STDERR "%s:  MAX_EXTRA_TOOLS_TO_DELETE is %d\n", $p, $MAX_EXTRA_TOOLS_TO_DELETE if ($VERBOSE);

#printf STDERR "tlmapList=(%s)\n", join("\n\t", @tlmapList);
#printf STDERR "distrootList=(%s)\n", join("\n\t", @distrootList);
#return 0;

    #Calculate difference sets:
    my @distrootOnly =  &list::MINUS(*distrootList, *tlmapList);
    my @tlmapOnly = &list::MINUS(*tlmapList, *distrootList);

    #number of extra files in each set:
    my $distrootExtra = ($#distrootOnly < 0)? 0 : $#distrootOnly  +1;
    my $tlmapExtra    =    ($#tlmapOnly < 0)? 0 : $#tlmapOnly  +1;

#printf STDERR "distrootOnly=(%s)\n", join("\n\t", @distrootOnly);
#printf STDERR "tlmapOnly=(%s)\n", join("\n\t", @tlmapOnly);
#return 0;

    if ( ($tlmapExtra + $distrootExtra) == 0 ) {
        printf "%s:  DISTROOT has same tool set listed within tlmap\n", $p;
        return 0;
    }

    if ( $tlmapExtra > 0 ) {
        printf ("%s:  BUILD_WARNING: %d files missing from DISTROOT\n", $p, $#tlmapOnly +1);
        printf "\t%s\n", join("\n\t", @tlmapOnly);
    }

    # perhaps we have an incomplete tlmap - if diff set greater 25%
    if ($distrootExtra > 0) {
        my $doDelete = $FORCEDELETE || ($DELETEFILES && ($distrootExtra <= $MAX_EXTRA_TOOLS_TO_DELETE));

        if ($doDelete) {
            printf "%s:  Deleting %d extra tools in DISTROOT:\n", $p, $distrootExtra;
            foreach $element (@distrootOnly) {
                if (! &os::rmFile($element )) {
                    printf "\tDeleted %s\n", $element;
                } else {
                    printf STDERR "%s: delete FAILED for %s\n", $p, $element;
                    ++$nerrs;
                }
            }
        } else {
            if ($DELETEFILES && ($distrootExtra > $MAX_EXTRA_TOOLS_TO_DELETE)) {
                printf STDERR "%s: BUILD_ERROR:  extra file count (%d) exceeds maximum (%d), delete ABORTED.\n",
                    $p, $distrootExtra, $MAX_EXTRA_TOOLS_TO_DELETE;
                ++$nerrs;
            }
        }

        if ($LISTONLY) {
            printf "%s:  Found %d extra tools in DISTROOT:\n", $p, $distrootExtra;
            printf "\t%s\n", join("\n\t", @distrootOnly);
        }
    }

    return $nerrs;
}


########################### SUBROUTINES #############################

sub generate_toolset
#INPUT:   wheresrc db
#OUTPUT:  unique list of full path names of each tool in <DB>
{
    local(*DB) = @_;
    my(@toolfns) = ();
    my($toolfn);
    my(@rec) = ();

    for (@DB) {
        chomp;
        @rec = split("\t", $_);
        $toolfn = &path'mkpathname($rec[$wheresrc'MAP_INSTALLDIR], $rec[$wheresrc'MAP_INSTALLFILE]) . ",v";
        push(@toolfns, $toolfn);
    }

    #we have duplicates due to multiple platform instances.  eliminate them:
    return &list::UNIQUE(@toolfns);
}

############################ INITIALIZATION #########################

sub init
#copies of global vars from main package:
{
    $p = $'p;       #$main'p is the program name set by the skeleton
    $OS = $'OS;
    $UNIX = $'UNIX;
    $MACINTOSH = $'MACINTOSH;
    $NT = $'NT;
    $DOT = $'DOT;

    #default option settings:
    $HELPFLAG = 0;
    $FILEFLAG = 1;
    $LISTONLY = 0;
    $DELETEFILES = 1;
    $FORCEDELETE = 0;

}

########################## USAGE SUBROUTINES ########################

sub usage
{
    local($exitstatus) = @_;

    print STDERR <<"!";
Usage:
    $p [-h] [-v] [-d] [-f printmap] [-list]

Synopsis:
    Show missing and/or extra files in a tools distribution.
    Automatically delete extra files unless the -list option
    is given, or the number of extra files is greater than
    25\% of the distribution.  In this case, do not delete
    the extra files unless the -d option is given.

Options:
-h    print this usage message and exit
-v    verbose option - print informational messages to stderr
-list list the tool set difference only - do not delete.
-d    force delete of all extra tools in \$DISTROOT.
      (limit is normally set to 25\%).
-f    printmap
      search <printmap> instead of default locations:
             1. \$SRCROOT/$TLMAP
             2. \$TOOLSFOR/$TLMAP
             3. \$TOOLROOT/lib/cmn/$TLMAP

Examples:
    % $p -list
!
    return($exitstatus);
}

sub parse_args
#proccess command-line aguments
{
    #set up program name argument:
    @tmp = split('\/', $0);
    $p = $tmp[$#tmp];
    local(*ARGS, *ENV) = @_;

    #set defaults:
    @CMDLIST = ();
    $TLMAP = "tlmap.txt";

    $TOOLDB = "NULL";

    if (defined($ENV{"SRCROOT"})) {
        $SRCROOT = $ENV{"SRCROOT"};
        if (-r "$SRCROOT/$TLMAP") {
            $TOOLDB = "$SRCROOT/$TLMAP";
        } elsif (defined($ENV{"TOOLSFOR"})) {
            $TOOLSFOR = $ENV{"TOOLSFOR"};
            if (-r "$TOOLSFOR/$TLMAP") {
                $TOOLDB = "$TOOLSFOR/$TLMAP";
            }
        } elsif (defined($ENV{"TOOLROOT"})) {
            my($toolroot) = $ENV{"TOOLROOT"};
            if (-r "$toolroot/lib/cmn/$TLMAP") {
                $TOOLDB = "$toolroot/lib/cmn/$TLMAP";
            }
        }
    }

    $PATTERN_FLAG = 0;
    $PRESERVE_CASE = 0;
    $VERBOSE = 0;
    $HELPFLAG = 0;
    $DISTROOT = $ENV{"DISTROOT"};
    #default output spec for searches:

    #eat up flag args:
    while ($#ARGS+1 > 0 && $ARGS[0] =~ /^-/) {
        local($flag) = shift(@ARGS);

        if ($flag eq "-f") {
            return &usage(1) if (!@ARGS);
            $TOOLDB = shift(@ARGS);
        } elsif ($flag eq '-d') {
            $DELETEFILES = 1;
            $FORCEDELETE = 1;
        } elsif ($flag eq '-v') {
            $wheresrc'VERBOSE = 1;
            $VERBOSE = 1;
        } elsif ($flag eq '-list') {
            $LISTONLY = 1;
            $DELETEFILES = 0;
        } elsif ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return &usage(0);
        } else {
            return &usage(1);
        }
    }

    if ($TOOLDB eq "NULL") {
        printf STDERR "%s: cannot find a tlmap in \$SRCROOT or \$TOOLSFOR - please specify.\n",  $p;
        return &usage(1);
    }

    return 0;
}
1;
