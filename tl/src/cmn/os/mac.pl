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
# @(#)mac.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# mac.pl
# mac specific functions

package os;

require "oscmn.pl";

&mac_init;
sub mac_init
{
	printf STDERR ("%s:  can't load MacPerl FileCopy routine\n", $p)
		if (&load_filecopy != 0);
}

sub TempFile {
	local($filename);
	$filename = "tmp.mac";
	return $filename;
}

sub load_filecopy
#since this is a bootstrap program, generate FileCopy module
#so we can include it.  Specific to MacPerl.
#Note that we can't just eval it, since the LoadExternals() routine
#must also have access to the external file.
#returns 0 on success.
{
	return if ($'OS != $'MACINTOSH);

	local ($tmp) = $ENV{'TempFolder'};	#this is always defined by MPW.
	return(1) if (!defined($tmp));

	$tmp = $tmp . "FileCopy.pl";
#print "tmp=$tmp\n";

	if (!open(OUTFILE, ">$tmp")) {
		printf STDERR ("%s:  can't open tempfile '%s', error='%s'\n", $'p, $tmp, $!);
		return(1);
	}

	print OUTFILE <<'END_SCRIPT';
package FileCopy;

&MacPerl'LoadExternals("FileCopy.pl");

package MacPerl;

#
# &MacPerl'FileCopy($from, $to [, $replace [, $dontresolve]])
# 

sub FileCopy {
   local($from, $to, $replace, $dontresolve) = @_;

   if ($replace) {
	  $replace = "true";
   } else {
	  $replace = "false";
   }

   if ($dontresolve) {
	  &FileCopy'FileCopy($from, $to, $replace, "DontResolveAlias", 
		 "DontShowProgress");
   } else {
	  &FileCopy'FileCopy($from, $to, $replace, "DontShowProgress");
   }
}

1;
END_SCRIPT

	close OUTFILE;

	unshift(@INC, $tmp);
	require "FileCopy.pl";
	shift(@INC);	#get rid of tmp dir.
	unlink($tmp);

	return(0);
}

$OS == $MACINTOSH;
