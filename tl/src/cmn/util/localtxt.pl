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
# @(#)localtxt.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# localtxt.pl - convert textfiles to the local parlance.
#            files with NULLS are considered to be binary and are skipped.
#
package localtxt;

require "path.pl";

&init;
sub init
	#copies of global vars from main package:
{
	$p = $'p;		#$main'p is the program name set by the skeleton
	$OS = $'OS;
	$UNIX = $'UNIX;
	$MACINTOSH = $'MACINTOSH;
	$NT = $'NT;
	$DOT = $'DOT;

	$TMPFILE = "";

	#global constants:
	($LF, $CR) = (0x0a, 0x0d);
	$BUFSIZE = 1024*8;
	$SRC_OS = 0;		#set on first call to localtxt
	$WORKFILE = "NULL";
	$FAKEPID = 2727;	#for temp file naming.

	$UNIX_EOL = 101;
	$MAC_EOL = 102;
	$DOS_EOL = 103;
	$LFCR_EOL = 104;

	#options:
	$HELPFLAG = 0;
	$VERBOSE = 0;
	$RECURSIVE = 0;
	$PRESERVE = 0;
	$TEST_MODE = 0;
	$MAXDEPTH = 100;
	$TARGET_OS = 0;
	$FAST_SCAN = 0;		#true if we don't want deep scan for ^M's
	$INDENT = "\t";		#indentation chars for VERBOSE

	%VALID_TARGETS = (
		'UNIX', $UNIX_EOL,
		'MAC', $MAC_EOL,
		'DOS', $DOS_EOL,
	);

}

#################################### MAIN #####################################

sub main
{
	local(*ARGV, *ENV) = @_;

	#set global flags:
	return (1) if (&parse_args(*ARGV, *ENV) != 0);
	return (0) if ($HELPFLAG);

	for $fn (@FILES) {
		if (-d $fn ) {
			if ($RECURSIVE) {
				if (chdir $fn) {
					&dowalk($fn, 0);
				} else {
					print STDERR "WARNING: cannot enter $fn\n";
				}
			} else {
				printf STDERR
					("%s: '%s' is a directory, and -r not specified - skipping\n",
					$p, $fn);
			}
		} else {
			&convert_text($DOT, $fn, 0);
		}
	}

	return(0);
}

############################## LOCALTXT ROUTINES ##############################

sub dowalk
#recursively convert text files in <cwd> to <TARGET_OS> form.
#we assume we are in <cwd>.
{
	local ($cwd, $level) = @_;
	local (@lsout);
	local($fn);

	if ($level > $MAXDEPTH) {
		printf STDERR ("MAX DEPTH exceeded:  %d\t%s\n", $MAXDEPTH, $cwd);
		return;
	}

	&path'ls(*lsout, $DOT);
	if (!@lsout) {
		return;	#empty directory
	} else {
		printf("\n%s<%s>\n", $INDENT x $level, $cwd) if ($VERBOSE);
	}

	#convert files, collect dirs:
	local (@dirs) = ();
	for $fn (@lsout) {
		if (-l $fn) {
			#ignore
		} elsif (-f _ ) {
			&convert_text($cwd, $fn, $level);
		} elsif (-d _ ) {
			@dirs = (@dirs, $fn);
		}
	}

	#now walk sub-directories:
	for $fn (@dirs) {
		if (chdir $fn) {
			&dowalk(&path'mkpathname($cwd, $fn), $level+1);		#RECURSIVE CALL
			chdir "$DOT$DOT";
		} else {
			printf STDERR ("%s:  WARNING: can't cd to '%s'\n",
				$p, &path'mkpathname($cwd, $fn));
		}
	}
}

sub convert_text
#convert <infile> to <TARGET_OS> text form, if a text file.
#return non-zero if non-recoverable error.
#we asume we are in <cwd>, and <infile> is in <cwd>.
{
	local ($cwd, $infile, $level) = @_;
	local ($nchanged, $totalchanged, $totalbytes, $totalobytes, $obufsize, $write_errors);
	local(@obuf) = ();
	local($buf) = "";
	local($isbinary);
	local($ret);
	local($fqfn);

	if ($cwd eq $DOT) {
		$fqfn = $infile;
	} else {
		$fqfn = &path'mkpathname($cwd, $infile);
	}

	$WORKFILE=$infile;	#set global file name for messages.

	if (!open(INFILE, $infile)) {
		printf STDERR ("%s: can't open '%s'\n", $p, $infile);
		return(1);
	}
	binmode INFILE;		#important! o'wise, perl converts to unix EOL under dos.

	if ($OS == $UNIX) {
		$TMPFILE = sprintf("_ltxt_%d.tmp", $$);
	} else {
		$TMPFILE = sprintf("_ltxt_%d.tmp", ++$FAKEPID);
	}

	#### create TMPFILE in same dir as <infile> so we can rename it later.
	$TMPFILE = &path'mkpathname(&path'head($infile), $TMPFILE);

#printf STDERR "infile=%s TMPFILE=%s\n", $infile, $TMPFILE;

	if (!open(TMPFH, ">$TMPFILE")) {
		close INFILE;
		printf STDERR ("%s:  can't open temp file, %s\n", $p, $TMPFILE);
		return(2);;
	} else {
		if ($OS == $NT) {
		    #BUG when running under mks ksh - flush the dir to disk:
		    `ls -l $TMPFILE`;
		}
	}
	binmode TMPFH;

	$nchanged = $totalchanged = $totalbytes = $totalobytes = $obufsize = $write_errors = 0;
	$SRC_OS = 0;	#we don't know the SRC_OS yet...
	$! = 0;		#set errno to 0
	while ($nbytes = read(INFILE, $buf, $BUFSIZE)) {
		# check for binary file:
		$nchanged = &dolocaltxt(*obuf, $buf, $nbytes, $TARGET_OS);
		$isbinary = 1 if ($nchanged < 0);
		last if ($isbinary);

		$totalbytes += $nbytes;
		$totalchanged += $nchanged;

		$! = 0;		#set errno to 0
		if ($nchanged > 0) {
			print TMPFH pack("C*", @obuf);
			$totalobytes += $#obuf+1;
		} else {
			print TMPFH $buf;
			$totalobytes += $nbytes;
		}

		if ($! != 0) {
			#IMPORTANT!! must check for write errors!!
			printf STDERR ("%s: ABORT: error writing to temp file, %s - '%s' (OS Error %d).\n",
				$p, $TMPFILE, $!, $!);
			++$write_errors;
			last;
		}
	}
	close (INFILE);
	close (TMPFH);

	if ($isbinary) {
		printf("%s %s is a binary/unknown file\n", $INDENT x $level, $infile) if ($VERBOSE);
		unlink $TMPFILE; $TMPFILE = "";
		return(0);
	}

	if ($write_errors != 0) {
		unlink $TMPFILE; $TMPFILE = "";
		return(3);
	}

	if ($totalchanged == 0) {
		printf("%s %s is already in the correct format for %s OS\n",
			$INDENT x $level, $infile, &os_str($TARGET_OS)) if ($VERBOSE);
		unlink $TMPFILE; $TMPFILE = "";
		return(0);
	}

	#otherwise, re-write text file:
	local($n_renamed) =  1;
	if (!$TEST_MODE) {
		unlink $infile;
		$n_renamed =  rename($TMPFILE, $infile);
	} else {
		unlink $TMPFILE; $TMPFILE = "";
	}

	if ($n_renamed > 0) {
		if ($VERBOSE) {
			printf("%s%s %s -> %s, %d in, %d out, %d changes.\n",
				 $INDENT x $level,
				 ($TEST_MODE) ? " TESTING -" : "",
				 $infile, &os_str($TARGET_OS),
				 $totalbytes, $totalobytes, $totalchanged);
		} else {
			printf("%s%s converted.\n", ($TEST_MODE) ? "TESTING - " : "", $fqfn);
		}
		unlink $TMPFILE; $TMPFILE = "";
	} else {
		printf STDERR ("%s: couldn't rename %s, '%s'\n", $p, $fqfn, $!);
		printf STDERR ("%s: SAVED OUTPUT IN '%s'\n", $p, $TMPFILE);
		$TMPFILE = "";
		return(4);
	}

	return(0);
}

sub detect_source
#what kind of file are we looking at?
#return OS type or -1 if binary or wierd.
{
	local ($ibuf) = @_;
	local (%possibles);
	local ($cc, $isbinary, $lchar, $ncr, $nlf);

	$lchar = $ncr = $nlf = 0;
	for $cc (unpack("C*", $ibuf)) { #unpack as unsigned chars.
		if ($cc == 0) {
			$isbinary = 1;
			last;
		} elsif ($cc == $LF) {
			++$nlf;
		} elsif ($cc == $CR) {
			++$ncr;
		} elsif ($ncr + $nlf > 0) {
			#look at counts to determine conventions:
			if ($ncr > 0 && $nlf == 0) {
				++$possibles{$MAC_EOL};
			} elsif ($nlf > 0 && $ncr == 0) {
				++$possibles{$UNIX_EOL};
			} elsif ($ncr > 0 && $nlf > 0) {
				if ($lchar == $LF) {
					++$possibles{$DOS_EOL};
				} else {
					++$possibles{$LFCR_EOL};
				}
			}
			#reset counts:
			$nlf = $ncr = 0;
		}
		$lchar = $cc;
	}

	return (-1) if ($isbinary);

	#if only one line, haven't done this yet...
	if ($ncr + $nlf > 0) {
		if ($ncr > 0 && $nlf == 0) {
			++$possibles{$MAC_EOL};
		} elsif ($nlf > 0 && $ncr == 0) {
			++$possibles{$UNIX_EOL};
		} elsif ($ncr > 0 && $nlf > 0) {
			if ($lchar == $LF) {
				++$possibles{$DOS_EOL};
			} else {
				++$possibles{$LFCR_EOL};
			}
		}
	}

	#DOS over-rides unix:
	if (defined($possibles{$DOS_EOL}) && defined($possibles{$UNIX_EOL})) {
		return($DOS_EOL);
	}

	#
	# otherwise, determine the most probable OS - based on frequency of hits of each EOL
	# convention. (note that normally there will only be one type).
	#
	local ($highcnt) = 0;
	local ($probable_os) = -2;		#default is indeterminate
	for (keys %possibles) {
#printf STDERR ("KEY='%s' VAL=%d highcnt=%d\n", $_, $possibles{$_}, $highcnt);
		if ($possibles{$_} > $highcnt) {
			$probable_os = $_;
			$highcnt = $possibles{$_};
		}
	}

#printf STDERR ("probable_os=%d\n", $probable_os);
	return ($probable_os);
}

sub localtxt
#this version is externally callable.
#
# WARNING!! do not change the interface to this routine, as it
#           is used directly by minstall. RT 12/19/96
#
{
	local (*olist, $ibuf, $ibufsize, $os) = @_;
	local ($target);

	#map os target to EOL target:
	if ($os == $NT) {
		$target = $DOS_EOL;
	} elsif ($os == $MACINTOSH) {
		$target = $MAC_EOL;
	} elsif ($os == $UNIX) {
		$target = $UNIX_EOL;
	} else {
		printf STDERR ("localtxt:  BAD TARGET_OS, %d, file '%s'\n", $os, $WORKFILE);
	}

	$SRC_OS = 0;	#we don't know the SRC_OS yet...
	return(&dolocaltxt(*olist, $ibuf, $ibufsize, $target));
}

sub dolocaltxt
#returns -1 if binary string
#returns n bytes rewritten, added, or deleted
#NOTE:  DOS EOL seq is <CR><LF>, MAC is <CR>, and UNIX is <LF>
{
	local (*olist, $ibuf, $ibufsize, $target) = @_;

	if ($SRC_OS == 0) {
		$SRC_OS = &detect_source($ibuf);
		if ($SRC_OS < 0) {
			if ($SRC_OS == -2) {
				printf STDERR ("%s:  file '%s' - indeterminate EOL conventions\n",
					$p, $WORKFILE);
			}
			return ($SRC_OS);
		}
	}

	if ($FAST_SCAN == 1) {
		#no conversion necessary:
		return 0  if ($SRC_OS == $target);
	} else {
		### force a full scan for CR's in files detected as UNIX_EOL.
		### the CR chars are sometimes buried deep in the file, due to cut/paste ops.
		return 0 if ($SRC_OS == $target && $target != $UNIX_EOL);
	}

	local ($nchanged, $isbinary);
	$obufsize = 0;

	$olist[$ibufsize] = 0xff;	#preallocate
	$nchanged = 0;
	$isbinary = 0;

	#
	#  handle all conversion possibilites.  Note that loops are
	#  repeated to optimize for speed.
	#

	if ( ($SRC_OS == $UNIX_EOL || $SRC_OS == $DOS_EOL) && $target == $UNIX_EOL) {
		### note - we can not be in this case with SRC = UNIX if -fast is selected, as
		### we will have returned already during $FAST_SCAN check above.
		for $cc (unpack("C*", $ibuf)) {
			last if ($isbinary = ($cc == 0));
			if ($cc == $CR) {
				++$nchanged;	#delete CR
			} else {
				$olist[$obufsize++] = $cc;
			}
		}
	} elsif ($SRC_OS == $UNIX_EOL && $target == $DOS_EOL) {
		for $cc (unpack("C*", $ibuf)) {
			last if ($isbinary = ($cc == 0));
			if ($cc == $LF) {
				$olist[$obufsize++] = $CR;
				$olist[$obufsize++] = $LF;
				++$nchanged;
			} else {
				$olist[$obufsize++] = $cc;
			}
		}
	} elsif ($SRC_OS == $UNIX_EOL && $target == $MAC_EOL) {
		for $cc (unpack("C*", $ibuf)) {
			last if ($isbinary = ($cc == 0));
			if ($cc == $LF) {
				$olist[$obufsize++] = $CR;
				++$nchanged;
			} else {
				$olist[$obufsize++] = $cc;
			}
		}
	} elsif ($SRC_OS == $DOS_EOL && $target == $MAC_EOL) {
		for $cc (unpack("C*", $ibuf)) {
			last if ($isbinary = ($cc == 0));
			if ($cc == $LF) {
				++$nchanged;	#delete LF
			} else {
				$olist[$obufsize++] = $cc;
			}
		}
	} elsif ($SRC_OS == $MAC_EOL && $target == $UNIX_EOL) {
		for $cc (unpack("C*", $ibuf)) {
			last if ($isbinary = ($cc == 0));
			if ($cc == $CR) {
				$olist[$obufsize++] = $LF;
				++$nchanged;
			} else {
				$olist[$obufsize++] = $cc;
			}
		}
	} elsif ($SRC_OS == $MAC_EOL && $target == $DOS_EOL) {
		for $cc (unpack("C*", $ibuf)) {
			last if ($isbinary = ($cc == 0));
			if ($cc == $CR) {
				$olist[$obufsize++] = $CR;
				$olist[$obufsize++] = $LF;
				++$nchanged;
			} else {
				$olist[$obufsize++] = $cc;
			}
		}
	} elsif ($SRC_OS == $LFCR_EOL && $target == $UNIX_EOL) {
		for $cc (unpack("C*", $ibuf)) {
			last if ($isbinary = ($cc == 0));
			if ($cc == $CR) {
				++$nchanged;	#delete CR
			} else {
				$olist[$obufsize++] = $cc;
			}
		}
	} elsif ($SRC_OS == $LFCR_EOL && $target == $MAC_EOL) {
		for $cc (unpack("C*", $ibuf)) {
			last if ($isbinary = ($cc == 0));
			if ($cc == $LF) {
				++$nchanged;	#delete LF
			} else {
				$olist[$obufsize++] = $cc;
			}
		}
	} elsif ($SRC_OS == $LFCR_EOL && $target == $DOS_EOL) {
		for $cc (unpack("C*", $ibuf)) {
			last if ($isbinary = ($cc == 0));
			if ($cc == $CR) {
				$olist[$obufsize++] = $CR;
				$olist[$obufsize++] = $LF;
				++$nchanged;
			} elsif ($cc == $LF) {
				; #delete LF
			} else {
				$olist[$obufsize++] = $cc;
			}
		}
	} else {
		printf STDERR ("localtxt:  bad (SRC, TARGET) = (%d, %d)\n", $SRC_OS, $target);
		return(-1);
	}

	return(-1) if ($isbinary);

	if ($nchanged > 0) {
		$#olist = $obufsize-1;
#printf STDERR ("#olist=%d obufsize=%d\n", $#olist, $obufsize);
	}

#printf STDERR ("locatxt() nchanged=%d\n", $nchanged);
	return($nchanged);
}

sub os_str
{
	local ($osnum) = @_;
	for (keys %VALID_TARGETS) {
		return ($_) if ($VALID_TARGETS{$_}  == $osnum);
	}
	return ("UNKNOWN");
}

################################ USAGE SUBROUTINES ###############################

sub usage
{
	local($status) = @_;
	local ($VALID) = join(',',sort keys %VALID_TARGETS);

    print STDERR <<"!";
Usage:  $p [-h] [-t] [-v] [-fast] -os target filenames ...
        $p [-h] [-t] [-v] [-fast] -os target [-r] [directories] ...

Synopsis:
  Convert text files to the local machine conventions.
  Files containing ASCII NULLS are ignored.

Options:
  -h    display this usage message and exit.
  -t    test mode - show the conversion, but don't do it.
  -v    verbose output
  -fast only check the first $BUFSIZE chars for DOS EOL conventions.
        normally, will scan the full file.
  -r    recursive - take names to be a list of directories,
        and convert all files contained therein. If list
        is missing, then start with current directory.
  -os target
        convert to target os conventions, which must be one of:
        {$VALID} (case ignored).

Example:  $p dosfile.txt
!
    return($status);
}

sub parse_args
#proccess command-line aguments
{
	local(*ARGV, *ENV) = @_;

	local ($flag, $arg);

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flag = shift(@ARGV);

		if ($flag =~ /^-v/) {
			$VERBOSE = 1;
		} elsif ($flag eq '-p') {
			$PRESERVE = 1;
		} elsif ($flag =~ /^-t/) {
			$TEST_MODE = 1;
		} elsif ($flag eq '-r') {
			$RECURSIVE = 1;
		} elsif ($flag eq '-fast') {
			$FAST_SCAN = 1;
		} elsif ($flag eq '-os') {
			return(&usage(1)) if (!@ARGV);
			$arg = shift(@ARGV);
			$arg =~ tr/a-z/A-Z/;
			if (!defined($TARGET_OS = $VALID_TARGETS{$arg})) {
				printf STDERR ("%s: bad -os, '%s', valid args are: {%s}\n",
					$p,$arg, join(',', sort keys %VALID_TARGETS));
				return(&usage(1));
			}
		} elsif ($flag =~ '^-h') {
			$HELPFLAG = 1;
			return(&usage(0));
		} else {
			return(&usage(1));
		}
    }

	if ($TARGET_OS == 0) {
		printf STDERR ("%s: -os parameter must be specified.\n", $p);
		return(&usage(1));
	}

    #take remaining args as file or dir names:
    if ($#ARGV >= 0) {
		@FILES = @ARGV;
    } else {
		if ($RECURSIVE) {
			@FILES = ".";
		} else {
			return(&usage(1));
		}
	}

	return(0);
}

sub cleanup
{
		unlink $TMPFILE if ($TMPFILE ne "");
}
1;
