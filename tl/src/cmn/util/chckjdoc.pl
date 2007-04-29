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
# @(#)chckjdoc.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# checkjdoc.pl
# check java files for basic syntax requirements
#

package checkjdoc;

require "os.pl";
require "sp.pl";

sub main
{
	local(*ARGV, *ENV) = @_;
	my($errCnt) = 0;
	my($ret);
	
	&init;
	$ret = &ParseArgs;
	if ($ret == 2) {
		return 0;
	} elsif ($ret) {
		return $ret;
	}

	foreach $file (@fileList) {
		$errCnt += &CheckFile($file);
	}
	return $errCnt;
}

&init;
sub init
{
	$DEBUG = 0;
	$QUIET = 0;

	@fileList = ();
}

sub Usage
{
	print <<"!"
Usage: $p file1.java ...

Do a basic syntax check of java files sufficient for javadoc.
	
	eg: $p foo.java
!
}

sub ParseArgs
{
	my($arg, $lcarg);
	while (defined($arg = shift @ARGV)) {
		$lcarg = lc($arg);
		if ($lcarg eq "-help") {
			&Usage;
			return 2;
		} elsif ($lcarg eq "-debug") {
			$DEBUG = 1;
		} elsif ($lcarg eq "-q") {
			$QUIET = 1;
		} elsif ($lcarg eq "-noq") {
			$QUIET = 0;
		} else {
			push(@fileList, $arg);
		}
	}		
	if ($#fileList+1 <= 0) {
		return &error("Must specify at least one java file.  Try -help.");
	}
	return 0;
}

sub CheckFile
	# Currently we check the following things:
	#   balanced jdoc comments:
	#       /**
	#        * blah blah
	#        */ 
{
	my($file) = @_;
	my($errCnt) = 0;

	if (! -r $file) {
		return &error("'$file' is not readable.");
	}
	my(@progLines, @commentStack);
	@progLines = &sp::File2List($file);
	
	# The comment stack will hold the line numbers of where the beginning
	# of the comment is found.
	@commentStack = ();
	my($lineNumber, $progLineCount, $line, $commentCount, $javaDocComment);
	$commentCount = 0;
	$progLineCount = $#progLines+1;
	for ($lineNumber = 0; $lineNumber < $progLineCount; ++$lineNumber) {
		$line = $progLines[$lineNumber];
		# remove C++ style comments (double slashes)
		$line =~ s#//.*##;
		if ($line =~ /\/\*/) {
			if ($line =~ /\/\*\*/) {
				$javaDocComment = 1;
			} else {
				$javaDocComment = 0;
			}
			++$commentCount;
			push(@commentStack, $lineNumber);
		}
		if ($line =~ /\*\//) {
			if ($#commentStack+1 <= 0) {
				++$errCnt;
				&error("Unbalanced comment found in $file ending at line " . ($lineNumber+1));
			} else {
				pop(@commentStack);
			}
		}
	}
	foreach $lineNumber (@commentStack) {
		++$errCnt;
		&error("Unbalanced comment found in $file beginning at line " . ($lineNumber+1));
	}
	if ($errCnt == 0) {
		print "$file okay ($commentCount relevant comment(s) found)\n" if (!$QUIET);
	}
	return $errCnt;
}

sub error
{
	my($msg) = @_;
	print "BUILD_ERROR: $p: $msg\n";
	return 1;
}
	
1;
