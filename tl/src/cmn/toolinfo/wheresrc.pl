package wheresrc;

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
# @(#)wheresrc.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


# wheresrc - look in the toolinfo database for the source associated
# with a forte tool.
#

require "url.pl";

############################# MAIN ##################################

sub main
{
    local(*ARGV, *ENV) = @_;

    &init_record_defs;
    exit (1) if (&parse_args(*ARGV, *ENV) != 0);
    exit (0) if ($HELPFLAG);

#read TOOLDB into @theDB.  note that @theDB records retain newlines.
    @theDB = ();
    %envDB = ();
    &read_db(*theDB, *envDB, $TOOLDB);

    #&dumpvar('main', 'DB');

    if ($GENERATE) {
	    #ignore other options if we're generating:
	    &do_generate(*theDB);
	    exit(0);
    }

    if ($#CMDLIST >=0) {
	    for (@CMDLIST) {
		    last if (!&findinfo($_, *theDB));
	    }
    } else {
	    &mapinfo(*theDB, $TOOLDB);
    }

    exit(0);

}

################################# SUBROUTINES #################################

sub do_generate
{
	local (*DB) = @_;
	local (@rec);

	print "#clean printmap\n";
        print "#DISTROOT=$DISTROOT\n";
	for (@DB) {
		print $_;
	}
}

sub mapinfo
#this form of the command just reads in the map file, collects
#info, and displays the results
{
	local (*DB, $fn) = @_;
	local(@rec) = ();
	local($nrecs) = 0;

	for (@DB) {
		chomp;
		@rec = split("\t", $_);
		if (!defined($uniq_targets{$rec[$MAP_TARGET_OS]})) {
			$uniq_targets{$rec[$MAP_TARGET_OS]} = 0;
			++$nuniq_targets;
		} else {
			++$uniq_targets{$rec[$MAP_TARGET_OS]};
		}
		++$nrecs;
	}

	printf STDERR ("%s:  %d map entries, %d unique target platforms\n",
		$fn, $nrecs, $nuniq_targets) if ($VERBOSE);
	if ($CSH_GEN) {
		printf("setenv TARGET_OS_LIST \"%s\"\n", join(",", (sort keys %uniq_targets)));
	} elsif ($SH_GEN) {
		printf("export TARGET_OS_LIST; TARGET_OS_LIST=\"%s\"\n", join(",", (sort keys %uniq_targets)));
	} else {
		printf("TARGET_OS_LIST:\n\t%s\n", join("\n\t", (sort keys %uniq_targets)));
	}
}

sub findinfo
#look for a command in our database.
#returns true if found unless error condition.
{
	local ($cmd, *DB) = @_;
	local(@possible) = ();
	local(@rec) = ();
	local($match, $nmatches);

	printf STDERR ("Looking for %s %s:\n",
		$cmd, $OS_ALL? "on all platforms": "on $TARGET_OS") if ($VERBOSE);

	#narrow down the possiblities to avoid loop interations:
	@possible = grep(/$cmd/i, @DB);

	$nmatches = 0;
	for (@possible) {
		chomp;		#eliminate trailing newline
		@rec = split("\t", $_);

		if ($PATTERN_FLAG) {
			if ($PRESERVE_CASE) {
				$match = ($rec[$MAP_INSTALLFILE] =~ /$cmd/o);
			} else {
				$match = ($rec[$MAP_INSTALLFILE] =~ /$cmd/oi);
			}
		} else {
			$match = ($rec[$MAP_INSTALLFILE] eq $cmd);
		}
		$match = $match && ($OS_ALL || $TARGET_OS eq $rec[$MAP_TARGET_OS]);
		if ($match) {
			++$nmatches;
			printf($OUTPUT_FORMAT,
				$rec[$MAP_TARGET_OS],
				$rec[$MAP_SRCDIR], $rec[$MAP_SRCFILE],
				$rec[$MAP_INSTALLDIR], &url'name_decode($rec[$MAP_INSTALLFILE]));
		}
	}
	return($nmatches > 0);
}

sub init_record_defs
{
	$MAP_NF = 6;
	($MAP_SRCDIR, $MAP_TARGET_OS, $MAP_SRCFILE, $MAP_INSTALLFILE,
		$MAP_INSTALLDIR, $MAP_MODE) = (0..$MAP_NF-1);

#Example:
#SRCDIR=tl/src/vaxvms/tools
#vaxvms	bhypehlp.com	build_hyperhlp.com	/forte1/d/tools/dist/bin/bld/vaxvms	555
}

sub cleanmap
#if the db has been regenerated using the -gen option,
#then read it in and return true.
{
	local (*DB, *EB, $fn) = @_;
	local ($ret) = 0;

	if (!open(INFILE, $fn)) {
		return(0);	#read_db will handle error
	}

        local(@envary)=();
	$_ = <INFILE>;		#read first record
        if ( /^#clean printmap/) {
            $ret = 1;
            @DB = <INFILE>;
            chomp(@DB);
            while ( $DB[0] =~ /^##*\s*[A-Z][A-Z]*/) {
                $_ = shift(@DB);
                $_ =~ s/^##*\s*//;
                @envary = split('=', $_);
                if ($#envary + 1 > 1) {
                $EB{$envary[0]} = $envary[1];
                }
                else {
                }
            }
        }
	printf STDERR ("Read %d records from clean printmap file '%s'.\n",
			$#DB, $fn) if ($VERBOSE);

	close(INFILE);
	return($ret);
}

sub read_db
#read the tool info file into a list.  recognize "clean printmap" 
#files that have been generated by -gen option.
{
	local (*DB, *EB, $fn) = @_;
	local ($ret) = 0;

	if (&cleanmap(*DB, *EB, $fn)) {
		return;
	}

	#otherwise, raw output from "make printmap"
	if (!open(INFILE, $fn)) {
		printf STDERR ("%s:  can't open %s\n", $p, $fn);
		exit(1);
	}

	local ($srcdir) = "";
	local ($scnt, $rcnt, $badrecs) = (0,0,0,0);
	local (@xx) = ();
	local(@rec) = ();

	local($linecnt) = 0;
	while (<INFILE>) {
		++$linecnt;
		if (/^SRCDIR/) {
			chomp; ++$scnt;
			@xx = split('=', $_);
			if ($#xx < 1) {
				printf STDERR ("%s:  WARNING: ignoring line #%d, file %s (%s)\n",
					$p, $linecnt, $fn, "BAD 'SRCDIR=' line") if ($VERBOSE);
				++$badrecs;
				$srcdir = "NULL";
			} else {
				$srcdir = $xx[1];
			}
		} else {
			@rec = split("\t", $_);
			if ($#rec != $MAP_NF-2) {
				printf STDERR ("%s:  WARNING: ignoring line #%d, file %s (%s)\n",
					$p, $linecnt, $fn, "BAD FIELD COUNT") if ($VERBOSE);
				++$badrecs;
			} elsif ($srcdir ne "NULL") {
				#prepend srcdir name to record:
				++$rcnt;
				@DB = (@DB, "$srcdir	$_");
			} else {
				printf STDERR ("%s:  WARNING: ignoring line #%d, file %s (%s)\n",
					$p, $linecnt, $fn, "NO PRECEEDING 'SRCDIR=' line") if ($VERBOSE);
				++$badrecs;
			}
		}
	}

	printf STDERR ("%s: %d lines, %d SRCDIR defs, %d map entries, %d bad records.\n",
		$fn, $scnt+$rcnt+$badrecs, $scnt, $rcnt, $badrecs) if ($VERBOSE);

	close(INFILE);
}

################################ USAGE SUBROUTINES ###############################

sub usage
{
	local($exitstatus) = @_;

    print STDOUT <<"!";
Usage:
    $p [-h] [-v] [-p] [-f printmap] [-os target_os] -fold installed_name...
    $p -gen [-f printmap]
    $p [-sh|-csh] [-f printmap]

Synopsis:
    Locate the source files for each installed file.

    The second "-gen" form of the command reads in the "raw"
    printmap data and generates a "clean" version that can
    be used to improve $p performance.

    The third "info" form of the command displays information
    about the map file, including a list of all valid "-os" values.

Options:
-h    print this usage message and exit.
-v    verbose option - print informational messages to stderr.
-f    printmap
      search <printmap> instead of default locations:
             1. \$SRCROOT/$TLMAP
             2. \$TOOLSFOR/$TLMAP
             3. \$TOOLROOT/lib/cmn/$TLMAP
-gen  generate (to stdout) "clean" data file from raw printmap output.
-p    take <command_name> arguments to be perl pattern specifications
      instead of simple strings.
-P    take <command_name> arguments to be perl pattern specifications
      instead of simple strings, perserve case.
-sh   with "info" form of command, generate sh or ksh command to set
      TARGET_OS_LIST variable, which can be used with mmfdrv command.
-csh  like -sh, except generate csh or tcsh syntax.
-os   target_os
      look for commands only for <target_os>, which is a value
      returned by the whatport(1) command, or a "pseudo" install
      target.  E.g., cmn, ntcmn, vmsinc, etc.  Use the "info"
      form of the command to get a list of all valid targets.
-fold output search results in multi-line format instead of column format.

Examples:
    % cd \$SRCROOT
    % mmfdrv -q -r -all -t printmap tl/src > \$SRCROOT/tlmap.txt
    % $p makedrv
    % $p -os mac makedrv
    % $p -gen -f myprintmap > cleanmap
    % $p -csh > mydefs
!
	return $exitstatus;
}

sub parse_args
#proccess command-line aguments
{
    #set up program name argument:
    @tmp = split('\/', $0);
    $p = $tmp[$#tmp];
    local(*ARGV, *ENV) = @_;

	#set defaults:
	@CMDLIST = ();
	$TLMAP = "tlmap.txt";
	if ($#ARGV+1 < 1 ) {
		return &usage(1);
	}

	$TOOLDB = "NULL";
        $DISTROOT = $ENV{"DISTROOT"};

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
	$GENERATE = 0;
	$HELPFLAG = 0;
	$SH_GEN = 0;
	$CSH_GEN = 0;
	$OS_ALL = 1;
	$TARGET_OS = "cmn";
	#default output spec for searches:
	$OUTPUT_FORMAT = "%s:	%s/%s -> %s/%s\n";

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		local($flag) = shift(@ARGV);

		if ($flag eq "-f") {
			return &usage(1) if (!@ARGV);
			$TOOLDB = shift(@ARGV);
		} elsif ($flag eq '-os') {
			return &usage(1) if (!@ARGV);
			$TARGET_OS = shift(@ARGV);
			$OS_ALL = 0;
		} elsif ($flag eq '-v') {
			$VERBOSE = 1;
		} elsif ($flag eq '-gen') {
			$GENERATE = 1;
		} elsif ($flag eq '-fold') {
			$OUTPUT_FORMAT = "%s:\t%s/%s\n\t-> %s/%s\n";
		} elsif ($flag eq '-sh') {
			$SH_GEN = 1;
		} elsif ($flag eq '-csh') {
			$CSH_GEN = 1;
		} elsif ($flag eq '-p') {
			$PATTERN_FLAG = 1;
		} elsif ($flag eq '-P') {
			$PATTERN_FLAG = 1;
			$PRESERVE_CASE = 1;
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

    #take remaining args as directories:
    if ($#ARGV >= 0) {
		@CMDLIST = @ARGV;
	}

	&url'init;
	&url'set_kshare_server;

	#convert spec to url encoding:
	for (@CMDLIST) {
		$_ = &url'name_encode($_);
	}
    return 0;
}
1;
