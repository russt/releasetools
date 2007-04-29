package fixcvsroot;
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
# @(#)fixcvsroot.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


# fixcvsroot - correct all "CVS/Root" entries to be the current $CVSROOT.
#

require "path.pl";
require "walkdir.pl";

&init;

#################################### MAIN #####################################

sub main
{
	local(*ARGV, *ENV) = @_;

	local(%DIRDB, @rec);

	#set global flags:
	return (1) if (&parse_args(*ARGV, *ENV) != 0);
	return (0) if ($HELPFLAG);

	my ($cwd) = &path'pwd;

	if ($cwd eq "NULL" && $#DIRLIST > 0) {
		printf STDERR 
		("%s: sorry, cannot process multiple dirs unless pwd function available\n", $p);
		return(1);
	} elsif ($cwd eq "NULL") {
		$cwd = $DOT;
	}

	%DIRDB = ();
	&walkdir::save_file_info(0);	#we don't need to save file or symlink info - only directories

	for $dir (@DIRLIST) {
		if (($error = &walkdir'dirTree(*DIRDB, $cwd, $dir)) != 0) {
			printf STDERR
			("%s: WARNING:  dirTree failed with error %d while walking %s\n", $p, $error, $dir);
		}
	}

	#find all the CVS directories:
	@CVSDIRS = grep(/\/CVS$/, &walkdir::dir_list(*DIRDB));

	#formulate list of CVS/Root files:
	@cvsRoots = grep($_ = "$_/Root", @CVSDIRS);

	#foreach CVS/Root file...
	my ($nerrs) = 0;
	for $rr (@cvsRoots) {
		$nerrs += &fixcvsroot($rr);
	}

	return($nerrs = 0);
}

sub fixcvsroot
#fix a single CVS/Root file.  return 0 if no errors.
{
	local($rootfn) = @_;

	if (!open(INFILE, $rootfn)) {
		printf STDERR "%s [fixcvsroot]:  ERROR:  cannot open '%s' for reading.\n", $p, $rootfn;
		return 1;
	}

	#we are only interested in the first line:
	my ($oldcvsroot) = <INFILE>;
	close INFILE;
	chomp $oldcvsroot;

	if ($CVSROOT eq $oldcvsroot) {
		printf STDERR "UNCHANGED:  %s:  %s\n", $rootfn, $CVSROOT;
		return 0;
	}

	#set the gleaned CVSROOT to the first that we find:
	$GLEANED_CVSROOT = $oldcvsroot if ($GLEANED_CVSROOT eq "NULL");

	if ($oldcvsroot ne $GLEANED_CVSROOT) {
		printf STDERR "%s [fixcvsroot]:  ERROR:  %s: '%s' != '%s' (gleaned)\n", $p, $rootfn, $oldcvsroot, $GLEANED_CVSROOT;
		printf STDERR "UNCHANGED:  %s:  %s\n", $rootfn, $CVSROOT;
		return 1;
	}

	if ($FIX_CVSROOT) {
		if (!open(OUTFILE, ">$rootfn")) {
			printf STDERR "%s [fixcvsroot]:  ERROR:  cannot open '%s' for writing.\n", $p, $rootfn;
			return 1;
		}

		printf OUTFILE "%s\n", $CVSROOT;
		close OUTFILE;
	}

	printf STDERR "%s%s:  %s -> %s\n", $FIX_CVSROOT? "": "PROPOSED: ", $rootfn, $oldcvsroot, $CVSROOT;

	return 0;
}

################################ USAGE SUBROUTINES ###############################

sub usage
{
	local($status) = @_;

    print STDERR <<"!";
Usage:  $p [-help] [-d cvsroot] [dirs...]

Synopsis:
 Tool to edit CVS/Root files, and make them consistent
 with the current \$CVSROOT setting.

Options:
 -help   display this usage message
 -d root set CVSROOT to <root>.
 -f      apply fix.  default is to just list the changes.

Environment:
 \$CVSROOT   the current CVSROOT, used if -d <root> not given.

Example:
 $p -f -d  :pserver:foouser\@fortecvs:/forte4j

!
    return($status);
}

sub parse_args
#proccess command-line aguments
{
	local(*ARGV, *ENV) = @_;

	$CVSROOT = "NULL";
	$HELPFLAG = 0;
	$FIX_CVSROOT = 0;	#default is non-destructive

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flag = shift(@ARGV);

		if ($flag eq "-d") {
			if ($#ARGV < 0 || $ARGV[0] =~ /^\s*$/) {
				printf STDERR "%s:  -d requires non-empty CVSROOT specification.\n", $p;
				return (&usage(1));
			}
			$CVSROOT = shift(@ARGV);
		} elsif ($flag =~ '^-h') {
			$HELPFLAG = 1;
			return &usage(0);
		} elsif ($flag eq '-f') {
			$FIX_CVSROOT = 1;
		} else {
			printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
			return &usage(1);
		}
    }

	if ($CVSROOT eq "NULL") {
		#get CVSROOT from env if it is defined:
		if (defined($ENV{'CVSROOT'})) {
			$CVSROOT = $ENV{'CVSROOT'};
		} else {
			printf STDERR "%s:  CVSROOT must be defined in environment or with -d option.\n", $p;
			return &usage(1);
		}
	}

    #eliminate empty args (this happens on some platforms):
	@ARGV = grep(!/^$/, @ARGV);

    #take remaining args as directories to process:
    if ($#ARGV < 0) {
		@DIRLIST = $DOT;
    } else {
		@DIRLIST = @ARGV;
	}

	return(0);
}

sub init
{
	$p = $'p;		#$main'p is the program name set by the skeleton
	$DOT = $'DOT;

	$GLEANED_CVSROOT = "NULL";		#consistency check
}

1;
