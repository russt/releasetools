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
# @(#)os.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# os.pl
#

package os;

&os_init;
sub os_init
{
	$OS = $'OS;
	$UNIX = $'UNIX;
	$NT = $'NT;
	$MACINTOSH = $'MACINTOSH;
	if ($OS == $UNIX) {
		require "unix.pl";
	} elsif ($OS == $NT) {
		require "ntcmn.pl";
	} elsif ($OS == $MACINTOSH) {
		require "mac.pl";
	} else {
		print "ERROR: unidentified OS ($OS)\n";
	}
}

1;
