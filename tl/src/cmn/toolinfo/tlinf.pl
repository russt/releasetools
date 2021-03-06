package tlinf;		#routines to read a tools src->dst map file.

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
# @(#)tlinf.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


&init;

sub init
{
	$VERBOSE = 0;
	&unset_verbose;

	$MAP_FS = "\t";		#field separator
	$MAP_NF = 6;
	($MAP_SRCDIR, $MAP_TARGET_OS, $MAP_SRCFILE, $MAP_INSTALLFILE,
		$MAP_INSTALLDIR, $MAP_MODE) = (0..$MAP_NF-1);

#Example:
#SRCDIR=tl/src/vaxvms/tools
#vaxvms	bhypehlp.com	build_hyperhlp.com	/forte1/d/tools/dist/bin/bld/vaxvms	555
}

sub set_verbose
{
	$VERBOSE = 1;
}

sub unset_verbose
{
	$VERBOSE = 0;
}

sub cleanmap
#if the db has been regenerated using the -gen option,
#then read it in and return true.
{
	local (*DB, $fn) = @_;
	local ($ret) = 0;

	if (!open(INFILE, $fn)) {
		return(0);	#read_db will handle error
	}

	$_ = <INFILE>;		#read first record
	if(/^#clean printmap/) {
		@DB = <INFILE>;
		$ret = 1;
		printf STDERR ("Read %d records from clean printmap file '%s'.\n",
			$#DB, $fn) if ($VERBOSE);
	}

	close(INFILE);
	return($ret);
}

sub read_db
#read the tool info file into a list.  recognize "clean printmap" 
#files that have been generated by -gen option.
#returns 1 if successful
{
	local (*DB, $fn) = @_;
	local ($ret) = 0;
	local ($p) = "tlinf (read_db)";

	if (&cleanmap(*DB, $fn)) {
		return(1);
	}

	#otherwise, raw output from "make printmap"
	if (!open(INFILE, $fn)) {
		printf STDERR ("%s:  can't open %s\n", $p, $fn);
		return(0);
	}

	local ($srcdir) = "";
	local ($scnt, $rcnt, $badrecs) = (0,0,0,0);
	local (@xx) = ();
	local(@rec) = ();

	local($linecnt) = 0;
	while (<INFILE>) {
		++$linecnt;
		if (/^SRCDIR/) {
			chop; ++$scnt;
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

	return(1);
}
1;
