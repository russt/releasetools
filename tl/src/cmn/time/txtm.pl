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
# @(#)txtm.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# txtm - routines to manipulate and display time in "transaction time"
#		format.
#

package txtm;

use Time::Local;	#use timegm routine.

&init;

sub to_systime
#returns system GMT time (i.e., unix time)
{
	my($txtm) = @_;

	return undef if (!&is_txtm($txtm));

	my ($year, $mon, $dd, $hh, $min, $ss) = &split_txtm($txtm);

	return timegm($ss,$min,$hh,$dd,$mon,$year);
}

sub to_gmtxtm
#
#convert unix time to transaction date/time format
#Usage:
#	$theTime = time;
# 	$yyyymmddhhmmss = &txtm::to_txtm($theTime);
#
{
	my($gtime) = @_;

	my(@trec) = gmtime($gtime);

	return sprintf("%04d%02d%02d%02d%02d%02d",
		$trec[$TM_YEAR] + 1900,
		$trec[$TM_MONTH] +1,
		$trec[$TM_MDAY],
		$trec[$TM_HOUR],
		$trec[$TM_MINUTE],
		$trec[$TM_SECOND]);
}

sub subtract
#return number of seconds between x1 & x2 (x1 - x2).
{
	my($x1, $x2) = @_;
	my($u1, $u2) = (&to_systime($x1), &to_systime($x2));

	if (!defined($u1) || !defined($u2)) {
		return (undef);
	}

	return ($u1 - $u2);
}

sub short_time
#yyyymmddhhmmss -> mmdd.hh:mm:ss
{
	my($txtm) = @_;

	return undef if (!&is_txtm($txtm));

	my ($year, $mon, $dd, $hh, $min, $ss) = &split_txtm($txtm);

	return sprintf("%s.%s:%s:%s", $mon, $dd, $hh, $min, $ss); 
}

sub split_txtm
#this is a "private" routine.  we assume &is_txtm($txtm).
{
	my ($txtm) = @_;

	#0 2 4 6 8 
	#yyyymmddhhmmss

	#note that we subtract 1 from the month to put it back to
	#the 0-11 value returned by localtime, gmtime.
	return(
		substr($txtm, 0, 4), substr($txtm, 4, 2) - 1,
		substr($txtm, 6, 2), substr($txtm, 8, 2),
		substr($txtm, 10, 2), substr($txtm, 12, 2)
	);

}

sub is_txtm
#true if arg is a valid txtm
{
	my ($txtm) = @_;

	#must be defined:
	return 0 if (!defined($txtm));

	#must be correct length:
	return 0 if (length($txtm) != $TXTM_LENGTH);

	#must be all digits:
	return 0 if ($txtm !~ /\d+/);

	return 1;
}

sub init
{
	#localtime record fields:
	$TM_SECOND	= 0;
	$TM_MINUTE	= 1;
	$TM_HOUR	= 2;
	$TM_MDAY	= 3;
	$TM_MONTH	= 4;
	$TM_YEAR	= 5;
	$TM_WDAY	= 6;
	$TM_YDAY	= 7;
	$TM_ISDST	= 8;

	$TXTM_LENGTH = length("yyyymmddhhmmss");
}

1;
