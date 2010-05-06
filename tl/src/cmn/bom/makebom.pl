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
# @(#)makebom.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# make bom files
#

package makebom;

$DEBUG = 0;

&'require_os;
require "path.pl";
require "suffix.pl";

sub main
{
	(*ARGV, *ENV) = @_;
	$topErrorCount = 0;
	
	&init;
	local($status) = 0;
	$status = &parse_args;
	if ($status != 0) {
		return (0) if ($status == 2);   #not an error to ask for help.
		return $status;
	}

	local($nn) = 0;
	while ($xx = shift(@dirList)) {
		++$nn;
		if ($FILES_OPT == 1) {
			if ($nn == 1) {
				printf("mkdir 0%o $prefixDst\n", 0775);
				print "\nset SRC_DIR $prefixSrc\n";
				if ($BIN_OPT ==1) {
					print "set BIN_SRC $bprefixSrc\n";
				}
				print "set DST_DIR $prefixDst\n";
			}
			$topErrorCount += &BomifyFile($xx, &path'tail($xx));
		} else {
			$topErrorCount += &Bomify($xx);
		}
	}

	return $topErrorCount;
}

sub init
{
	$p = $'p;
	@dirList = ();

	$SRCROOT = $ENV{"SRCROOT"} || "";

	$prefixSrc = "";
	$prefixDst = "";
	
	local($suffix_file);
	$suffix_file = &path'mkpathname($SRCROOT, "bdb", "suffix.dat");
	if (-e $suffix_file) {
		&suffix'ReadSuffixDat($suffix_file);
	} else {
	printf STDERR "%s:  $BUILD_ERROR: cannot open suffix file, %s\n", $p, $suffix_file;  
	}
}

sub cleanup
{
}

sub parse_args
{
	$BIN_OPT = 0;
	$FILES_OPT = 0;

	while ($arg = shift(@ARGV)) {
		if ($arg eq "-h" || $arg eq "-help") {
			&usage;
			return 2;
		} elsif ($arg eq "-d" || $arg eq "-debug") {
			$DEBUG = 1;
		} elsif ($arg eq "-C" || $arg eq "-c") {
			local($dir) = shift @ARGV;
			if (!chdir($dir)) {
				&bom_error("Unable to chdir to '$dir'");
				return 1;
			}
		} elsif ($arg eq "-prefixSrc") {
			$prefixSrc = shift @ARGV;
		} elsif ($arg eq "-bprefixSrc") {
			$bprefixSrc = shift @ARGV;
			$BIN_OPT = 1;
		} elsif ($arg eq "-prefixDst") {
			$prefixDst = shift @ARGV;
		} elsif ($arg eq "-files") {
			$FILES_OPT = 1;
		} elsif ($arg =~ /^-/) {
			&bom_error("Unknown argument '$arg'");
			&usage;
			return 1;
		} else {
			push(@dirList, $arg);
		}
	}
	if ($#dirList+1 == 0) {
		&bom_error("Not enough arguments.\n");
		&usage;
		return 1;
	}
	return 0;
}

sub usage
{
	print <<"!";
Usage: $p [-help] [-debug] [-C dir] [-files] [-prefixDst string]
        [-prefixSrc string] [-bprefixSrc string] bomlist...

Synopsis:
 $p will recursively create a bom file from a list of directories

Options:
 -help       Display this usage message.
 -debug      Display debugging information.
 -C          Change to this directory first.
 -files      Treat <bomlist> as a list of files instead of directories,
             and create entries for each file.
 -prefixSrc  Put this string in front of the SRC_DIR statements.
 -prefixDst  Put this string in front of the DST_DIR statements.
 -bprefixSrc Define a BIN_SRC var, and prefix it with this string.
             Use BIN_SRC in all statements containing binary files.
             (used by mvs390).

Examples:
  $p -prefixSrc "<SRCROOT>" -C /forte1/d inc
  $p -prefixSrc "<RELEASE>" -bprefixSrc "<BIN_RELEASE>" -C /cure3/wf/d/release/cmn userapp appdist

!
}

#############################################################################

sub Bomify
{
	local($dir) = @_;
	local($file);
	local(@lsout) = ();
	local($dirMode, $fileMode, $type, $firstFile);

	if (! -d $dir) {
		&bom_error("$dir is not a directory.");
		return 1;
	}
	$dirMode = &os'mode($dir) & 0777;
	
	&path'ls(*lsout, $dir);
	printf("mkdir 0%o $prefixDst$dir\n", $dirMode);
	$firstFile = 1;
	foreach $file (sort @lsout) {
		$fullFileName = &path'mkpathname($dir, $file);
		if (-d $fullFileName) {
			# Push it onto the list of directories to do.
			unshift(@dirList, $fullFileName);
		} else {
			if ($firstFile) {
				$firstFile = 0;
				print "\nset SRC_DIR $prefixSrc/$dir\n";
				if ($BIN_OPT ==1) {
					print "set BIN_SRC $bprefixSrc/$dir\n";
				}
				print "set DST_DIR $prefixDst/$dir\n";
			}
			&BomifyFile($fullFileName, $file);
		}
	}
	if (! $firstFile) {
		print "\n";
	}
	return 0;
}

sub BomifyFile
{
	local($fullFileName, $file) = @_;
	local($suffix, $srcstr);

	$fileMode = &os'mode($fullFileName);
	if (!defined($fileMode)) {
		&bom_error("Unexpected error: $fullFileName doesn't seem to exist.");
	}
	$fileMode = $fileMode & 0777;
	$suffix = &path'suffix($file);
	if (&suffix'IsKnownType($suffix)) {
		$type = &suffix'TypeOfFile($suffix);
	} else {
		$type = "binary";
	}

	if ($BIN_OPT ==1 && $type eq  "binary") {
		$srcstr = "<BIN_SRC>";
	} else {
		$srcstr = "<SRC_DIR>";
	}

	printf "%s|0%o|$type|%s|<FILE>|<DST_DIR>\n", $file, $fileMode, $srcstr;
}

sub bom_error
#generate special "raise BUILD_ERROR" statement, which is recognized
#by the bom parsing routines.
{
	local ($msg) = @_;

	print STDERR "raise BUILD_ERROR: $p: $msg\n";
}

1;
