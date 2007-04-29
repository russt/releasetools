package dupsrc;	#find duplicate src files from tools map

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
# @(#)dupsrc.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


require "tlinf.pl";
require "pcrc.pl";
require "url.pl";

#################################### MAIN #####################################

sub main
{
	local(*ARGV, *ENV) = @_;

	#set global flags:
	&init;

	return (1) if (&parse_args(*ARGV, *ENV) != 0);
	return (0) if ($HELPFLAG);

	&tlinf'set_verbose if ($VERBOSE);
	&url'set_kshare_server;		#assume dist area is configured for kshare

	for $fn (@MAPFILES) {
		printf STDERR ("%s: working on map file '%s'\n", $p, $fn) if ($VERBOSE);
		@DB = ();
		last if (!&tlinf'read_db(*DB, $fn));
		&find_dups(*DB, $fn);
	}

	return 0;
}

################################# SUBROUTINES #################################

sub find_dups
{
	local (*DB, $fn) = @_;
	local ($pn) = "";
	local($cnt,@rec,$srcfn,$dstdir,$dstfn,%TMP_CRC,$crc,$kk,$vv,@rec_nums);
	local($ntarfiles, $nsymlinks, $nzero_size) = (0,0,0);

#$pcrc'DEBUG = 1;

	$cnt = -1;

	for (@DB) {
		++$cnt;

		@rec = split($FS, $_);
		($srcfn, $dstdir,$dstfn) = (
			$rec[$MAP_SRCFILE], $rec[$MAP_INSTALLDIR], $rec[$MAP_INSTALLFILE]);

		if ($srcfn =~ /\..tz$/) {
			++$ntarfiles;
			next;
		}

		$pn = &url'name_decode("$dstdir/$dstfn");
		if (-l $pn) {
			++$nsymlinks;
			next;
		}
		if (-z _) {
			++$nzero_size;
			next;
		}

		$crc = &pcrc'CalculateFileCRC($pn);

#printf STDERR "pn=%s crc=0x%lX\n", $pn, $crc;

		#store a list of record #'s for each crc:
		if (defined($TMP_CRC{$crc})) {
			$TMP_CRC{$crc} .= "\t$cnt";
		} else {
			$TMP_CRC{$crc} = $cnt;
		}
	}

	if ($VERBOSE) {
		printf STDERR
		("calculated %d crc's, skipped %d tar files, %d zero size, & %d symlinks\n",
			$cnt - ($ntarfiles+ $nzero_size+ $nsymlinks),
			$ntarfiles, $nzero_size, $nsymlinks
		);
	}

	#examine each multiple-crc case:
	while (($kk, $vv) = each %TMP_CRC) {
		next unless $vv =~ $FS;
		@rec_nums = split($FS, $vv);
		if (&count_dups(*DB, *rec_nums) != 0) {
			#at least one src file is different - output list:
			for (@rec_nums) {
				&dump_rec($kk, $DB[$_]);
			}
			print "-----\n";
		}
	}
}
sub dump_rec
{
	local ($crc, $rectxt) = @_;

	@rec = split($FS, $rectxt);
	local($spn) = "$rec[$MAP_SRCDIR]/$rec[$MAP_SRCFILE]";
	local($dpn) = "$rec[$MAP_INSTALLDIR]/$rec[$MAP_INSTALLFILE]";

	printf("%08X %-36s -> %s\n", $crc, $spn, $dpn);
}

sub count_dups
#return the number of different src files that have the same crc.
{
	local (*DB, *rec_nums) = @_;
	local (@rec,$dir,$fn,%DUPS,$ndups);

	for (@rec_nums) {
		@rec = split($FS, $DB[$_]);
		($dir,$fn) = ($rec[$MAP_SRCDIR], $rec[$MAP_SRCFILE]);
		++$DUPS{"$dir/$fn"};
	}

	@rec = (keys %DUPS);
	$ndups = $#rec;
#printf STDERR "count_dups:  found %d dups\n", $ndups;
	return($ndups);
}

sub init
{
	$p = $'p;		#$main'p is the program name set by the skeleton

	$FS				= $tlinf'MAP_FS;
	$MAP_SRCDIR			= $tlinf'MAP_SRCDIR;
	$MAP_SRCFILE		= $tlinf'MAP_SRCFILE;
	$MAP_INSTALLFILE	= $tlinf'MAP_INSTALLFILE;
	$MAP_INSTALLDIR		= $tlinf'MAP_INSTALLDIR;
}

sub parse_args
#proccess command-line aguments
{
	local(*ARGV, *ENV) = @_;
	local ($flag, $arg);

	$HELPFLAG = 0;
	@MAPFILES = ();

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flag = shift(@ARGV);

		if ($flag =~ '^-v') {
			$VERBOSE = 1;
		} elsif ($flag =~ '^-h') {
			$HELPFLAG = 1;
			return(&usage(0));
		} else {
			return(&usage(1));
		}
    }

    #add remaining args:
    if ($#ARGV >= 0) {
		for (@ARGV) {
			next if ($_ eq "");
			@MAPFILES = (@MAPFILES, $_);
		}
	}

	if ($#MAPFILES < 0) {
		@MAPFILES = ("/forte1/d/tlmap.txt");
	}

	return(0);
}

sub usage
{
	local($status) = @_;

    print STDERR <<"!";
Usage:  $p [-h] [-v] [tool_map_files...]

Synopsis:

For each tool_map_file, look for duplicate installed files
that do *not* share a common source file.

Options:
  -h      display usage message.
  -v      verbose messages
!
    return($status);
}

1;
