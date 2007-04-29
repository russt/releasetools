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
# @(#)numutil.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
#numutil.pl - some useful numerical routines.
#
# 16-Aug-96
#	russt - created.
#
package num;

sub ceiling
# 1.0 -> 1, 1.0001 -> 2
# -1.0 -> -1, -1.0001 -> -1
{
	local ($num) = @_;
	if ($num > 0) {
		return ($num > int($num)) ? int($num) + 1 : $num;
	} else {
		return ($num < int($num)) ? int($num): $num;
	}
}

sub floor
# 1.0 -> 1, 1.0001 -> 1
# -1.0 -> -1, -1.0001 -> -2
{
	local ($num) = @_;
	if ($num > 0) {
		return ($num > int($num)+1) ? int($num) + 1 : $num;
	} else {
		return ($num < int($num)) ? int($num): $num;
	}
}

1;
