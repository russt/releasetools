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
# @(#)suffix.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# suffix.pl
# information about suffixes (type of file)
#

package suffix;

&init;
sub init
{
	$p = $'p;

	$DEBUG = 0;
	$VERBOSE = 0;

	&ResetSuffixTable;
}

sub ResetSuffixTable
	# Clear the suffix table, so that we know nothing about any suffixes.
{
	%SUFFIX = ();
	$LastReadSuffixDat = "";
}

sub ReadSuffixDat
	# Read in suffix information.
	# return 1 if errors in file.
	# The layout of the suffix data file should be:
	#   <suffix> <type>
	# eg:
	#   c text
	#   bat text
	#   zip binary
	#
	# If we try to read the same file twice, the call is ignored
	# unless $force is true.  If we try to read another file after
	# already having read 1, then return an error unless $force is
	# true.  (See ResetSuffixTable)
	# $force may be undef
{
	local($filename, $force) = @_;
	local($cnt, $line);
	local(@rec);

	if (!defined($force)) {
		$force = 0;
	}
	if (! $force) {
		if ($LastReadSuffixDat ne "") {
			if ($filename eq $LastReadSuffixDat) {
				# Just rereading the same file.
				return 0;
			} else {
				# We've already loaded one file, don't read another.
				print STDERR "$p: BUILD_ERROR: attempt to load another suffix file '$filename'\n";
				return 1;
			}
		}
	}

	if (!open(INFILE, $filename)) {
		printf STDERR ("%s:  BUILD_ERROR:  can't open suffix file '%s'\n", $p, $filename);
		return 1;
	}

	$cnt = 0;
	while (defined($line = <INFILE>)) {
		chop($line);
		++$cnt;

		@rec = split(/\s+/, $line);

		if ($#rec+1 != 2) {
			printf STDERR ("%s:  BUILD_WARNING: bad suffix record in %s, line %d\n", $p, $filename, $cnt);
			next;
		}

		#use this array to keep track of frequencies of occurence:
		$SUFFIX{$rec[0]} = $rec[1];
	}

	close INFILE;
	$LastReadSuffixDat = $filename;
	return 0;
}

sub TypeOfFile
	# given the suffix, figure out what type it is
{
	local($suffix) = @_;

	if (!defined($suffix)) {
		return "suffix_not_defined";
	}
	if (defined($SUFFIX{$suffix})) {
		return $SUFFIX{$suffix};
	}
	return "unknown";
}

sub IsBinary
	# return 1 if the suffix is of type binary; otherwise, return 0
{
	local($suffix) = @_;
	
	if (!defined($suffix)) {
		return 0;
	}
	if (&TypeOfFile($suffix) eq "binary") {
		return 1;
	} else {
		return 0;
	}
}

sub IsText
	# return 1 if the suffix is of type text; otherwise, return 0
{
	local($suffix) = @_;
	
	if (!defined($suffix)) {
		return 0;
	}
	if (&TypeOfFile($suffix) eq "text") {
		return 1;
	} else {
		return 0;
	}
}

sub IsKnownType
	# return 1 if the suffix has a known type; otherwise, return 0
{
	local($suffix) = @_;

	if (!defined($suffix)) {
		return 0;
	}
	if (defined($SUFFIX{$suffix})) {
		return 1;
	} else {
		return 0;
	}
}

sub CompareSuffix
# return 1 if the suffix matches target; otherwise return 0.
{
	local($suffix, $target) = @_;

	if (!defined($suffix) || !defined($target)) {
		return 0;
	}
	if ("$suffix" eq "$target") {
		return 1;
	}
	return 0;
}

1;
