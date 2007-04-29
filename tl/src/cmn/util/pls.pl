package pls;	#portable version of the ls command

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
# @(#)pls.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


#require "dumpvar.pl";
require "path.pl";
require "listutil.pl";

$p = $'p;		#$main'p is the program name set by the skeleton

&init;		#init globals

sub main
{
	local(*ARGV, *ENV) = @_;

	&init;		#init globals
	#set global flags:
	if (&parse_args != 0) {
		return 1;
	}

#printf("argc=%d, argv=(%s)\n", $#ARGV, join(',', @ARGV));

	if ($#ARGV >= 0) {
		@DIRS = @ARGV;
	} else {
		@DIRS = $'DOT;		#portable form for the current dir
	}

	for $ff (@DIRS) {
		if (!&pls($ff)) {
			printf STDERR ("%s:  can't open '%s'\n", $p, $ff);
		}
	}

	return 0;
}

sub pls
{
	local($fn) = @_;
	local (@lsout) = ();
	local (@printlist) = ();

	return 0 if (!-e $fn);

	if (!$d_FLAG && -d _) {
		#use portable ls routines to get dir listing:
		if ($a_FLAG) {
			#get all files, including special files:
			&path'ls_all(*lsout, $fn);
		} else {
			#normal directory listing:
			&path'ls(*lsout, $fn);		#use portable ls routine.
		}
	} else {
		@lsout = $fn;
	}

	for $ff (@lsout) {
#printf("ff='%s'\n", $ff);
		if ($F_FLAG) {
			@printlist = (@printlist, &F_opt($fn, $ff));
		} elsif ($l_FLAG) {
			@printlist = (@printlist, &l_opt($fn, $ff));
		} else {
			@printlist = (@printlist, $ff);
		}
	}

	&display_dir(*printlist);
	return 1;
}

sub display_dir
{
	local (*printlist) = @_;
	local ($multicol) = !($l_FLAG);

	local ($maxwidth) = 0;
	local ($col, $maxcol, $len, $didnl) = (0, 0, 0, 0);

	#set maxwidth:
	local ($ll) = 0;
	for (@printlist) {
		$ll = length($_);
		$maxwidth = $ll if ($ll > $maxwidth);
	}
	$maxwidth += 2;
	$maxcol = &num'ceiling($SCREEN_WIDTH/$maxwidth) -1;

	if ($maxcol < 1 || $maxwidth > $SCREEN_WIDTH) {
		$maxwidth = $SCREEN_WIDTH;
		$maxcol = 1;
	}

#printf "maxcol=%d maxwidth=%d SCREEN_WIDTH=%d\n", $maxcol, $maxwidth, $SCREEN_WIDTH;

	if (!$multicol || $maxcol <= 1) {
		for (@printlist) {
			print "$_\n";
		}
		return;
	}

	#
	# TRANSPOSE
	#
	local (@newlist) = (sort @printlist);
#printf("BEFORE: (%s)\n", join(',', @newlist));
	@printlist = &list'rows2columns(*newlist, $maxcol);

#printf("AFTER:  (%s)\n", join(',', @printlist));
#return;

#$cnt = 0;
#for (@printlist) {
#	printf("list[%d]=%s\n",$cnt, defined($_)? $_ : UNDEF);
#	++$cnt;
#}
#return;


	for (@printlist) {
		++$col;
		if ($col >= $maxcol) {
			printf("%s\n", $_);
			$col = 0;
			$didnl = 1;
		} else {
			printf("%-${maxwidth}s", $_);
		}
	}

	print "\n" unless ($didnl);

	return(1);
}

sub ugo
{
	local ($mode) = @_;
	local ($txt)  = "---";
#printf STDERR "ugo mode=%o\n", $mode;
	if ($mode == 7) {
		$txt  = "rwx";
	} elsif ($mode == 6) {
		$txt  = "rw-";
	} elsif ($mode == 5) {
		$txt  = "r-x";
	} elsif ($mode == 4) {
		$txt  = "r--";
	} elsif ($mode == 3) {
		$txt  = "-wx";
	} elsif ($mode == 2) {
		$txt  = "-w-";
	} elsif ($mode == 1) {
		$txt  = "--x";
	}

	return $txt;
}

sub ascii_mode
{
	local ($allmode) = @_;
	local ($ownmode) = ($allmode & 0700) >> 6;
	local ($grpmode) = ($allmode & 0070) >> 3;
	local ($pubmode) = ($allmode & 0007);

#printf STDERR "ascii_mode allmode=%o ownmode=%o grpmode=%o pubmode=%o\n", $allmode, $ownmode, $grpmode, $pubmode;

	return sprintf("%s%s%s", &ugo($ownmode), &ugo($grpmode), &ugo($pubmode));
}

sub ascii_user
{
	local ($uid) = @_;

	return sprintf("%4d", $uid);
}

sub ascii_group
{
	local ($gid) = @_;

	return sprintf("%3d", $gid);
}

sub timeStr
{
	local ($rawtime) = @_;
	return( &sp'GetDateStrFromUnixTime($rawtime) );
}

sub l_opt
{
	local ($dir, $infn) = @_;
	local ($inf) = "";
	local ($fn) = $infn;
	local ($islink) = 0;
	local ($linkto) = "";
	local ($isdir) = 0;
	local ($txt) = "";

	$fn = &path'mkpathname($dir, $infn) if ($dir ne $infn);
	if ($'OS == $'MACINTOSH && !-e $fn) {
#print "OS IS MAC\n";
		#try again with leading ":"
		$fn = &path'mkpathname(":", $dir, $infn) if ($dir ne $infn);
	}

	if (-l $fn) {
		#stat the link, not what it points to:
		$islink = 1;
		@sbuf = lstat(_);
		$linkto = readlink($fn);
	} else {
		$isdir = (-d _);
		@sbuf = stat(_);
	}

	if ($#sbuf < 0) {
		return sprintf("%s - ERROR:  could not stat.\n", $fn);
	}

#printf "dir=%s infn=%s fn=%s #sbuf=%d isdir=%d islink=%d linkto=%s\n", $dir, $infn, $fn, $#sbuf, $isdir, $islink, $linkto;
#ls -ldg foo RCS pls.pl
#lrwxrwxrwx   1 russt    forte          29 Feb 18  1997 RCS -> /forte1/d/tl/src/cmn/util/RCS/
#drwxrwsr-x   2 russt    forte         512 Apr  1 10:28 foo/
#-rw-r--r--   1 russt    forte        4203 Apr  1 10:27 pls.pl

	$txt = sprintf("%s%s %4s %s %s %10d %s %s%s",
		$isdir? "d" : ($islink? "l" : "-"),
		&ascii_mode($sbuf[$MODE]),
		$sbuf[$NLINK],
		&ascii_user($sbuf[$UID]),
		&ascii_group($sbuf[$GID]),
		$sbuf[$SIZE],
		&timeStr($sbuf[$MTIME]),
		$infn,
		$islink? " -> $linkto" : ""
		);

	return($txt);
}

sub F_opt
{
	local ($dir, $infn) = @_;
	local ($inf) = "";
	local ($fn) = $infn;

	$fn = &path'mkpathname($dir, $infn) if ($dir ne $infn);

	if (-l $fn) {
		$inf = '@';
	} elsif (-d _) {
		$inf = $'PS_OUT;
	} elsif (-x _) {
		$inf = '*';
	}
	return("$infn$inf");
}

sub init
{
	#record defs for stat buf:
	$N_STATBUF = 12;
	($DEV, $INO, $MODE, $NLINK, $UID, $GID, $RDEV, $SIZE,
	 $ATIME, $MTIME, $CTIME, $BLKSIZE, $BLOCKS) =  (0..$N_STATBUF);

	#default screen width:
	$SCREEN_WIDTH = 80;
}

sub parse_args
#proccess command-line aguments
{
	local ($flag, $flagstr);

	@LEGAL_FLAGS = ('F', 'l', 'a', 'd', 'sw');

	#clear all flags:
	for $flag (@LEGAL_FLAGS) {
		eval(sprintf('$%s_FLAG = 0;', $flag));
	}

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flagstr = shift(@ARGV);

		if ($flagstr eq "-sw") {
			$sw_FLAG = 1;
			if ($#ARGV >= 0) {
				$SCREEN_WIDTH = shift(@ARGV);
			} else {
				printf STDERR "%s:  -sw flag requires a numerical screen width specification\n", $p;
				return &usage(1);
			}
			if ($SCREEN_WIDTH !~ /\d+/) {
				printf STDERR "%s:  -sw:  non-numerical screen width, '%s'\n", $p, $SCREEN_WIDTH;
				return &usage(1);
			}
			next;
		}

		$flagstr =~ s/^-//;

#printf ("flagstr='%s'\n", $flagstr);

		@flags = split("", $flagstr);	#split into single chars
		for $flag (@flags) {
#printf ("flag='%s'\n", $flag);
			return &usage(1) unless grep($_ eq $flag, @LEGAL_FLAGS);
			#set the flag.  eg. if -f, set fFLAG to 1:
			eval(sprintf('$%s_FLAG = 1;', $flag));
		}
    }

#printf ("FFLAG=%d lFLAG=%d\n", $F_FLAG, $l_FLAG);
#&'dumpvar($p, 'ARGV');
	#remaining arguments in @ARGV

	return 0;
}

sub usage
{
	local($status) = @_;

    print STDERR <<"!";
Usage:  $p [-lFad] [-sw screen_width] [file...]

Options:

 -sw <width>
     set the max screen width to <width> when displaying
     multi-column listings.
 -a  list all files.
 -d  if directory, show directory not its contents.
 -l  List in long  format,  giving  mode, number  of links,
     owner, group, size in bytes, and time of last modification
     for each file.  If the file is a symbolic link (or a Finder
     alias on the Macintosh) the filename is printed followed by
     "->" and the path name of the referenced file.
 -F  Put a slash (/) after each filename if the file  is  a
     directory,  an  asterisk  (*) if the file is an executable,
     and an at-sign (@) if  the  file  is  a  symbolic
     link.
!
    return ($status);
}

sub cleanup
{
}
1;
