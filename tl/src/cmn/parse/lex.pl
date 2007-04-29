package lx;

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
# @(#)lex.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

$EOF = "";
$EOL = "\n";
$SC = "";		#global copy of current scan character

$MAX_FILE_LEN = 128*1024;		#biggest input file we can handle

sub currSC
{
#print "currSC=$SC<\n";
	return($SC);
}

sub save_scan_state
#save the current scan position
{
	$save_SC		= $SC;
    $save_LINENUM	= $LINENUM;
    $save_LCHARNUM	= $LCHARNUM;
    $save_CHARNUM	= $CHARNUM;
	$save_EOFSET	= $EOFSET;
}

sub restore_scan_state
#restore the scan position to the saved state
{
	$SC		= $save_SC;
	$LINENUM	= $save_LINENUM;
	$LCHARNUM	= $save_LCHARNUM;
	$CHARNUM	= $save_CHARNUM;
	$EOFSET		= $save_EOFSET;
}

sub setscanbuf
#save a copy of a scan buffer
#returns 1 on success
{
#print "setscanbuf\n";
    local ($fn) = @_;
    local ($buf) = "";

	$FILENAME = $fn eq "-" ? "STDIN" : $fn;

	if (!open(INFILE, $fn)) {
		printf STDERR ("setscanbuf:  open failed on '%s'\n", $fn);
		return(0);
	}

	$buf="";
	$FILE_LENGTH = read(INFILE, $buf, $MAX_FILE_LEN);
	close(INFILE);

	if ($FILE_LENGTH >= $MAX_FILE_LEN) {
		printf STDERR ("setscanbuf:  file '%s' exceeds max size (%d)\n",
			$fn, $MAX_FILE_LEN);
		return(0);
	}

	#split file into one big global array:
    # @SCANBUF = split(//, $buf);
	@SCANBUF = unpack("a" x length($buf) , $buf);

#&main'dumpvar('lx', 'SCANBUF');
    $LINENUM = 1;
    $LCHARNUM = 1;
    $CHARNUM = 0;
	$EOFSET = 0;

	return(1);		#success
}

sub scan
#get the next char from the global scan buffer, and keep track
#of line numbers.
{
	if ($CHARNUM > $FILE_LENGTH-1) {
		$EOFSET = 1;
		$SC = $EOF;
#print STDERR "SCAN EOF A\n";
		return($EOF);
	}

	local ($cc) = $SCANBUF[$CHARNUM];
	++$CHARNUM;
	++$LCHARNUM;

	$SC = $cc;
	return($cc) unless (&eolchar($cc));


	#otherwise, we have an EOL sequence.
	$LCHARNUM = 1;
    ++$LINENUM;
	if ($CHARNUM > $FILE_LENGTH-1) {
		#no more chars
		$EOFSET = 1;
		$SC = $EOL;
#print STDERR "SCAN EOF B\n";
		return ($SC);
	}

	#otherwise, have at least one more char.
	local ($nc) = $SCANBUF[$CHARNUM];
	if ($cc eq "\r" && $nc eq "\n") {
		#DOS EOL convention - skip LF
		++$CHARNUM;
	}

	$SC = $EOL;
	return($EOL);

#printf STDERR ("scan: cc='%s' LINENUM=%d LCHARNUM=%d CHARNUM=%d\n", $cc, $LINENUM, $LCHARNUM, $CHARNUM);
#printf STDERR ("return cc='%s'\n", $cc);
}

sub showerror
#show an error at the current scan position in the file
{
	local ($msg) = @_;
	local ($lf) = $CHARNUM;
	local($lastchar) = $CHARNUM;
	if ($EOFSET) {
		$lf = $FILE_LENGTH-1 
	}

	#scan to the last non-lf char:
	while (&eolchar($SCANBUF[$lf])) {
		--$lf;
	}
	if ($EOFSET) {
		$lastchar = $lf+1;
	}

	#now scan to the beginning of the current line:
	while ($lf > 0 && !&eolchar($SCANBUF[$lf])) {
		--$lf;
	}

	++$lf if (&eolchar($SCANBUF[$lf]));

	#now collect the last line in a local buffer:
	local ($theline) = "";
	for ($ii = $lf; $ii < $lastchar; ++$ii) {
		$theline = $theline . $SCANBUF[$ii];
	}

	local ($therest) = "";
	for ($ii = $lastchar;
			$ii < $FILE_LENGTH && !&eolchar($SCANBUF[$ii]);
			$ii++)
	{
		$therest = $therest . $SCANBUF[$ii];
	}

	if ($EOFSET) {
		#reset line position to length of last line:
		$colpos = length($theline) + length($therest) + 1;
#printf STDERR ("$theline='%s'\ntherest='%s'\n", $theline, $therest);
		$posmsg = "EOF";
	} else {
		$colpos = $LCHARNUM;
		$posmsg = sprintf("line %d, column %d", $LINENUM, $colpos);
	}

    printf STDERR ("Syntax error in file %s at %s:\n", $FILENAME, $posmsg);
	if ($msg eq "") {
		printf STDERR ("%s %s\n%s^\n", $theline, $therest, " " x ($colpos-1));
	} else {
		printf STDERR ("%s %s\n%s^%s\n", $theline, $therest, " " x ($colpos-1), $msg);
	}
}

sub eolchar
#true if an EOL char
{
	local ($cc) = @_;
	return ($cc eq "\r" || $cc eq "\n");
}
1;
