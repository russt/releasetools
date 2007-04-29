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
# @(#)shsyntax.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# sh syntax checker
#
# First run ksh's own syntax checker, then check for some cases that it misses.
#

package shsyntax;

$DEBUG = 0;

&'require_os;
require "path.pl";

sub main
{
	(*ARGV, *ENV) = @_;
	local ($status) = 0;
	local($errorCount) = 0;
	
	&init;
	$status = &parse_args;
	if ($status != 0) {
		return (0) if ($status == 2);	#not an error to ask for help.
		return $status;
	}

	local($file);
	foreach $file (@ARGV) {
		$errorCount += &Check($file);
	}

	return $errorCount;
}

sub init
{
	$p = $'p;
}

sub cleanup
{
}

sub parse_args
{
	$arg = $ARGV[0];
	while (defined($arg) && $arg =~ /^-/) {
		if ($arg eq "-h" || $arg eq "-help") {
			&usage;
			return 2;
		} elsif ($arg eq "-d" || $arg eq "-debug") {
			$DEBUG = 1;
		} else {
			print STDERR "Unknown argument '$arg'\n";
			&usage;
			return 1;
		}
		shift @ARGV;
		$arg = $ARGV[0];
	}
	return 0;
}

sub usage
{
	print <<"!";
Usage: $p [-help] [-debug]  list of files
   eg: $p foo.sh

    $p will check the syntax of ksh programs.
!
}

#############################################################################

sub Check
{
	local($file) = @_;

	$KSH = &path'which("bash");
	if ($KSH eq "") {
		$KSH = &path'which("ksh");
		if ($KSH eq "") {
			print "Warning: bash or ksh not found in PATH cannot check syntax.\n";
		}
	} else {
		local($fullFileName) = $file;
		if (! &path'isfullpathname($fullFileName)) {
			$fullFileName = &path'mkpathname(&path'pwd, $file);
		}
		#
		# We seem to need the leading "cd ; " as ksh will seg fault if
		# started from cron if we don't have it there.
		#
		chop($output = `cd ; $KSH -n $fullFileName 2>&1`);
		if ($output ne "") {
			print STDERR "ERROR: ksh syntax check of $file failed:\n'$output'\n\n";
			return 1;
		}
	}
	
	local(@origLines, @lines);
	local($lineNum, $line);

	if (!open(SHFILE, $file)) {
		print STDERR "ERROR: unable to open $file for read: $!\n";
		return 1;
	}
	push(@origLines, <SHFILE>);
	close(SHFILE);

	# noPush is set when logical lines are continued across multiple
	# physical lines.
	local($noPush) =0;
	local($unfinishedQuote) = 0;
	$fullLine = "";
	for ($lineNum = 0; $lineNum <= $#origLines; ++$lineNum) {
		$line = $origLines[$lineNum];
		chop($line);
		$line =~ s/^\s+//;   # Remove whitespace at the end
		$line =~ s/\s+$//;   # Remove whitespace at the beginning
		$line =~ s/\\.//g;   # Remove '\.' (backslash anything)
		$line =~ s/'[^']*'//g;     # Remove single-quoted strings (needs to
		                           # happend before double quotes)
		$line =~ s/\"[^\"]*\"//g;  # Remove strings

		# Get rid of comments, but need to leave $#.  So we expand all
		# '#'s to '##', follow that by taking '$##' back down to '$#'
		# as it used to be, then we can kill everything following a
		# '##', because we know its now a '$##'.
		$line =~ s/^#.*//;
		$line =~ s/#/##/g;
		$line =~ s/\$##/\$#/g;
		$line =~ s/##.*//;
		
		if ($line =~ /'/ || $line =~ /\"/) {
			$unfinishedQuote ^= 1;
		}

		# If it has a backslash at the end or there's a quote which isn't done
		if ($line =~ /\\$/ || $unfinishedQuote) {
			$noPush = 1;
			$line =~ s/\\$//;
		}
		print "   $line (noPush=$noPush)\n" if ($DEBUG);

		$fullLine .= $line;
		if ($noPush) {
			$noPush = 0;
		} else {
			if ($fullLine ne "") {
				push(@lines, $fullLine);
				$fullLine = "";
			}
		}
	}
	if ($fullLine ne "") {
		print STDERR "ERROR: incomplete last line (possibly unterminated quote or unexpected EOF) in $file\n";
		return 1;
	}

	print "Passed lexical scan.\n" if ($DEBUG);
	local($isError) = 0;
	local($errorMsg);
	for ($lineNum = 0; $lineNum <= $#lines; ++$lineNum) {
		$line = $lines[$lineNum];
		print "   $line\n" if $DEBUG;
		if ($requireThen) {
			$requireThen = 0;
			if ($line !~ /then/) {
				$errorMsg = "based on the previous line, this line requires a 'then'";
				$isError = 1;
			}
		}
		if ($line =~ /^if\s/) {
			print "if statement\n" if $DEBUG;
			if ($line !~ /^if\s+\[\s+.*\s+\]/ &&
				$line !~ /^if\s+\[\[\s+.*\s+\]\]/ &&
				$line !~ /^if\s+.*\;\s*then/) {
				$errorMsg = "Misbalanced if expression";
				$isError = 1;
			}
			if ($line !~ /;.*then/ && $line !~ /\]\]\s+then/) {
				$requireThen = 1;
			}
		} elsif ($line =~ /^elif\s/) {
			print "elif statement\n" if $DEBUG;
			if ($line !~ /^elif\s+\[\s+.*\s+\]/ &&
				$line !~ /^elif\s+\[\[\s+.*\s+\]\]/) {
				$errorMsg = "Misbalanced elif expression";
				$isError = 1;
			}
			if ($line !~ /;.*then/ && $line !~ /\]\]\s+then/) {
				$requireThen = 1;
			}
		} elsif ($line =~ /^echo\s/) {
			# accept all echo's as okay
			print "echo\n" if $DEBUG;
		} elsif ($line =~ /^[a-zA-Z0-9_]+[ \t]*=/) {
			print "assignment\n" if $DEBUG;
			if ($line =~ /\s=/) {
				$errorMsg = "unacceptable white space in assignment";
				$isError = 1;
			}
		} elsif ($line =~ /^while/) {
			print "while statement\n" if $DEBUG;
		} elsif ($line =~ />&[^0-9]/) {
			$errorMsg = "csh redirection syntax (>&)";
			$isError = 1;
		}
		if ($isError) {
			printf STDERR ("ERROR: on line '%s' of $file:\n %s\n", $line, $errorMsg);
			return 1;
		}
	}
	
	return 0;
}
