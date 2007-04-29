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
# @(#)mmfdrv.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# mmfdrv - recursive combination makefile generator and runner.
#
# Makefiles are generated using makemf tool.
# The resultant makefile is run.

package mmfdrv;

$p = "mmfdrv";

$MAKEMMF = "make.mmf";
$MAKEFILE = "Makefile";
$VALUELISTSEPARATOR = ",";

$DOT = $'DOT;
$UPDIR = $'UPDIR;
$CPS = $'CPS;

################################### SETUP #####################################

&'require_os;
# require "dumpvar.pl";
require "targets.pl";
require "sp.pl";
require "path.pl";
require "listutil.pl";

#################################### MAIN #####################################

sub main
{
	local(*ARGV, *ENV) = @_;

	&init_globalsA;
	if (&parse_args()) {
		return 1;
	}
	&init_env;
	&init_globalsB;
	&save_mvars;		#save initial values of make variable defs.

#printf "DIRS=(%s)\n", join(',', @DIRS);
	while ($dir = shift @DIRS) {
		if ($RECURSIVE) {
			&walkdir($dir);
		}
#printf "dir=$dir\n";
		if (-x $dir) {
			&processDir($dir);
		} else {
			print "$dir is not a valid directory\n";
		}
		# print "DIRS = @DIRS\n";
	}
	if ($fileCount == 0) {
		print "Unable to successfully find any $MAKEMMF files.\n";
	}

	return 0;
}

sub cleanup
{
	&'dump_inc if ($DEBUG);
}

################################# SUBROUTNES ##################################

sub walkdir
{
	local($dir) = @_;
	local($file, $full);
	local(@files);

#printf "WALKDIR dir = %s IGNORE_SCM=%d\n", $dir, $IGNORE_SCM;

	if (!opendir(DIR, $dir)) {
		print "ERROR trying to read $dir: $!\n";
		return 1;
	}
	@files = readdir(DIR);
	closedir(DIR);
#print "WALKDIR dir = $dir files = @files\n";
	foreach $file (@files) {
		last if (!defined($file));
		next if ($file eq "." || $file eq ".." || ($IGNORE_SCM && ($file eq 'CVS' || $file eq 'RCS')));
		$full = &path'mkpathname($dir, $file);
		# print "file = $full\n";
		if (-d $full) {
			unshift(@DIRS, $full);
			# print "DIRS = @DIRS\n";
		}
	}
	return 0;
}

sub processDir
{
	local($dir) = @_;
	local($makeArgs);
	local(@makeArgList, @tmpList, @valueList);
	
#print "processDir dir=$dir\n";
	$| = 1;
	local($makemmf_file) = &path'mkpathname($dir, $MAKEMMF);
	if (-r $makemmf_file) {
		local($TIMING) = $DEBUG ? "time" : "";
		
		print "SRCDIR=$dir\n" if ($RECURSIVE || $DEBUG);
		++$fileCount;
		local($makefile) = &path'mkpathname($dir, $MAKEFILE);
		if ($DOMAKEMF) {
			&os'rmFile($makefile);
			&os'run_cmd("$TIMING makemf -f $makemmf_file -o $makefile MAKEMMF=$MAKEMMF MAKEFILE=$MAKEFILE RWD=$dir", ! $QUIET);

			#
			# Check to make sure the the makefile doesn't have an
			# mtime in the future (this can easily happen over NFS).
			# If it does, then reset the mtime to current local time.
			#
			local($makeFileTime) = &os'modTime($makefile);
			if (!defined($makeFileTime)) {
				print "ERROR: $p, Makefile does not exist and should at this point.\n";
				return 1;
			}
			local($curTime) = time;
			if ($curTime < $makeFileTime) {
				printf("Reseting the time/date stamp of $makefile to local now (diff=%d)\n", $makeFileTime - $curTime) unless $QUIET;
				utime($curTime, $curTime, $makefile);
			}
		}

		return if (! $DOMAKE);

		local(@SPEC_TARGETS) = ();
		local(@GLEANED_TARGETS) = ();
		local(@RC_TARGETS) = ();
		local(@NEW_TARGETS) = ();

		# if TARGET_OS_LIST is defined...
		if (defined($MVARDEFS{'TARGET_OS'})) {
			@SPEC_TARGETS = split(',', $MVARDEFS{'TARGET_OS'});
#printf "SPEC_TARGETS=(%s)\n", join(',', @SPEC_TARGETS);
		}

		if ($GLEAN_TARGETS) {
			local(%targets);

			local($mapfn) = &path'mkpathname($dir, $INSTALL_MAP);
			if (&glean_targets(*targets, $mapfn)) {
				@GLEANED_TARGETS = (keys %targets);
			}
#printf "GLEANED_TARGETS=(%s), dir=%s INSTALL_MAP=%s\n", join(',', @GLEANED_TARGETS), $dir, $INSTALL_MAP;
		}

		#process the RC file::
		if ($DO_RCFILE) {
			#WARNING:  this routine over-rides original defs:
			if (&readRcFile(&path'mkpathname($dir, $rcFile))) {
				@RC_TARGETS = split(',', $MVARDEFS{'TARGET_OS'});
#printf "RC_TARGETS=(%s)\n", join(',', @RC_TARGETS);
			}
		}

		if ($GLEAN_TARGETS && $#GLEANED_TARGETS >= 0) {
			@NEW_TARGETS = @GLEANED_TARGETS;
		}

		#RC targets override GLEANED:
		if ($DO_RCFILE && $#RC_TARGETS >= 0) {
			@NEW_TARGETS = @RC_TARGETS;

			#print a warning if we just overrode one or more gleaned targets:
			local (@tmp) = &list'MINUS(*GLEANED_TARGETS, *RC_TARGETS);
			if ($#tmp >= 0) {
				printf "%s:  WARNING: RC file %s in %s over-riding gleaned targets: (%s)\n",
					$p, $rcFile, $dir, join(',', @tmp);
			}
		}

		if ($#NEW_TARGETS < 0) {
			@NEW_TARGETS = @SPEC_TARGETS;
#printf "NEW_TARGETS A=(%s) SPEC_TARGETS=(%s)\n", join(',', @NEW_TARGETS), join(',', @SPEC_TARGETS);
		} else {
#printf "NEW_TARGETS B=(%s)\n", join(',', @NEW_TARGETS);
			#reduce by spec'ed targets:
			if ($#SPEC_TARGETS >= 0) {
				@NEW_TARGETS = &list'AND(*NEW_TARGETS, *SPEC_TARGETS);
#printf "reduced NEW_TARGETS=(%s)\n", join(',', @NEW_TARGETS);
			}
		}

		if ($#NEW_TARGETS >= 0) {
			&reset_mvar('TARGET_OS', join(',', (sort @NEW_TARGETS)));
			printf "%s:  building for (%s)\n", $p, $MVARDEFS{'TARGET_OS'} unless $QUIET;
		} else {
			###
			#if we reduced the target list to none, and TARGET_OS_LIST is
			#defined in the env, then pass TARGET_OS="" to make.
			#otherwise, run make without a TARGET_OS def on the command line.
			###
			&reset_mvar('TARGET_OS', "") if (defined($MVARDEFS{'TARGET_OS'}));
		}

		# Now let the variable definitions from the command line
		# override everything else.
		foreach $var (keys %VARDEFS) {
			$MVARDEFS{$var} = $VARDEFS{$var};
			printf("command line: %s = '%s'\n", $var, $MVARDEFS{$var}) unless $QUIET;
		}
		
		@makeArgList = ();
		if (defined($MVARDEFS{"MAKE_TARGET"})) {
			# Special case for the MAKE_TARGET, because it's the only
			# one which may vary and should not say varname=value.
			@makeArgList = split($VALUELISTSEPARATOR, $MVARDEFS{"MAKE_TARGET"});
		}
		foreach $mdvar (keys %MVARDEFS) {
			# We already did the MAKE_TARGET.
			next if ($mdvar eq "MAKE_TARGET");
			@tmpList = ();
			@valueList = split($VALUELISTSEPARATOR, $MVARDEFS{$mdvar});
			if ($#valueList+1 == 0) {
				@valueList = ("");
			}
			foreach $value (@valueList) {
				@lst = &prepend_onto_list("$mdvar=\"$value\" ", @makeArgList);
				push(@tmpList, @lst);
				# print "mdvar=$mdvar value=$value lst=(" . join(",", @lst) . ")\n";
			}
			@makeArgList = @tmpList;
			# print "mdvar=$mdvar makeArgList=(" . join(",", @makeArgList) . ")\n";
		}

		# If makeArgList is empty, we should do one make with no arguments.
		@makeArgList = ("") if (!@makeArgList);
		# print "makeArgList: (" . join(",", @makeArgList) . ")\n";
	
 		foreach $makeArgs (@makeArgList) {
			local($extraArgs) = "";
			if ($NOP_FLAG) {
				$extraArgs = "-n";
			}
 			print "\n" unless $QUIET;
			print "before\n" if ($DEBUG);
 			&os'run_cmd("cd $dir ; $TIMING $MAKECMD -k -f $MAKEFILE $extraArgs $makeArgs", ! $QUIET);
			print "after\n" if ($DEBUG);
 		}

		&restore_mvars();		#restore make variables if they where changed
	}
	return 0;
}

sub readRcFile
	# Read the rc file and interpret it's contents.
	# Typical contents:
	#    VAR1=blah,blah
	#    VAR2=blah
	#Returns 1 if file read, otherwise 0;
{
	local($filename) = @_;
	local($line, $var, $value);

	if (! -e $filename) {
		if (! $RECURSIVE && ! $QUIET) {
			print STDERR "$filename does not exist.\n";
		}
		return 0;
	}
	if (!open(RC, $filename)) {
		print STDERR "Unable to read $filename: $!\n";
		return 0;
	}
	print "about to read $filename as an rc file\n" if ($DEBUG);
	while (defined($line = <RC>)) {
		chop($line);
		$line =~ s/#.*//;			#delete comments
		next if ($line =~ /^\s*$/);	#skip empty lines

		($var, $value) = split(/\s*=/, $line);
		&reset_mvar($var, $value);

		printf("%s:  %s = '%s'\n", $filename, $var, $value) unless($QUIET);
	}
	close(RC);
	return 1;
}

sub save_mvars
#save initial values of make variable defs.
{
	local ($var, $value);
	while(($var, $value) = each %MVARDEFS) {
		$SAVED_MVARDEFS{$var} = $value;
	}
	$MVARS_DIRTY = 0;
}

sub reset_mvar
{
	local ($kk, $vv) = @_;

	#don't make dirty unless we have to:
	return if (defined($MVARDEFS{$kk}) && $MVARDEFS{$kk} eq $vv);

	$MVARDEFS{$kk} = $vv;
	$MVARS_DIRTY = 1;
}

sub restore_mvars
# Put the variables from %SAVED_MVARDEFS back into %MVARDEFS.
{
	local($kk, $vv);

	return unless ($MVARS_DIRTY);

	%MVARDEFS = %SAVED_MVARDEFS;
	$MVARS_DIRTY = 0;
}

sub prepend_onto_list
# This is basicaly a scalar times by a vector.
# Every item in <vec> will have <sca> concatenated onto the front of
# the return list.
# If <vec> is empty, then we return <sca> as a list.
# eg: input:  sca = a   vec = (b,c,d)
#     output: (ab,ac,ad)
{
	local($sca, @vec) = @_;
	local($dir);
	local(@outList) = ();

	if ($#vec+1 <= 0) {
		@outList = ($sca);
	} else {
		foreach $dir (@vec) {
			push(@outList, $sca . $dir);
			# print "Just pushed $sca onto $dir\n";
		}
	}
	return @outList;
}	

sub ReadInFileList
{
	local($fileList) = @_;
	local(@files) = ();
	local($file, $dir);

	open(FILELIST, $fileList) || die "Unable to open $fileList for read: $!\n";
	push(@files, <FILELIST>);
	close(FILELIST);

	foreach $file (@files) {
		$file =~ s#/[^/]*$##;
		$dirList{$file} = 1;
	}
	foreach $dir (sort keys %dirList) {
		if (! -d $dir) {
			if (-d "$SRCROOT/$dir") {
				chdir("$SRCROOT");
			}
		}
		push(@DIRS, $dir);
	}
}

sub glean_targets
#glean TARGET_OS values from <fn>, and return in <%targets>.
#returns 1 if successful, otherwise 0.
{
	local(*targets, $fn) = @_;

	if (!open(INFILE, $fn)) {
		printf("%s not available.\n", $fn) unless ($QUIET);
		return 0;
	}

	%targets = ();	#result

	while(<INFILE>) {
		chop;
		next unless (/TARGET_OS/);
		next unless (/=/);
		@rec = split('=', $_);

		return 0 if ($#rec < 1);

		$rval = $rec[1];
		# Remove any munges that take arguments, since those arguments
		# are also separated by commas.
		$rval =~ s/\([^\(\)]*\)//g;
		@rec = split(',', $rval);
		@rec = $rval if ($#rec < 0);	#only one target
		for (@rec) {
			s/^\s+//;
			s/[\s\|\&\^].*$//;
			$targets{$_} = 1;
		}
	}

	close(INFILE);
	return(1);
}

################################ USAGE & SETUP ################################

sub usage
{
    print <<"!";
Usage: $p [-h] [-r] [-n] [-csv VARNAME=value1,value2...]
          [-rc mmf_defs] [-t make_target1,make_target2...]
          [-base INSTALL_BASE]
          [-glean map_file]
          [-all | -p platform1,platform2...]
          [-nommf] [-nomk] [-mkis makefile_name] [-mmfis mmf_file_name]
          [VAR=value...] [-f fileList] [dirs...]

Options:
 -h     print this usage message & exit.
 -r     recursive - do subdirectories too.
 -n     passed to make (echo commands only)
 -q     quiet: don't be quiet as verbose
 -t make_target1,make_target2...
        After generating the makefile, successively run make with make_target1,
        make_target2, etc.  Note that this option is multplicative with any
        -csv generated substitution.
 -csv VARNAME=value1,value2...valueN
        After generating the makefile, successively run make with VARNAME
        set to value1, value2, etc.  Only one -csv argument is allowed.
 -rc mmf_defs
        read definitions from a file named <mmf_defs> in each directory.
        Lines are of the form VARNAME=value1[,value2...] are taken
        as a -csv option; simple definitions (VAR=value) can appear as well.
 -base INSTALL_BASE
        Shorthand for BASE=<install_base_directory>.
 -p platform1,platform2...
        Shorthand for -csv TARGET_OS=platform1,platform2... This option
        has no effect unless TARGET_OS is defined in the makefile template.
 -all   Shorthand for -csv TARGET_OS=\$TARGET_OS_LIST.  \$TARGET_OS_LIST
        must be defined in the environment.
-glean map_file
        glean TARGET_OS defs from <map_file>. Will build the intersection
		of the gleaned list and TARGET_OS_LIST.
 -nommf Don't do the makemf step (assumes that the Makefile is already there).
 -nomk  Don't do the make step (just generate the Makefile).
 -mkis  Use makefile_name as the name of the makefile to generate.
 -mmfis Use mmf_file_name as the name of the mmf file to feed to makemf.
 -include_scm
        if -r, then include source-control management dirs (CVS, RCS).
 -f fileList  The fileList is a file containing a list of files to
        go through.
 var=value ...
        define <var> to be <value> in the environment passed to make.

Example:
  $p -r -t clean -rc mmfdrv.rc ./src
  $p -p cmn,mac,ntcmn -t install -base \$DISTROOT devdirs testutil
  $p -r DEST=\$DISTROOT -p cmn,mac,nt FORTE_PORT=solsparc tl/src/cmn tl/src/mac
!
}

sub parse_args
#	Process command line arguments.
# VARDEFS is used for the normal variable definitions: VARNAME=value
# MVARDEFS is used for the multidiminsional variables: VARNAME=value1,value2,...
{
    while ($arg = shift @ARGV) {
		if ($arg =~ /^-/) {
			if ($arg eq "-n") {
				$NOP_FLAG = 1;
			} elsif ($arg eq "-csv") {
				$arg = shift @ARGV;
				local(@xx) = split('=', $arg, 2);
				if (@xx) {
					$MVARDEFS{$xx[0]} = $xx[1];
				} else {
					print "improper argument to -csv: $arg\n";
					&usage;
					return 1;
				}
			} elsif ($arg eq "-r") {
				$RECURSIVE = 1;
			} elsif ($arg eq "-include_scm") {
					$IGNORE_SCM = 0;	#don't ignore RCS, CVS subdirs
			} elsif ($arg eq "-F") {
				$VALUELISTSEPARATOR = shift @ARGV;
			} elsif ($arg eq "-p") {
				local($platforms) = shift @ARGV;
				$platforms =~ s/:/,/g;
				$MVARDEFS{"TARGET_OS"} = $platforms;
			} elsif ($arg eq "-t") {
				$MVARDEFS{"MAKE_TARGET"} = shift @ARGV;
			} elsif ($arg eq "-base") {
				$VARDEFS{"BASE"} = shift @ARGV;
			} elsif ($arg eq "-all") {
				if (defined($ENV{'TARGET_OS_LIST'})) {
					$MVARDEFS{"TARGET_OS"} = $ENV{'TARGET_OS_LIST'};
				} else {
					print "TARGET_OS_LIST is not defined in your environment\n";
					print "which is required for the -all flag.\n";
					&usage;
					return 1;
				}
			} elsif ($arg eq "-rc") {
				$DO_RCFILE = 1;
				$rcFile = shift @ARGV;
			} elsif ($arg eq "-glean") {
				$GLEAN_TARGETS = 1;
				$INSTALL_MAP = shift @ARGV;
				if (!defined($INSTALL_MAP) || $INSTALL_MAP eq "") {
					print "$p:  -glean option requires filename argument.\n";
					return 1;
				}
			} elsif ($arg eq "-q") {
				$QUIET = 1;
			} elsif ($arg eq "-h" || $arg eq "-help") {
				&usage;
				return 1;
			} elsif ($arg eq "-debug" || $arg eq "-d") {
				$DEBUG = 1;
			} elsif ($arg eq "-nommf") {
				$DOMAKEMF = 0;
			} elsif ($arg eq "-nomk") {
				$DOMAKE = 0;
			} elsif ($arg eq "-mkis") {
				$MAKEFILE = shift @ARGV;
			} elsif ($arg eq "-mmfis") {
				$MAKEMMF = shift @ARGV;
			} elsif ($arg eq "-f") {
				&ReadInFileList(shift @ARGV);
			} else {
				print "Unknown argument: $arg\n";
				&usage;
				return 1;
			}
		} else {
			if ($arg =~ /=/) {
				local(@xx) = split('=', $arg, 2);
				if (@xx) {
					$VARDEFS{$xx[0]} = $xx[1];
				} else {
					print "improper variable definition: $arg\n";
					&usage;
					return 1;
				}
			} else {
				@DIRS = (@DIRS, $arg);
			}
		}
    }

    if ( defined($ENV{'MAKEDRV_MAKE_COMMAND'}) ) {
        $MAKECMD = $ENV{'MAKEDRV_MAKE_COMMAND'};
		printf "%s:  using make command MAKEDRV_MAKE_COMMAND='%s'\n", $p, $MAKECMD if ($DEBUG);
    }

	@DIRS = ($DOT) if (!@DIRS);
	return 0;
}

sub init_globalsA
{
	$RECURSIVE = 0;
	$NOP_FLAG = 0;
	@DIRS = ();
	@TARGET_OS = ();
	%VARDEFS = ();
	%MVARDEFS = ();
	%SAVED_MVARDEFS = ();
	@platforms = ();
	$DEBUG = 0;
	$QUIET = 0;
	$MVARS_DIRTY = 0;
	$GLEAN_TARGETS = 0;
	$DO_RCFILE = 0;
	$INSTALL_MAP = "install.map";

	$IGNORE_SCM = 1;	#default is to ignore RCS, CVS subdirs

    # package global variables
	$fileCount = 0;
    # the arguments to give to make (from the command line)
	$makeargs = "";
	# whether or not to generate the Makefiles
	$DOMAKEMF = 1;
	# whether or not to call make
	$DOMAKE = 1;
	# If rcFile is not null, then we use that filename as a file to
	# read -csv variables in through.
	$rcFile = "";

	$MAKECMD = "make";
	$SRCROOT = $ENV{'SRCROOT'};
}

sub init_globalsB
{
}

sub init_env
#copy VARDEFS into environment:
{
	local ($kk, $vv);
	while (($kk, $vv) = each %VARDEFS) {
		$ENV{$kk} = $vv;
	}
}
