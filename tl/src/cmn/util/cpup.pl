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
# @(#)cpup.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# cpup.pl
# copy files up recursively
#

package cpup;

&'require_os;
require "path.pl";

sub main
{
	local(*ARGV, *ENV) = @_;

	&Init;
	return 1 if &ParseArgs;
	return &DoCopyUp;
}

sub Init
{
	$p = $'p;
	
	$DEBUG = 0;
	
	$newerTime = 0;
	@fileList = ();
}

sub ParseArgs
{
	local($arg);
	while ($arg = shift @ARGV) {
		if ($arg =~ /^-/) {
			if ($arg eq "-h" || $arg eq "-help") {
				&Usage;
				return 2;
			} elsif ($arg eq "-newer") {
				local($file);
				$file = shift @ARGV;
				$newerTime = &os'modTime($file);
				if (! defined($newerTime)) {
					print "ERROR reading mtime of $file: $!\n";
					return 1;
				}
			} elsif ($arg eq "") {
				# ignore blanks
			} elsif ($arg eq "-debug") {
				$DEBUG = 1;
			} else {
				print "ERROR: Unrecognized argument '$arg'\n";
				&Usage;
				return 1;
			}
		} else {
			push(@fileList, $arg);
		}
	}
	if ($#fileList+1 < 2) {
		print "ERROR: Not enough arguments\n";
		&Usage;
		return 1;
	}
	return 0;
}

sub Usage
{
	print <<"!";
usage: $p [-help] [-newer file] <srcdirs> <destdir>

   eg: $p -newer .last log port 970721
!
}

sub DoCopyUp
{
	local($destDir, $ddir, $srcDir, $result);
	$result = 0;

	if ($DEBUG) {
		$os'DEBUG = 1;
	}
	$destDir = pop @fileList;
	foreach $srcDir (@fileList) {
		# figure out the destination directory
		$ddir = &path'mkpathname($destDir, &path'tail($srcDir));
		$result += &os'cp_recursive_newer($srcDir, $ddir, $newerTime);
	}
	return $result;
}

1;
