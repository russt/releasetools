#!/usr/bin/perl -w
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
# @(#)instldir.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# installdir - portable directory installation utility

package installdir;

#require "dumpvar.pl";
require "oscmn.pl";

$p = $'p;		#$main'p is the program name set by the skeleton

sub main
{
	local(*ARGV, *ENV) = @_;
	local ($nerrs) = 0;

	#set global flags:
	if (&parse_args != 0) {
		return (1) unless ($HELP_FLAG);
	}

#printf("argc=%d, argv=(%s)\n", $#ARGV, join(',', @ARGV));

	umask(0) if ($'OS == $'UNIX);
	for $dir (@DIRS) {
		if (&os'createdir($dir, $MODE) != 0) {
			printf STDERR ("%s:  can't create directory '%s', %s\n", $p, $dir, $!);
			++$nerrs;
		}
	}

	return $nerrs;
}

sub parse_args
#proccess command-line aguments
{
	$MODE = 0775;
	$HELP_FLAG = 0;
	local ($flag);

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flag = shift(@ARGV);

		if ($flag eq '-m') {
			return(&usage(1)) if (!@ARGV);
			$MODE = oct(shift(@ARGV));
		} elsif ($flag =~ '^-h') {
			$HELP_FLAG = 1;
			return &usage(1);
		} else {
			return &usage(1);
		}
    }

    #take remaining args as command names:
    if ($#ARGV >= 0) {
		@DIRS = @ARGV;
    } else {
		return &usage(1);
	}

	return 0;
}

sub usage
{
	local($status) = @_;

    print STDERR <<"!";
Usage:  $p [ -m mode ] [ dirs... ]

Options:
  -m mode  create directories with <mode>, which must be octal.

Example:
  installdir -m 0755 /tmp/foo1 /tmp/foo2
!
    return($status);
}

sub cleanup
{
}
1;
