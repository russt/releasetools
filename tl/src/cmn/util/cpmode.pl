package cpmode;

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
# @(#)cpmode.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


# cpmode - copy modes & mod times from one file to another.
#
#  25-Mar-96 (russt)
#	Initial revision
#

&init;

#################################### MAIN #####################################

sub main
{
	local(*ARGV, *ENV) = @_;
	local ($status) = 0;

	return (1) if (&parse_args(*ARGV, *ENV) != 0);
	return (0) if ($HELPFLAG);

	$status = &cpmodes($REF_FILE, @TARGET_LIST);

	return $status;

	&squawk_off;	#avoid perl warnings.
}

################################# SUBROUTINES #################################

sub cpmodes
#returns 0 if no errors.
{
	local ($ref, @target_list) = @_;
	local (@refstat, $nerrs, $target);
	
	$nerrs = 0;

#	if (!-e $ref) {
#		printf STDERR ("%s: can't open reference file '%s'.\n", $p, $ref);
#		return 1;
#	}
	@refstat = stat $ref;

	if ($#refstat < 0) {
		printf STDERR ("%s: couldn't stat reference file '%s'.\n", $p, $ref);
		return 1;
	}

	for $target (@target_list) {
		if (!-e $target) {
			printf STDERR ("%s: can't open target file %s.\n", $p, $target);
			++$nerrs;
			next;
		}

		if ($UTIME_FLAG && utime($refstat[$ATIME], $refstat[$MTIME], $target) != 1) {
			printf STDERR ("%s: failed to modify times, file %s.\n", $p, $target);
			++$nerrs;
			next;
		}

		if ($MODE_FLAG && chmod($refstat[$MODE], $target) != 1) {
			printf STDERR ("%s: failed to copy modes, file %s.\n", $p, $target);
			++$nerrs;
			next;
		}
	}

	return $nerrs;
}

sub unset_mode_option
{
	$MODE_FLAG = 0;
}

sub set_mode_option
{
	$MODE_FLAG = 1;
}

sub unset_time_option
{
	$UTIME_FLAG = 0;
}

sub set_time_option
{
	$UTIME_FLAG = 1;
}

############################## USAGE SUBROUTINES ###############################

sub usage
{
	local($status) = @_;

    print STDERR <<"!";
Usage:  $p [-h] [-time] [-mode] reference target_files...

Synopsis:
 Copies last modification time, access time, and mode bits
 from <reference> to <target_files>.

Options:
 -h      show this help message.
 -time   copy times only
 -mode   copy mode bits (permissions) only.

Default:
 $p -time -mode reference target_file

Example:  $p foo.cc foo.o

!
    return($status);
}

sub parse_args
#proccess command-line aguments
{
	local(*ARGV, *ENV) = @_;
	local ($flag);

	$HELPFLAG = 0;
	&unset_time_option;
	&unset_mode_option;

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flag = shift(@ARGV);

		if ($flag =~ '^-h') {
			$HELPFLAG = 1;
			return(&usage(0));
		} elsif ($flag eq '-time') {
			&set_time_option;
		} elsif ($flag eq '-mode') {
			&set_mode_option;
		} else {
			return(&usage(1));
		}
    }

    #take remaining args as command names:
    if ($#ARGV < 1) {
		return(&usage(1));
    } else {
		$REF_FILE = shift(@ARGV);
		@TARGET_LIST = (@ARGV);
	}

	#default if no flags:
	if (!$UTIME_FLAG && !$MODE_FLAG) {
		&set_time_option;
		&set_mode_option;
	}

#printf STDERR "ref=%s targets=(%s)\n", $REF_FILE, join(',', @TARGET_LIST);

	return(0);
}

sub init
{
    $p = $'p;

	$UTIME_FLAG = 1;
	$MODES_FLAG = 1;

	#record defs for stat buf:
	$N_STATBUF = 12;
	($DEV, $INO, $MODE, $NLINK, $UID, $GID, $RDEV, $SIZE,
	 $ATIME, $MTIME, $CTIME, $BLKSIZE, $BLOCKS) =  (0..$N_STATBUF);
}

sub squawk_off {
	if (1 > 2) {
		$DEV = $DEV;
		$INO = $INO;
		$MODE = $MODE;
		$NLINK = $NLINK;
		$UID = $UID;
		$GID = $GID;
		$RDEV = $RDEV;
		$SIZE = $SIZE;
		$ATIME = $ATIME;
		$MTIME = $MTIME;
		$CTIME = $CTIME;
		$BLKSIZE = $BLKSIZE;
		$BLOCKS = $BLOCKS;
	}
}
