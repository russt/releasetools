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
# @(#)bomscan.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


# bomscan.pl
#
# a scanner for the BOM files

package bomscan;

$CommentStr = "#";
$SkipWS = 1;    # "WS" => White Space
$KeepEOL = 1;
$Identifier = "[a-zA-Z_0-9]+";

$DEBUG = 0;

sub Open
{
	local($file) = @_;

	$theFile = $file;
	@Lines = ();
	$LineNum = 0;
	$TokenNum = 0;
	$TokensInCurLine = 0;
	@SaveState = ();
	$EOF = 0;

	local(@preLines) = ();
	if (!open(FIN, $file)) {
		return 1;
	}
	push(@preLines, <FIN>);
	close(FIN);

	# Go thru every line and do some preprocessing
	local($line, $lineNum);
	$lineNum = 0;
	foreach $line (@preLines) {
		++$lineNum;
		# Get rid of comments;
		$line =~ s/$CommentStr.*//;
		if ($SkipWS) {
			# Remove EOLs
			$line =~ s/\n//g;
			$line =~ s///g;
			# Translate WS into just spaces (should preserve it in strings)
			$line =~ s/\s+/ /g;
			next if ($line eq " ");
		}
		next if ($line eq "");
		# print "line = '$line'\n";
		push(@Lines, $line);
		push(@LineNums, $lineNum);
	}
	$FinalLineNum = $#Lines+1;
	&NextLine;

	return 0;
}

sub PushState
{
	push(@SaveState, join($;, ($TokenNum, $LineNum)));
}

sub PopState
{
	local($prevLineNum) = $LineNum;
	($TokenNum, $LineNum) = split($;, pop(@SaveState));
	if ($prevLineNum != $LineNum) {
		&ChunkCurLine($LineNum);
	}
}

sub State
{
	return ($TokenNum, $LineNum);
}

sub ChunkCurLine
{
	local($lineNum) = @_;

	return if ($EOF);
# 	if ($lineNum > $FinalLineNum) {
# 		print "bomscan:: Exceeded final line with $lineNum\n" if ($DEBUG);
# 	}
	local(@preLine);
	# print "bomscan:: lineNum = $lineNum FinalLineNum = $FinalLineNum\n";
	@preLine = ($Lines[$lineNum-1] =~ /($Identifier)?(.)?/g);
	@CurLine = ();
	@CurLineCharNum = ();
	local($t);
	local($charNum) = 0;
	foreach $t (@preLine) {
		next if (!defined($t));
		print "bomscan:: curLine token = '$t'\n" if ($DEBUG);
		push(@CurLine, $t);
		push(@CurLineCharNum, $charNum);
		$charNum += length($t);
	}
	if ($KeepEOL) {
		push(@CurLine, "\n");
		push(@CurLineCharNum, $charNum);
		++$charNum;
	}
	$TokensInCurLine = $#CurLine+1;
}

sub TokenWS
	# Return tokens including WS
{
	local($token);
	if ($TokenNum >= $TokensInCurLine) {
		# goto the next line
		&NextLine;
		if ($EOF) {
			return "";
		}
	}
	$token = $CurLine[$TokenNum];
	++$TokenNum;
	return $token;
}

sub Token
{
	local($token);
	if ($SkipWS) {
		do {
			$token = &TokenWS;
		} while ($token eq " ");

		# skip extra white space in the beginning
		if ($TokenNum < $TokensInCurLine) {
			if ($CurLine[$TokenNum] eq " ") {
				++$TokenNum;
			}
		}
	} else {
		return &TokenWS;
	}
	return $token;
}

sub GetUpToWS
	# If the next token is WS, then we return the empty string.
{
	local($realEndChar);

	return &GetUpTo(" ", *realEndChar);
}

sub GetUpTo
	# If the next token is an EOL, then keep it, so that &Token will return it.
{
	local($endChar, *realEndChar) = @_;
	local($str) = "";
	local($token) = "";

	while (! $EOF) {
		$token = &TokenWS;
		if ($token eq $endChar) {
			last;
		}
		if ($token eq "\n") {
			&BackUpToken;
			last;
		}
		$str .= $token;
	}
	$realEndChar = $token;
	return $str;
}

sub LookAhead
{
	local($token);
	&PushState;
	$token = &Token;
	&PopState;
	return $token;
}

sub LookAheadWS
{
	local($token);
	&PushState;
	$token = &TokenWS;
	&PopState;
	return $token;
}

sub BackUpToken
{
	--$TokenNum;
	if ($TokenNum <= 0) {
		$TokenNum = 0;
		--$LineNum;
		if ($LineNum <= $FinalLineNum) {
			$EOF = 0;
		}
		&ChunkCurLine($LineNum);
	}
}

sub NextLine
{
	++$LineNum;
	$TokenNum = 0;
	if ($LineNum > $FinalLineNum) {
		$EOF = 1;
		print "bomscan:: Hit EOF\n" if ($DEBUG);
	} else {
		&ChunkCurLine($LineNum);
	}
}

sub RestOfLine
{
	local($str);
	if ($EOF) {
		return "";
	}
	$str = substr(&CurLine, &CurCharNum);
	if ($SkipWS) {
		$str =~ s/^ //;
	}
	&NextLine;
	return $str;
}

sub CurLine
{
	if ($LineNum > $FinalLineNum) {
		return "";
	}
	return $Lines[$LineNum-1];
}

sub CurLocStr
{
	return sprintf("%s^", " " x &CurCharNum);
}

sub CurLineNum
{
	if ($LineNum > $FinalLineNum) {
		return ($LineNums[$FinalLineNum-1]+1);
	}
	return $LineNums[$LineNum-1];
}

sub CurCharNum
{
	if ($LineNum > $FinalLineNum) {
		return 0;
	}
	return $CurLineCharNum[$TokenNum];
}

1;
