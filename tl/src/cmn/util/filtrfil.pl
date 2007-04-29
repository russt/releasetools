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
# @(#)filtrfil.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# filterFiles.pl
# Parse a (simple) filter language which can specify file patterns to
# keep or prune.  Later, the client can ask whether a file should be kept
# or pruned.
#

package filterFiles;

require "os.pl";
require "sp.pl";
require "path.pl";

&init;

sub main
{
	local(*ARGV, *ENV) = @_;

	#set global flags:
	return (1) if (&parse_args(*ARGV, *ENV) != 0);
	return (0) if ($HELPFLAG);

	my($stat) = 0;
	my($file, $ret, $cwd, %MYTREE);

	require "walkdir.pl";
	#copies of file defs for walkdir db:
	$WDK_DNAME = $walkdir::WDK_DNAME;
	$WDK_FNAME = $walkdir::WDK_FNAME;
	$WDK_TYPE = $walkdir::WDK_TYPE;		#entry type:  {'F', 'D', 'L'} <==> (File, Dir, Link)

	local(@filter)= ();
	$errmsg = "NULL";
	if (!&filterFiles::nReadFilter(*filter, $FilterFile)) {
		printf STDERR "%s: ERROR: nReadFilter failed for file '%s'\n%s\n", $p, $FilterFile, $errmsg;
		return 1;
	}

	if ($SHOW_RULES) {
		&show_filter_rules(*filter);
	}

	print "Scanning $StartDir...\n";

	$cwd = &path::pwd();
	if ($cwd eq "NULL") {
		printf STDERR "%s:  ERROR:  path::pwd() could not get current directory", $p;
		return 1;
	}

	$ret = &walkdir::dirTree(*MYTREE, $cwd, $StartDir);
	if ($ret != 0) {
		printf STDERR "%s:  ERROR:  walkdir::dirTree FAILED with status %d", $p, $ret;
		return 1;
	}

	$rule_name = "NULL";
	for $fn (&walkdir::file_list(*MYTREE)) {
		if (&nKeepFile(*filter, $fn, *rule_name)) {
			if ($SHOW_KEEPS ) {
				$tmp = "SELECT";
				printf "%6s[%20s]: %s\n", $tmp,  $rule_name, $fn;
			}
		} else {
			if ($SHOW_PRUNES) {
				$tmp = "PRUNE";
				printf "%6s[%20s]: %s\n", $tmp,  $rule_name, $fn;
			}
			if ($RemoveNoKeeps) {
				&os::rmFile($fn);
			}
		}
	}
	return 0;
}

sub init
{
	$p = $::p;
	$OS = $::OS;
	$UNIX = $::UNIX;
	$NT = $::NT;
	$MACINTOSH = $::MACINTOSH;
	$DOT = $::DOT;
	
	$DEBUG = 0;
	$VERBOSE = 0;

	$StartDir = "";
	$FilterFile = "";
	$RemoveNoKeeps = 0;

	$PRUNE_DIR_OP = '70';
	$SELECT_DIR_OP = '71';
	$PRUNE_PATH_OP = '80';
	$SELECT_PATH_OP = '81';
	$PRUNE_FILE_OP = '90';
	$SELECT_FILE_OP = '91';
	$INCLUDE_OP = '100';

	%OP_NAME2NUM = (
		"PRUNE_DIR", $PRUNE_DIR_OP,
		"SELECT_DIR", $SELECT_DIR_OP,
		"PRUNE_PATH", $PRUNE_PATH_OP,
		"SELECT_PATH", $SELECT_PATH_OP,
		"PRUNE_FILE", $PRUNE_FILE_OP,
		"SELECT_FILE", $SELECT_FILE_OP,
		"INCLUDE", $INCLUDE_OP,
	);
	%OP_NUM2NAME = (
		$PRUNE_DIR_OP, "PRUNE_DIR",
		$SELECT_DIR_OP, "SELECT_DIR",
		$PRUNE_PATH_OP, "PRUNE_PATH",
		$SELECT_PATH_OP, "SELECT_PATH",
		$PRUNE_FILE_OP, "PRUNE_FILE",
		$SELECT_FILE_OP, "SELECT_FILE",
		$INCLUDE_OP, "INCLUDE",
	);
}

sub usage
{
	print <<"!"
Usage: $p [-debug] [-help] [-keeps|-nokeeps] [-rm] <StartDir> <FilterFile>

	-keeps   Print which files will be kept.
	-nokeeps Print which files will be pruned (default).
	-showall show prune & select actions
	-rm      Remove (delete) files marked for pruning.

	  eg: $p -keeps . \$SRCROOT/prune.dat
	  eg: $p \$SRCROOT \$SRCROOT/prune.dat
	  eg: $p -rm \$SRCROOT \$SRCROOT/prune.dat

	A filter file has two columns:  

	    PRUNE_DIR     regular_expression
		PRUNE_PATH    regular_expression
		PRUNE_FILE    regular_expression

	    SELECT_DIR    regular_expression
		SELECT_PATH   regular_expression
		SELECT_FILE   regular_expression

		INCLUDE       filename

	Note that PRUNE statements must appear before SELECT statements.

	Filter file examples:
	  Skip all <??>/doc directories, except tl/doc.
	    PRUNE_DIR    ^\w\w/doc/
	    SELECT_DIR   ^tl/doc/

	  Skip all .out, .err, .diff files created by regression tests.
	    PRUNE_FILE   \\.out\$|\\.err\$|\\.diff\$

	  Skip all files in tl/doc except abc.doc
	    PRUNE_DIR    ^tl/doc/
	    SELECT_FILE  abc.doc

	  Skip all .btz file in a directory except solsparc.btz
		PRUNE_PATH   ^tl\\/src\\/cmn\\/devdir\\/.+\\.btz
		SELECT_PATH  ^tl\\/src\\/cmn\\/devdir\\/solsparc\\.btz
!
}

sub parse_args
{
	local(*ARGV, *ENV) = @_;

	my($flag);

	#default displays:
	$SHOW_KEEPS = 1;
	$SHOW_PRUNES = 0;
	$SHOW_RULES = 0;
	$HELPFLAG = 0;
	
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flag = lc(shift(@ARGV));

		if ($flag =~ /^-h/) {
			$HELPFLAG = 1;
			return &usage(0);
		} elsif ($flag =~ /^-v/) {
			$VERBOSE = 1;
		} elsif ($flag =~ /^-d/) {
			$DEBUG = 1;
		} elsif ($flag eq "-keeps") {
			$SHOW_KEEPS = 1;
			$SHOW_PRUNES = 0;
		} elsif ($flag eq "-nokeeps") {
			$SHOW_KEEPS = 0;
			$SHOW_PRUNES = 1;
		} elsif ($flag eq "-showrules") {
			$SHOW_RULES = 1;
		} elsif ($flag eq "-showall") {
			$SHOW_KEEPS = 1;
			$SHOW_PRUNES = 1;
			$SHOW_RULES = 1;
		} elsif ($flag eq "-rm") {
			$RemoveNoKeeps = 1;
		} else {
			printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
			return &usage(1);
		}
	}

    #eliminate empty args (this happens on some platforms):
	@ARGV = grep(!/^$/, @ARGV);

	#take next arg as start directory:
    if ($#ARGV >= 0) {
		$StartDir = shift(@ARGV);
    } else {
		printf STDERR "%s:  must specify a starting directory.\n", $p;
		return &usage(1);
	}

	#take next arg as filter spec:
    if ($#ARGV >= 0) {
		$FilterFile = shift(@ARGV);
    } else {
		printf STDERR "%s:  must specify a filter specification.\n", $p;
		return &usage(1);
	}

	return 0;
}

############################################################################

sub ReadFilter
{
	my($file) = @_;

	if (!defined($file) || $file eq "") {
		print "BUILD_ERROR: $p [filterFiles::ReadFilter]: argument undefined or NULL\n";
		return undef;
	}

	if (! -r $file) {
		print "BUILD_ERROR: $p: [ReadFilter]: file '$file' is not readable.\n";
		return undef;
	}
	my(@lines);
	@lines = &sp::File2List($file);
	my($line, $op, $args);
	my($filter) = "";
	foreach $line (@lines) {
		if ($line =~ /^\s*$/ || $line =~ /^\s*#/) {
			next;
		}
		($op, $args) = split(/\s+/, $line, 2);
		if (!defined($op)) {
			print "Bad line: '$line'\n";
			next;
		}
		# do some static analysis of the file here
		if ($op eq "FILTER_FUNC") {
			$args = &ConvertFunc($args);
			if (!defined($args)) {
				# got some sort of an error
				next;
			}
		} elsif ($op eq "PRUNE_DIR") {
		} elsif ($op eq "PRUNE_FILE") {
		} elsif ($op eq "SELECT_DIR") {
		} elsif ($op eq "SELECT_FILE") {
		} elsif ($op eq "PRUNE_PATH") {
		} elsif ($op eq "SELECT_PATH") {
		} elsif (lc($op) eq "include") {
			require "vars.pl";
			my($fileToInclude) = $args;
			local($errCnt) = 0;
			$fileToInclude = &vars::expand_vars($fileToInclude, *ENV, *errCnt);
			if ($errCnt > 0) {
				print "Variable expansion failed on include of '$args', skipping.\n";
				next;
			}
			if (! -r $fileToInclude) {
				my($alternateFile) = &path::mkpathname(path::head($file),
													   $fileToInclude);
				if (! -r $alternateFile) {
					print "BUILD_ERROR: $p: [ReadFilter]: $fileToInclude is not readable (included from $file).\n";
					next;
				}
				$fileToInclude = $alternateFile;
			}
			my($incFilt) = &ReadFilter($fileToInclude);
			if (defined($incFilt) && $incFilt ne "") {
				if ($filter eq "") {
					$filter = $incFilt;
				} else {
					$filter .= $; . $incFilt;
				}
			}
			next;
		} else {
			print "Unknown operation from $file: op='$op'\n";
			next;
		}
		if ($filter eq "") {
			$filter = $op . " " . $args;
		} else {
			$filter .= $; . $op . " " . $args;
		}
	}
	return $filter;
}

sub nReadFilter
#new, improved version of ReadFilter.
#Usage:
#	my(@myfilterspec);
#	if (!&nReadFilter(*myfilterspec, "myfilterfile")) {
#		#FAILURE...
#	}
#   $keepit =  &nKeepFile(*myfilterspec, $local_filename, *rule_name);
#
# Parse a filter-spec text file, and build a list containing
# the specs.
#
# Example:
# INPUT:
#	PRUNE_DIR	tl/src/doc
#	PRUNE_FILE	*.doc
#	SELECT_PATH	tl/src/doc/foo.doc
#
# OUTPUT (on macintosh):
#	($PRUNE_DIR_OP, ":tl:src:doc:", 1, $PRUNE_FILE_OP, "*.doc", 2, $SELECT_PATH_OP, ":tl:src:doc:foo.doc", 3)
#
# OUTPUT (on unix):
#	($PRUNE_DIR_OP, "tl/src/doc/", $PRUNE_FILE_OP, "*.doc", 1, $SELECT_PATH_OP, 2, "tl/src/doc/foo.doc", 3)
#
# OUTPUT (on NT):
#	($PRUNE_DIR_OP, "tl[/\]src[/\]doc[/\]", $PRUNE_FILE_OP, 1, "*.doc", $SELECT_PATH_OP, 2, "tl[/\]src[/\]doc[/\]foo.doc", 3)
#
# RETURNS 1 if successful parse, 0 if errors.
{
	local(*filter_spec, $file) = @_;
	my(@lines);
	my($line, $op, $args);
	my($linecnt);
	my($nerrs, $numop);


	$errmsg = "";           #GLOBAL RESULT
	@filter_spec = ();      #RESULT

	$nerrs = 0;

	if (!defined($file) || $file eq "") {
		$errmsg = "argument undefined or NULL\n";
		return 0;
	}

	if (! -r $file) {
		$errmsg = "cannot open '$file'\n";
		return 0;
	}

	@lines = &sp::File2List($file);
	$linecnt = 0;
	foreach $line (@lines) {
		++$linecnt;
		if ($line =~ /^\s*$/ || $line =~ /^\s*#/) {
			###### IGNORE comment and blank lines
			next;
		}

		#REMOVE LEADING & TRAILING BLANKS:
		$line =~ s/^[ \t]+//;
		$line =~ s/[ \t]+$//;

		#look for 2 fields:
		($op, $args) = split(/\s+/, $line, 2);

		if (!defined($op) || !defined($args)) {
			$errmsg .= sprintf("ERROR:  expected %s on line #%d, file '%s', near '%s'.\n",
				!defined($op) ? "keyword" : "pattern",
				$linecnt, $file, $line);
			++$nerrs;
			next;
		}

		$op =~ tr/[a-z]/[A-Z]/;	#toupper

		if (!defined($numop = $OP_NAME2NUM{$op})) {
			$errmsg .= sprintf("ERROR:  unrecognized operation '%s' on line #%d, file '%s', near '%s'.\n",
				$op, $linecnt, $file, $line);
			++$nerrs;
			next;
		}

#printf STDERR "nReadFilter:  op='%s' args='%s'\n", $op, $args if ($DEBUG);

		if ($numop == $INCLUDE_OP) {
			##### RECURSIVE CALL!!
			my($fn) = $args;
printf STDERR "nReadFilter:  op='%s' fn='%s' REMINDER:  LOCALIZE filenames, do var subst.\n", $op, $args;
			local (@included) = ();
			if (!&filterFiles::nReadFilter(*included, $fn)) {
				$errmsg .= sprintf("INCLUDE failed for file '%s'\n", $fn);
				++$nerrs;
			} else {
#printf STDERR "nReadFilter:  added %d elements from include file '%s'\n", $#included, $fn;
				push (@filter_spec, @included);
			}
		} else {
			$args =  &localize_pattern_spec($numop, $args);
			push (@filter_spec, $numop, $args, $file . ":" . $linecnt);
		}
	}

	return ($nerrs == 0);
}

sub localize_pattern_spec
{
	local ($op, $inpat) = @_;
	my ($ret) = $inpat;

	#if dir op, then add a / at end:
	if ($op == $SELECT_DIR_OP || $op == $PRUNE_DIR_OP) {
		$ret =~ s/$/\// ;
	}

	#eliminate duplicate /'s:
	$ret =~ s/\/+/\//g;

	$ret =~ s/\//$PS_IN/g;

#printf STDERR "localize_pattern_spec:  in='%s' out='%s'\n", $inpat, $ret;

	return $ret;
}

sub nKeepFile
#new, improved version of KeepFile.
#Usage:
#	@myfilterspec = &nReadFilter("myfilterfile");
#   $keepit =  &nKeepFile(*myfilterspec, $local_filename);
#
#Note that nKeepFile expects a directory & filenames in local OS conventions.
#
#The result of nReadFilter is a flattened list of triples, each containing:
#	(filter_op_number, filter_spec, rule_info)
#
# filter_specs are written using "portable" pathname conventions,
# using unix-style pathnames.  nReadFilter converts these filenames to
# local conventions.  On Macintosh, this means '/' ==> ':'.  On NT,
# this means that '/' is converted to the pattern [\/].  There is
# no mechanism for incorporating '/' as part of the pattern, even
# though this is a legal filename on the mac.
#
# SEMANTICS OF FILTER OPERATIONS:
#
# ALL FILTERING operations are applied completely for each filename,
# in the order they are declared.  This means you can prune a directory,
# but then select individual files, sub-directories, or full pathnames later.
#
# In the beginning, the file or directory or full pathname is considered to be
# selected.
#
# the following operations are allowed:
#
#	PRUNE_DIR	- directories matching the specified pattern are pruned.
#				  function returns 0
#	SELECT_DIR	- directories matching the specified pattern are kept
#				  function returns 1
#	PRUNE_PATH	- full pathnames matching the specified pattern are pruned.
#				  function returns 0
#	SELECT_PATH	- full pathnames matching the specified pattern are kept
#				  function returns 1
#	PRUNE_FILE	- filenames matching the specified pattern are pruned
#				  function returns 1
#	SELECT_FILE	- filenames matching the specified pattern are kept
#				  function returns 1
{
	local (*filter, $ifn, *theRule) = @_;
		#NOTE:  $theRule is a RESULT parameter.
	my($dir, $fn, $ii, $op, $pat, $keepit, $ruleinf);

	######
	#apply each operation to input filename in order specified:
	######

	$keepit = 1;		#DEFAULT ACTION IS TO KEEP IT
	$theRule = "implied";		#corresponds to line number of pattern that matched

	#foreach triple in filter-spec...
	for ($ii=0; $ii<$#filter; $ii += 3) {
		#... retrieve filter spec ...
		($op, $pat, $ruleinf) = ($filter[$ii], $filter[$ii+1], $filter[$ii+2]);

		#
		#... and then evaluate it.
		# IMPORTANT:  <keepit> holds the "pending" action; which becomes final
		# unless a later rule over-rides it.
		#
		if ($op == $PRUNE_DIR_OP || $op == $SELECT_DIR_OP) {
			$dir = &path'head($ifn) . $DOT;		#keep trailing separator
			$match = ($dir =~ $pat);
			if ($op == $SELECT_DIR_OP && $match) {
				$keepit = 1;
				$theRule = $ruleinf;
			} elsif ($op == $PRUNE_DIR_OP && $match) {
				$keepit = 0;
				$theRule = $ruleinf;
			} ### else retain previous action #####

			printf "DIR OP=%d ifn='%s' dir='%s' pat='%s' match=%d keepit=%d\n", $op, $ifn, $dir, $pat, $match, $keepit if ($DEBUG);

		} elsif ($op == $PRUNE_FILE_OP || $op == $SELECT_FILE_OP) {
			$match = (&path'tail($ifn) =~ $pat);
			if ($op == $SELECT_FILE_OP && $match) {
				$keepit = 1;
				$theRule = $ruleinf;
			} elsif ($op == $PRUNE_FILE_OP && $match) {
				$keepit = 0;
				$theRule = $ruleinf;
			} ### else retain previous action #####

			printf "FILE OP=%d ifn='%s' fn='%s' pat='%s' match=%d keepit=%d\n", $op, $ifn, &path'tail($ifn), $pat, $match, $keepit if ($DEBUG);

		} elsif ($op == $PRUNE_PATH_OP || $op == $SELECT_PATH_OP) {
			$match = $ifn =~ $pat;
			if ($op == $SELECT_PATH_OP && $match) {
				$keepit = 1;
				$theRule = $ruleinf;
			} elsif ($op == $PRUNE_PATH_OP && $match) {
				$keepit = 0;
				$theRule = $ruleinf;
			} ### else retain previous action #####

			printf "PATH OP=%d ifn='%s' pat='%s' match=%d keepit=%d\n", $op, $ifn, $pat, $match, $keepit if ($DEBUG);

		} else {
			##### note - nReadFilter has already checked for bad opts, so this case
			##### should never execute.
			printf STDERR "nKeepFile:  PROGRAMMER ERROR:  undefined op, %d\n", $op;
			next;
		}
	}

	return $keepit;
}

sub show_filter_rules
#display the filter rules
#WORKS FOR NEW version only!!
#
{
	local(*filter_spec) = @_;
	my ($op, $pat, $rule_info, $lfn, $fn, $cnt, $ii);

	$lfn = "NULL";
	$cnt = -1;

	#foreach triple in filter-spec...
	for ($ii=0; $ii<$#filter; $ii += 3) {
		#... retrieve filter spec ...
		($op, $pat, $rule_info) = ($filter[$ii], $filter[$ii+1], $filter[$ii+2]);

		($fn, $cnt) = split(':', $rule_info);

		#... and display it:
		printf "\n####### %s ######\n", $fn if ($lfn ne $fn);
		printf "%3d %s\t%s\n", $cnt, $OP_NUM2NAME{$op}, $pat;

		$lfn = $fn;
	}
}


sub KeepFile
	# $file should be in portable format (ie, unix slashes)
	# directories should have an ending slash
{
	my($filter, $file) = @_;
	my($pruneIt) = 0;

	local($dir, $filename);
	($dir, $filename) = ($file =~ /^(.*\/)(.*)$/);
	if (!defined($dir)) {
		# no slashes
		$dir = "./";
		$filename = $file;
	}
	print "KeepFile: dir = '$dir' filename = '$filename'\n" if ($DEBUG);
	my($cmd, $op, $args);
	foreach $cmd (split($;, $filter)) {
		($op, $args) = split(" ", $cmd, 2);
		print "KeepFile: do $op with $args\n" if ($DEBUG);
		if ($op eq "FILTER_FUNC") {
			my($ret);
			$ret = eval $args;
			if ($@ ne "") {
				print "ERROR: $p (filterFiles.pl): $@\n";
			} elsif (!defined($ret)) {
			} elsif ($ret == 0) {
				return 0;
			}
		} elsif ($op eq "PRUNE_DIR") {
			if ($dir =~ /$args/) {
				# The filter wants to prune it, so don't keep it.
				$pruneIt = 1;
			}
		} elsif ($op eq "PRUNE_PATH") {
			if ($file =~ /$args/) {
				$pruneIt = 1;
			}
		} elsif ($op eq "PRUNE_FILE") {
			if ($filename =~ /$args/) {
				# The filter wants to prune it, so don't keep it.
				$pruneIt = 1;
			}
		} elsif ($op eq "SELECT_DIR") {
			if ($dir =~ /$args/) {
				# The filter wants to keep it, so do.
				$pruneIt = 0;
			}
		} elsif ($op eq "SELECT_PATH") {
			if ($file =~ /$args/) {
				$pruneIt = 0;
			}
		} elsif ($op eq "SELECT_FILE") {
			if ($filename =~ /$args/) {
				# The filter wants to keep it, so do.
				$pruneIt = 0;
			}
		} else {
			print STDERR "PROGRAMMER ERROR:  Unknown operation from $file: op='$op'\n";
			next;
		}
	}

	if ($pruneIt) {
		print "KeepFile: pruning it\n" if ($DEBUG);
		return 0;
	} else {
		print "KeepFile: keeping it\n" if ($DEBUG);
		return 1;
	}
}

sub ConvertFunc
	# Take the symbolic name for a function in a filter file and
	# convert it to an actual perl function that will be evalled.
	# All valid functions will be listed here.
{
	my($args) = @_;
	
	if (lc($args) eq "&legalforos") {
		if ($OS == $UNIX) {
			$args = "&LegalForUnix";
		} elsif ($OS == $NT) {
			$args = "&LegalForNT";
		} elsif ($OS == $MACINTOSH) {
			$args = "&LegalForMac";
		} else {
			print "filterFiles.pl: unknown OS (OS = $OS)\n";
			return undef;
		}
	} elsif (lc($args) eq "legalforunix" || lc($args) eq "legalfornt" ||
			 lc($args) eq "legalformac") {
		$args = "&" . $args;
	} else {
		print "filterFiles.pl: unknown function '$args'\n";
		return undef;
	}
	return $args;
}

sub LegalForUnix
{
	return 1;
}

sub LegalForNT
{
	return 1;
}

sub LegalForMac
{
	# the mac has a filename length limit of 31 chars
	if (length($filename) > 31) {
		return 0;
	}
	return 1;
}

1;
