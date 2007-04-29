package tok;

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
# @(#)screen.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


require "lex.pl";

$SC = 0;

$DEBUG = 0;
$TRUE = 1;
$FALSE = 0;

$NULL	= 100;
$EOL	= 101;
$EOF	= 102;
$IDEN	= 103;
$INT	= 104;
$PUNC	= 105;
$STRING	= 106;

#### caller may set these:
$PUNC_SET = '[=,$\/{}\+\-\*&\(\)\[\]\|\^\!<>:]';
$ID_START	= '[\.A-Za-z_%]';
$ID_CONTINUE = '[\.A-Za-z0-9_%]';
$WHITESPACE = '[ \t]';

sub init
#got to prime the pump!
{
	$SC = &lx'scan;
}

sub lookahead
{
	&lx'save_scan_state;
	local($t, $v) = &get;
	&lx'restore_scan_state;
	return($t, $v);
}

sub get
{
	local ($tokval) = "";
	$SC = &lx'currSC;	#set global scan char

	#this is a loop because we ignore comments, and we may have
	#look-ahead conflicts that take a couple of rounds.
	#look-ahead conflicts:
	#	filenames can start with a number, have continuation set
	#   that is a super-set of id's, and can possibly have spaces in them!
	#
	for (;;) {
#print "get\n";
		if (&identifier(*tokval)) {
			printf STDOUT ("<%s:%s> ", "IDEN", $tokval) if ($DEBUG);
			return($IDEN, $tokval);
		} elsif (&integer(*tokval)) {
			printf STDOUT ("<%s:%s> ", "INT", $tokval) if ($DEBUG);
			return($INT, $tokval);
		} elsif (&punctuation(*tokval)) {
			printf STDOUT ("<%s:%s> ", "PUNC", $tokval) if ($DEBUG);
			return($PUNC, $tokval);
		} elsif (&atqstring(*tokval)) {
			printf STDOUT ("<%s:%s> ", "STRING", $tokval) if ($DEBUG);
			return($STRING, $tokval);
		} elsif (&dqstring(*tokval)) {
			printf STDOUT ("<%s:%s> ", "STRING", $tokval) if ($DEBUG);
			return($STRING, $tokval);
		} elsif (&endofline(*tokval)) {
			printf STDOUT ("<EOL> ") if ($DEBUG);
			return($EOL, $tokval);
		} elsif (&endoffile()) {
			printf STDOUT ("<EOF> ") if ($DEBUG);
			return($EOF, "");
		} elsif (&comment()) {
			printf STDOUT ("<COMMENT> ") if ($DEBUG);
			next;	#ignore
		} else {
			#unrecognized input:
			printf STDOUT ("<NULL>'%s'", $SC) if ($DEBUG);
			&lx'scan;
			return($NULL, "");
		}
	}
}

sub getchar
{
	local($c);
	$c = &lx'currSC;
	$SC = &lx'scan;
	return $c;
}

sub getword
	# get until we hit whitespace
{
	local($str) = "";
	local($c);

	while (1) {
		$c = &getchar;
		if ($c =~ $WHITESPACE || $c eq $lx'EOL || $c eq $lx'EOF) {
			last;
		}
		$str .= $c;
	}
	return $str;
}

sub getword_endchar
	# get until we hit whitespace, report which whitespace we hit
{
	local(*endChar) = @_;
	local($str) = "";
	local($c);

	while (1) {
		$c = &getchar;
		if ($c =~ $WHITESPACE || $c eq $lx'EOL || $c eq $lx'EOF) {
			$endChar = $c;
			last;
		}
		$str .= $c;
	}
	return $str;
}

sub getuntil
{
	local($untilChar, *endChar) = @_;
	local($str) = "";
	local($c);

	while (1) {
		$c = &getchar;
		if ($c eq $untilChar || $c eq $lx'EOL || $c eq $lx'EOF) {
			$endChar = $c;
			last;
		}
		$str .= $c;
	}
	return $str;
}

sub debugON
{
	$DEBUG = 1;
}

sub debugOFF
{
	$DEBUG = 0;
}

sub identifier
{
#print "identifier\n";
	local (*tokval) = @_;

	&wsp();
#print "ID CURRSC=$SC\n";

	return($FALSE) unless ($SC =~ /$ID_START/);

	$tokval = $SC;
	$SC = &lx'scan;
#print "ID NEXT=$SC\n";

	while ($SC =~ $ID_CONTINUE) {
		$tokval = $tokval . $SC;
		$SC = &lx'scan;
#print "ID LOOP=$SC\n";
	}

	return($TRUE);
}

sub integer
{
	local (*tokval) = @_;
#print "integer\n";

	&wsp();

	return($FALSE) unless ($SC =~ /[0-9]/);

	$tokval = $SC;
	$SC = &lx'scan;

	while ($SC =~ /[0-9]/) {
		$tokval = $tokval . $SC;
		$SC = &lx'scan;
	}

#print "integer true >>$SC<<\n";
	return($TRUE);
}

sub punctuation
{
#print "punc\n";
	local (*tokval) = @_;

	&wsp();

	return($FALSE) unless ($SC =~ $PUNC_SET);

	$tokval = $SC;
	$SC = &lx'scan;

	return($TRUE);
}

sub dqstring
{
#print "dqstring\n";
	local (*tokval) = @_;

	&wsp();

	return($FALSE) unless ($SC eq '"');

	$tokval = $SC;
	$SC = &lx'scan;

	while ($SC ne '"' && $SC ne $lx'EOL && $SC ne $lx'EOF) {
		#check for backslash escapes:
		if ($SC eq '\\') {
			$tokval .= $SC;
			$SC = &lx'scan;

			last if ($SC eq $lx'EOF);

			if ($SC eq $lx'EOL) {
				$tokval .= "n";
			} else {
				$tokval .= $SC;
			}
			$SC = &lx'scan;

		} else {
			$tokval .= $SC;
			$SC = &lx'scan;
		}
	}

	return($FALSE) unless ($SC eq '"');
	$tokval .= $SC;
	$SC = &lx'scan;

	return($TRUE);
}

sub atqstring
{
	local (*tokval) = @_;

	&wsp();

# ja	return($FALSE) unless ($SC eq '"');
	return($FALSE) unless ($SC eq '@');

	$tokval = $SC;
	$SC = &lx'scan;

# ja	while ($SC ne '"' && $SC ne $lx'EOL && $SC ne $lx'EOF) {
	while ($SC ne '@' && $SC ne $lx'EOL && $SC ne $lx'EOF) {
		#check for backslash escapes:
		if ($SC eq '\\') {
			$tokval .= $SC;
			$SC = &lx'scan;

			last if ($SC eq $lx'EOF);

			if ($SC eq $lx'EOL) {
				$tokval .= "n";
			} else {
				$tokval .= $SC;
			}
			$SC = &lx'scan;

		} else {
			$tokval .= $SC;
			$SC = &lx'scan;
		}
	}

# ja	return($FALSE) unless ($SC eq '"');
	return($FALSE) unless ($SC eq '@');
	$tokval .= $SC;
	$SC = &lx'scan;

	return($TRUE);
}

sub endofline
#eat up multiple EOL's
{
#print "endofline\n";
	local (*tokval) = @_;
	&wsp();

	return ($FALSE) unless ($SC eq $lx'EOL);
	$tokval = $SC;
	while ($SC eq $lx'EOL) {
		$SC = &lx'scan;
	}

	return($TRUE);
}

sub endoffile
{
#print "endoffile\n";
	&wsp();

	return ($SC eq $lx'EOF);
}

sub comment
#	comment -> '#' <any_but_EOL_or_EOF>* <EOL>|<EOF>
{
#print "comment\n";
	&wsp();


	return ($FALSE) unless ($SC eq "#");

	$SC = &lx'scan;
	while ($SC ne $lx'EOL && $SC ne $lx'EOF) {
		$SC = &lx'scan;
	}

	#scan past EOL's
	$SC = &lx'scan while ($SC eq $lx'EOL);

	return($TRUE);
}

sub wsp
#true if whitespace
{
#printf("wsp SC=>>%s<<\n", $SC);

	return($FALSE) unless ($SC =~ $WHITESPACE);

	while ($SC =~ $WHITESPACE) {
		$SC = &lx'scan;
	}

	return($TRUE);
}
1;
