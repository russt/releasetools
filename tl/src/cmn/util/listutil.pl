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
# @(#)listutil.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
#listutil.pl - some useful routines for manipulating lists.
#
# 16-Aug-96
#	russt - created.
# 05-Sep-95
#	russt - added set utils
#

package list;

require "numutil.pl";

&init;

############################## UTILITIES - SETS ################################

sub KEYED_OR
#see usage under KEYED_OP
{
	return &KEYED_OP($LIST_OR, @_);
}
sub KEYED_AND
#see usage under KEYED_OP
{
	return &KEYED_OP($LIST_AND, @_);
}

sub KEYED_MINUS
#see usage under KEYED_OP
{
	return &KEYED_OP($LIST_MINUS, @_);
}

sub OR
#returns UNION of 2 lists.
#usage:  local (@a, @b); ... ; @union = &OR(*a, *b);
{
	local (*A, *B) = @_;
	local (%mark);

	for (@A, @B) { $mark{$_}++;}

	return(sort keys(%mark));
}

sub AND
#returns INTERSECTION of 2 lists.
#usage:  local (@a, @b); ... ; @intersection = &AND(*a, *b);
{
	local (*A, *B) = @_;
	local (%mark);

	#store smaller of the two lists:
	if ($#A <= $#B) {
		for (@A) { $mark{$_}++;}
		return(grep($mark{$_}, @B));
	} else {
		for (@B) { $mark{$_}++;}
		return(grep($mark{$_}, @A));
	}
}

sub stable_AND
	# return the intersection of @masterList and @doList while
	# preserving the order in @masterList
{
	local(*masterList, *doList) = @_;
	local($element);
	local(%mark);
	local(@result);
	@result = ();
	
	foreach $element (@doList) {
		$mark{$element}++;
	}
	foreach $element (@masterList) {
		if ($mark{$element}) {
			push(@result, $element);
		}
	}
	return @result;
}

sub MINUS
#returns A - B
#usage:  local (@a, @b); ... ; @difference = &MINUS(*a, *b);
{
	local (*A, *B) = @_;
	local (%mark);

	for (@B) { $mark{$_}++;}
	return(grep(!$mark{$_}, @A));
}

sub UNIQUE
{
	local (%mark);
	for (@_) { $mark{$_}++;}
	return(keys %mark)
}

sub KEYED_OP
#performs OR, AND, or MINUS OP on 2 lists, using specified key in multi-field elements. 
#
#	usage:  local (@a, @b);
#	$FS = ',';
#	$a[1] = join($FS, $x, $y, $z);
#	$ZKEY=2;
#	$SAFE_FS=",";	 #a safe field-separator I can use to join mult. keys in a string.
#	...
#	@union			= &KEYED_OR(*a, *b, $FS, $ZKEY [, $SAFE_FS]);
#	@intersection	= &KEYED_AND(*a, *b, $FS, $ZKEY [, $SAFE_FS]);
#	@difference		= &KEYED_AND(*a, *b, $FS, $ZKEY [, $SAFE_FS]);
#
# NOTES:
#	this operation first maps the original keys of @a & @b by the selector key.
#	It then operates on the result, and returns the original keylist.
#
{
	local ($OP, *A, *B, $fs, $kn, $SAFE_FS) = @_;
	local (%XA, %XB, @KXA, @KXB, @tmp, $xx, @result);


	if (!defined($SAFE_FS)) {
		if ($fs eq $;) {
			$SAFE_FS = ",";
		} else {
			$SAFE_FS = $;;
		}
	}

#printf STDERR "KEYED_OP: OP=%d #A=%d #B=%d fs='%s' kn='%d' SAFE_FS='%s'\n", $OP, $#A, $#B, $fs, $kn, $SAFE_FS;

	&map_keys(*XA, *A, $fs, $kn, $SAFE_FS);
	@KXA = keys %XA;

	&map_keys(*XB, *B, $fs, $kn, $SAFE_FS);
	@KXB = keys %XB;

	if ($OP == $LIST_OR) {
		@tmp = OR(*KXA, *KXB);
	} elsif ($OP == $LIST_AND) {
		@tmp = AND(*KXA, *KXB);
	} elsif ($OP == $LIST_MINUS) {
		@tmp = MINUS(*KXA, *KXB);
	} else {
		printf STDERR "%s:  ERROR - OP '%d' not defined\n", $p, $OP;
		return undef;
	}

	foreach $xx (@tmp) {
		push(@result, split($SAFE_FS, $XA{$xx})) if (defined($XA{$xx}));
		push(@result, split($SAFE_FS, $XB{$xx})) if (defined($XB{$xx}));
	}

	return (&UNIQUE(@result));
}

########################## UTILITIES - TRANSPOSE ##############################

sub rows2columns
#reorder a list from row order to column order
{
	local (*listin, $rowdim) = @_;
	local (@out) = ();

	return () unless ($#listin >= 0 && $rowdim > 1);

	#recall that $# is the last index, not the cardinality:
	local ($nrows) = &num'ceiling(($#listin+1)/$rowdim);

#printf "nrows=%d #listin=%d rowdim=%d\n", $nrows, $#listin, $rowdim;

	local($hh, $ii, $jj, $kk) = (0,0,0,0);
	local($tmp) = "";

	#for each row...
	for ($hh=0; $hh< $nrows; $hh++) {

		#for each column...
		for ($ii=0; $ii< $rowdim; $ii++) {
			#if element defined...
			if (defined($listin[$kk])) {
				$tmp = $listin[$kk];
			} else {
				$tmp = "";
			}

			push (@out, $tmp);

#printf "(%d,%d) = [%d]\n", $hh, $ii, $kk;

			$kk += $nrows;
		}

		++$jj;
		$kk = $jj;
	}

	return(@out);
}

############################ INTERNAL ROUTINES ################################

sub map_keys
#map list <L> of multi-field keys into new hash <X>.
#the keys of X are the unique set of <kn>th fields of <L>.
#the values of X are the full elements of <L>.
{
	local (*X, *L, $fs, $kn, $SAFE_FS) = @_;
	local ($kk, $nkk, @rec);

	foreach $kk (@L) {
		@rec = split($fs, $kk);
		$nkk = $X{$rec[$kn]};
		if (defined($nkk)) {
			$X{$rec[$kn]} = join($SAFE_FS, $nkk, $kk);
		} else {
			$X{$rec[$kn]} = $kk;
		}
	}
}

sub init
{
	$p = "list.pl";
	$LIST_OR = 101;
	$LIST_AND = 102;
	$LIST_MINUS = 103;
}
1;
