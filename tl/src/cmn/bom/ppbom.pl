#!/bin/perl -w
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
# @(#)ppbom.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# ppbom.pl
#  pretty print bom

package ppbom;

require "bomparse.pl";
require "bomsuprt.pl";

sub main
{
	local(*ARGV, *ENV) = @_;
	local($errorCount) = 0;

	&Init;
	return 1 if &ParseArgs;
	&PrepBomParse;
	foreach $file (@fileList) {
		if (!chdir($BOMLOC)) {
			&error("Failed to chdir into $BOMLOC\n");
			++$errorCount;
		}
		if (! -r $file) {
			&error("file $file is not readable in directory $BOMLOC\n");
			++$errorCount;
			next;
		}
		$errorCount += &PrettyPrintBOMFile($file);
	}
	return $errorCount;
}

sub Init
{
	# variables from other packages
	$p = $::p;

	# variables that affect the programs direction
	$DEBUG = 0;
	$QUIET = 0;
	$VERBOSE = 0;
	$FILTERDEBUG = 0;
	$totalErrorCount = 0;

	$DEFAULT_DIR_PERM = "0755";
	# whether or not to do variable expansions fully or only partially
	$useExternal = 0;
	# whether or not to print out files with a visual hierachary or to
	# print a file listing.
	$doFlatPrinting = 0;
	# whether or not to print where in the BOM file a particular file
	# came from.
	$from = 0;
	# whether or not to include other BOM files.
	$doInclude = 1;
	# whether or not to print out "decorations"; ie, permissions, file
	# type, etc.
	$DECORATE = 0;
	# variables that the user defined
	%USERVARDEF = ();
	@fileList = ();
	$kitFlagType = "dev";
	$BOMLOC = "";
	$FilterFile = "";
	$Filter = "";
	# The topmost directory to start printing out the heirarchy
	$topPrintDir = "/";
	# Just print out one dir
	$justOneDir = 0;
	# Print just the source file
	$justSrcFile = 0;
	# Print things out in InstallShield5 format
	$installShieldFormat = 0;

	# variables from the environment
	$TARGET_OS = $ENV{'FORTE_PORT'} || "";
}

sub PrepBomParse
{
	&bomsuprt::Init($TARGET_OS, $useExternal);
	&bomsuprt::SetKitType($kitFlagType);
	foreach $var (keys %USERVARDEF) {
		print("Setting $var = $USERVARDEF{$var}\n") unless $QUIET;
		&bomsuprt::SetVar($var, $USERVARDEF{$var});
	}
}

sub ParseArgs
{
	local($arg);
	while ($arg = shift @ARGV) {
		if ($arg =~ /^-/) {
			if ($arg eq "-h" || $arg eq "-help") {
				&Usage;
				return 2;
			} elsif ($arg eq "") {
				# ignore blanks
			} elsif ($arg eq "-C") {
				chdir shift @ARGV;
			} elsif ($arg eq "-decorate" || $arg eq "-dec") {
				$DECORATE = 1;
			} elsif ($arg eq "-nodecorate" || $arg eq "-nodec") {
				$DECORATE = 0;
			} elsif ($arg eq "-from") {
				$from = 1;
			} elsif (lc($arg) eq "-useexternal") {
				$useExternal = 1;
			} elsif (lc($arg) eq "-noexternal" || $arg eq "-nouseexternal") {
				$useExternal = 0;
			} elsif ($arg eq "-flat") {
				$doFlatPrinting = 1;
			} elsif ($arg eq "-bomloc") {
				$BOMLOC = shift @ARGV;
			} elsif ($arg eq "-justone") {
				$justOneDir = 1;
			} elsif ($arg eq "-nojustone") {
				$justOneDir = 0;
			} elsif ($arg eq "-justsrc") {
				$justSrcFile = 1;
			} elsif ($arg eq "-nojustsrc") {
				$justSrcFile = 0;
			} elsif ($arg eq "-include") {
				$doInclude = 1;
			} elsif ($arg eq "-noinclude") {
				$doInclude = 0;
			} elsif ($arg eq "-installShield") {
				$installShieldFormat = 1;
				$doFlatPrinting = 1;
				$useExternal = 1;
			} elsif ($arg eq "-top") {
				$topPrintDir = shift @ARGV;
			} elsif ($arg eq "-dev") {
				$kitFlagType = "dev";
			} elsif ($arg eq "-rtv") {
				$kitFlagType = "rtv";
			} elsif ($arg eq "-fbc") {
				$kitFlagType = "fbc";
			} elsif ($arg eq "-kittype") {
				$kitFlagType = shift @ARGV;
			} elsif ($arg eq "-port") {
				$TARGET_OS = shift @ARGV;
			} elsif ($arg eq "-debug") {
				$DEBUG = 1;
			} elsif ($arg eq "-filterdebug") {
				$FILTERDEBUG = 1;
			} elsif ($arg eq "-parsedebug") {
				$bomparse::DEBUG = 1;
			} elsif ($arg eq "-q") {
				$QUIET = 1;
			} elsif ($arg eq "-noq") {
				$QUIET = 0;
			} elsif (lc($arg) eq "-filter") {
				$FilterFile = shift @ARGV;
			} else {
				print "ERROR: Unrecognized argument '$arg'\n";
				&Usage;
				return 1;
			}
		} else {
			if ($arg =~ /=/) {
				# It's a variable declaration.  Example:
				#  VAR = nt,rs6000,solsparc,alphaosf
				local($varName, $value) = ($arg =~ /(\S+)\s*=\s*(.*)/);
				$USERVARDEF{$varName} = $value;
			} else {
				push(@fileList, $arg);
			}
		}
	}
 	if ($BOMLOC eq "") {
 		$BOMLOC = &path::mkpathname($ENV{'RELEASE_ROOT'}, "bom");
 	}

	# If the the user doesn't specify a bom file to do, then we do the
	# bom file associated with kit type.
	if ($#fileList+1 == 0) {
		if ($kitFlagType eq "dev") {
			$defaultBomFile = ($ENV{"PRODUCT"} || "forte") . ".bom";
		} else {
			$defaultBomFile = $kitFlagType . ".bom";
		}
		print "Defaulting to BOM file $defaultBomFile\n" if ($VERBOSE);
		push(@fileList, $defaultBomFile);
	}

	if ($FilterFile ne "") {
		require "filterFiles.pl";

		print "$p using filter $FilterFile\n";
		$Filter = ""  unless( defined($Filter = &filterFiles::ReadFilter($FilterFile)) );
	}
	
	return 0;
}

sub Usage
{
	print <<"!";
usage: $p [-help] [-bomloc <dir>] [-port <port>] [-flat] [-noinclude]
	[-useexternal|-noexternal] [-decorate|-nodecorate] [-filterdebug]
	[-from] [-justone|-nojustone] [-justsrc|-nojustsrc] [-top <dir>]
    [-installShield] [-filter <filterFile>]
	bomFile

  eg: $p

	  -bomloc  The location of the bom files.
	  -port  Use <port> for the platform.
	  -flat  Don't print in a hierachary (only print files).
	  -noinclude  Don't run thru included files.
	  -useexternal  Use external variables (environment variables).
	  -top <dir> The top directory to starting printing with.
	  -justone   Print out just one directory.
	  -justsrc   Print out just the source file.
	  -decorate  Print out source dir, source file, permission, and type.
	  -from      Print out the source bom file line.
      -filter  Pass the files and directories thru this filter.
      -filterdebug  Print out potentially debugging info while using filters.
      -installShield  Generate an InstallShield 5 File Control List (fgl) file.

  Internal and debugging options:
      -dev -rtv -fbc  Set internal kitFlagType to "dev","rtv","fbc".
      -kittype <arg>  Set internal kitFlagType to <arg>.
      -debug          Set internal DEBUG to 1.
      -filterdebug    Set internal FILTERDEBUG to 1.
      -parsedebug     Set internal $bomparse::DEBUG to 1.
      -q              Set internal QUIET to 1.
      -noq            Set internal QUIET to 0.
!
}

sub error
{
	local($msg) = @_;

	print STDERR "BUILD_ERROR: $p, " . $msg;
	++$totalErrorCount;
}

########################################################################

sub PrettyPrintBOMFile
{
	local($file) = @_;
	local($objNum);
	local($errorCount) = 0;
	
	print "Parsing $file...\n" unless $QUIET;
	$objNum = &bomparse::ReadBOM($file, $doInclude);
	# we get an object number as our handle into the parsed structure
	if ($objNum == $bomparse::invalidObjNum) {
		&error("Failed to parse $file correctly\n");
		return 1;
	}
	if ($bomparse::ParseErrorCount != 0) {
		print "There were parse errors.\n";
		$errorCount += $bomparse::ParseErrorCount;
		$totalErrorCount += $bomparse::ParseErrorCount;
	}

	print "Executing tree...\n" unless $QUIET;
	# This will essentially "execute" the parsed tree; that is,
	# evaluation is done here to determine which branches can be bruned.
	&bomsuprt::ExecuteObjTree($objNum);
	
	$errorCount += &PrettyPrintBOMObj($objNum);
	return $errorCount;
}

sub PrettyPrintBOMObj
{
	local($objNum) = @_;

	%dirContents = ();
	%dirObjNum = ();
	print "Prepping tree...\n" unless $QUIET;
	# BuildDirObjTree will convert the parsed tree into a file
	# tree.  %dirContents is the file tree where an artificial node of
	# "/" marks the start, while the corresponding entries in
	# %dirObjNum will give you the handles into each entry.
	&bomsuprt::BuildDirObjTree($objNum, *dirContents, *dirObjNum);
	return &PrettyPrintTree($topPrintDir, 0);
}

sub PrettyPrintTree
{
	my($topDir, $level) = @_;
	my($dirOrFile, $fullPath, $padding, $i, $myDir);
	my(@bomFiles,@bomDirectories);

	return 0 if (!defined($dirContents{$topDir}));
	$padding = "";
	if (! $doFlatPrinting) {
		for ($i = 0; $i < $level; ++$i) {
			$padding .= "   ";
		}
	}
	local($dirInDirCount) = 0;
	if ($installShieldFormat) {
		if ($level == 0) {
			print "[General]\n";
			print "Type=FILELIST\n";
			print "Version=1.00.000\n";
			print "\n";
			print "[TopDir]\n";
			foreach $myDir (sort split($;, $dirContents{"/"})) {
				next if ($myDir eq "");
				$myFullDir = $myDir;
				if (defined($dirContents{$myFullDir})) {
					$myFullDir =~ s|/|\\|g;
					printf("SubDir%d=%s\n", $dirInDirCount, $myFullDir);
					++$dirInDirCount;
				}
			}
		}
	}

	foreach $dirOrFile (sort split($;, $dirContents{$topDir})) {
		next if ($dirOrFile eq "");
		if ($topDir eq "/") {
			$fullPath = $dirOrFile;
		} else {
			$fullPath = $topDir . "/" . $dirOrFile;
		}
		if (defined($dirContents{$fullPath})) {
			# $fullPath is a directory.
			push(@bomDirectories, [$fullPath, $dirOrFile]);
		} else {
			# $fullPath is a directory.
			push(@bomFiles, [$fullPath, $dirOrFile]);
		}
	}

	# PrettyPrintFiles must be run before PrettyPrintDirectories
	# for the InstallSheild output to be correct.
	my($refBomFileLoc, $refBomDirectoryLoc);
	my($fileInDirCount) = 0;
	foreach $refBomFileLoc (@bomFiles) {
		if($DEBUG) {
			print(STDERR $p,':',__LINE__,":\$refBomFileLoc->[0]=$refBomFileLoc->[0] \$refBomFileLoc->[1]=$refBomFileLoc->[1]  \$level=$level \$padding=$padding \$fileInDirCount=$fileInDirCount\n");
		}
		&PrettyPrintFiles($refBomFileLoc->[0], $refBomFileLoc->[1],
						  $level, $padding, $fileInDirCount);
		$fileInDirCount++;
	}
	foreach $refBomDirectoryLoc (@bomDirectories) {
		if($DEBUG) {
			print(STDERR $p,':',__LINE__,":\$refBomFileLoc->[0]=$refBomFileLoc->[0] \$refBomFileLoc->[1]=$refBomFileLoc->[1]  \$level=$level \$padding=$padding\n");
		}
		&PrettyPrintDirectories($refBomDirectoryLoc->[0], $refBomDirectoryLoc->[1],
								$level, $padding);
	}
	return 0;
}

sub PrettyPrintFiles
{
	my($fullPath, $fileName, $level, $padding, $fileInDirCount) = @_;
	my($objNum, $myDir);
	if($DEBUG) {print(__LINE__.":DEBUG:  FILE \$fullPath=$fullPath \$fileName=$fileName \$level=$level \$padding=$padding\n");}

	$objNum = $dirObjNum{$fullPath};
	if ($Filter ne "" &&
		! &filterFiles::KeepFile($Filter, $fullPath)) {
		print "Skipped $fullPath because of filter\n" if ($FILTERDEBUG);
	} elsif ($installShieldFormat) {
		$myDir = $bomparse::objAttrib4[$objNum];
		$myDir =~ s|/|\\|g;
		printf("file%d=%s\\%s\n", $fileInDirCount, $myDir,
			   $bomparse::objAttrib1[$objNum]);
		++$fileInDirCount;
	} elsif ($justSrcFile) {
		print $padding;
		printf("%s\n",
			   &path::mkpathname($bomparse::objAttrib4[$objNum],
								 $bomparse::objAttrib1[$objNum]));
	} else {
		if ($doFlatPrinting) {
			print "$fullPath";
		} else {
			print $padding;
			print "$fileName";
		}
		if ($DECORATE) {
			# printf("   <- SRC_DIR=%s SRC_FILE=%s PERM=%s TYPE=%s ",
			printf("   <- %s %s %s %s ",
				   $bomparse::objAttrib4[$objNum],
				   $bomparse::objAttrib1[$objNum],
				   $bomparse::objAttrib2[$objNum],
				   $bomparse::objAttrib3[$objNum]);
		}
		if ($from) {
			printf("   file defined %s", &bomparse::ObjLocation($objNum));
		}
		print "\n";
	}
	return 0;
}

sub PrettyPrintDirectories
{
	my($fullPath, $dirName, $level, $padding) = @_;
	if($DEBUG) {print(__LINE__.":DEBUG: DIR \$fullPath=$fullPath \$fileName=$fileName \$level=$level \$padding=$padding\n");}
	my($objNum,$perm, $myDir);

	# print "PrettyPrintTree: $dirName $level\n";
	$objNum = $dirObjNum{$fullPath};
	print __LINE__.":DEBUG: fullPath='$fullPath' objNum='$objNum'\n" if ($DEBUG);
	if ($Filter ne "" &&
		! &filterFiles::KeepFile($Filter, $fullPath . "/")) {
		print "Skipped $fullPath because of filter\n" if ($FILTERDEBUG);
	} elsif ($installShieldFormat) {
		$myDir = $fullPath;
		$myDir =~ s|/|\\|g;
		print "\n[$myDir]\n";
		print __LINE__.":DEBUG: fullPath=[$fullPath] mydir=[$myDir]\n" if ($DEBUG);
		local($myFullDir);
		$dirInDirCount = 0;
		foreach $myDir (sort split($;, $dirContents{$fullPath})) {
			next if ($myDir eq "");
			$myFullDir = $fullPath . "/" . $myDir;
			if (defined($dirContents{$myFullDir})) {
				$myFullDir =~ s|/|\\|g;
				printf("SubDir%d=%s\n", $dirInDirCount, $myFullDir);
				++$dirInDirCount;
			}
		}
	} elsif (! $doFlatPrinting) {
		print $padding;
		print "$dirName/";
		if ($DECORATE) {
			if ($bomparse::objType[$objNum] eq "filemapping") {
				$perm = $DEFAULT_DIR_PERM;
			} else {
				# a mkdir_dcl
				$perm = $bomparse::objAttrib1[$objNum];
			}
			# printf("   <- PERM=%s", $bomparse::objAttrib1[$objNum]);
			printf("   <- %s", $perm);
		}
		if ($from) {
			printf("   dir defined %s", &bomparse::ObjLocation($objNum));
		}
		print "\n";
	}
	if (! $justOneDir) {
		&PrettyPrintTree($fullPath, $level + 1);
	}
	return 0;
}

1;
