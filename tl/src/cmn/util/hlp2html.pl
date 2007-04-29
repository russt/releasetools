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
# @(#)hlp2html.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# Creates command help html files for our tools
#
package help2html;

sub main 
{
	local(*ARGV, *ENV) = @_;
	local($st);

	&Init;
	if ($st = &ParseArgs) {
		return $st;
	}

	if ($GENINDEX) {
		return &CreateIndexFiles($htmlDir);
	} else {
		return &CreateCmdHelpFiles;
	}
}

sub CreateCmdHelpFiles
{
	# Get list of commands via make.
	if (scalar(@CMDS) == 0) {
		&GetCmdList;
	}

	if (scalar(@CMDS) == 0) {
		return 0;
	}

	&Help2HTML($htmlDir);
}

sub GetCmdList
{
	local($MAKECMD) = "make -s";
	local($common) = "";
	local($target);
	local(@targets) = "$FORTE_PORT";
	local(@tmp);

	if (&IsUnix($FORTE_PORT)) {
		$COMMON = "cmn";
	} elsif (&IsNT($FORTE_PORT)) {
		$COMMON = "ntcmn";
	} elsif (&IsVMS($FORTE_PORT)) {
		$COMMON = "vms";
	}

	if ($COMMON ne "") {
		push(@targets, $COMMON);
	}

	foreach $target (@targets) {
		open(FILE, "$MAKECMD showcommands TARGET_OS=$target|");
		chop(@tmp = <FILE>);
		push(@CMDS, @tmp);
		close(FILE);
	}
}

sub Help2HTML
{
	local($htmlDir) = @_;
	local($toolType, $helpArg, $cmd, $cmdFile, $helpMsg, $dir);
	local($tmpFile) = "/tmp/${p}.$$";

	if (! -d $htmlDir) {
		system("mkdir -p $htmlDir");
	}

	foreach $cmd (sort @CMDS) {
		$helpArg = "";
		if (defined($CMDHELP{$cmd})) {
			$helpArg = $CMDHELP{$cmd};
		}

		$toolType = "";
		if (defined($CMDTYPE{$cmd})) {
			$toolType = $CMDTYPE{$cmd};
		}

		if ($helpArg eq "" || $toolType eq "") {
			&Warning("Skipping '$cmd'.");
			next;
		} else {
			$dir = "$htmlDir/$toolType";
			$cmdFile = "$htmlDir/$toolType/$cmd.html";
			if (! -d $dir) {
				system("mkdir -p $dir");
			}
		}

		$helpMsg = "";
		unlink $cmdFile, $tmpFile;
		print "Creating $cmdFile...\n";
		# Should check result but some commands returns non-zero even
		# if they are sucessful.
		system("$cmd $helpArg >> $tmpFile 2>&1");
		&ReadFileToStr(*helpMsg, $tmpFile);
		unlink $tmpFile;
		$helpMsg =~ s/>/&gt;/g;
		$helpMsg =~ s/</&lt;/g;
		open(CMDHTML, ">$cmdFile");
		print CMDHTML "<HTML>\n<PRE>\n";
		print CMDHTML "%$cmd $helpArg\n\n";
		print CMDHTML "$helpMsg\n";
		print CMDHTML "</PRE>\n</HTML>\n";
		close(CMDHTML);
	}
}

sub Init
{
	$p = $::p;

	$TOOLROOT = $ENV{'TOOLROOT'} || die "TOOLROOT not defined in env";
	$DISTROOT = $ENV{'DISTROOT'} || die "DISTROOT not defined in env";
	$htmlDir  = "$DISTROOT/src/cmdhelp";
	$FORTE_PORT = $ENV{'FORTE_PORT'};
	@CMDS = ();
	%CMDHELP = ();
	%CMDTYPE = ();
	%TOOLTYPE = ();
	$GENINDEX = 0;
	$htmlSuffix = ".html";

	$tooldeptHomePage = "http://engwww.forte.com/~tooldept/index.html";
	&LoadCmdHelpTable("$TOOLROOT/lib/cmn/cmdhelp.txt");
}

sub IsUnix
{
	local($ports) = `bldhost -port -unix -colon`;
	local(@UNIX) = split(/:/, $ports);
	local($match);

	$match = scalar(grep(/^$FORTE_PORT$/i, @UNIX));
	return $match;
}

sub IsNT
{
	if ($FORTE_PORT =~ /^nt$/i || $FORTE_PORT =~ /^axpnt$/i) {
		return 1;
	} else {
		return 0;
	}
}

sub IsVMS
{
	if ($FORTE_PORT =~ /alpha/i) {
		return 1;
	} else {
		return 0;
	}
}

sub ParseArgs
{
	local($arg);

	while ($arg = shift @ARGV) {
		if ($arg =~ /-help|-h/) {
			&Usage;
			return 1;
		} elsif ($arg eq "-c") {
			if (scalar(@CMDS = @ARGV) == 0) {
				&Error("Bad argument");
				&Usage;
			}
			return 0;
		} elsif ($arg eq "-genindex") {
			$GENINDEX = 1;
		} else {
			&Error("Bad argument");
			&Usage;
		}
	}
}

sub CreateIndexFiles
{
	local($htmlDir) = @_;

	if (! -d $htmlDir) {
		&Error("$htmlDir does not exist");
		return 1;
	}

	&CreateTopLevelIndex($htmlDir);
	&CreateToolIndex($htmlDir);
	system("updateDistDir -veryq $htmlDir");
}

sub CreateTopLevelIndex
{
	local($htmlDir) = @_;
	local($indexHtml) = "index.html";
	local($topLevelIndexFile) = "$htmlDir/$indexHtml";

	if (-f $topLevelIndexFile) {
		unlink $topLevelIndexFile;
	}
	if (! open(TOPLEVELINDEXFILE, ">$topLevelIndexFile")) {
		die "Can't open $topLevelIndexFile";
	}

	print TOPLEVELINDEXFILE "<HTML>\n<PRE>\n";
	print TOPLEVELINDEXFILE "Please click on one of links below to see help messages:\n<BR>\n";
	map {print TOPLEVELINDEXFILE "<H4><A HREF=$_/$indexHtml>$_ tools</A></H4>\n"} keys %TOOLTYPE;
	print TOPLEVELINDEXFILE "<H4>To return to tooldept home page, click <A HREF=$tooldeptHomePage>return-to-tooldept-homepage</A></H4>\n";
	print TOPLEVELINDEXFILE "</PRE>\n</HTML>\n";
}

sub CreateToolIndex
{
	local($htmlDir) = @_;
	local($indexHtml) = "index.html";
	local($i, $toolType, $dir, $file, $cmd, @lsout);
	local(@fileArray) = ();
	local($cmdPerLine) = 5;

	foreach $toolType (keys %TOOLTYPE) {
		$dir = "$htmlDir/$toolType";
		if (! -d $dir) {
			&Error("$dir does not exist");
			next;
		}
		$indexFile = "$dir/$indexHtml";
		if (-f $indexFile) {
			unlink $indexFile;
		}
		opendir(DIR, "$dir");
		@lsout = grep(/^.+\.html$/,readdir(DIR));
		closedir(DIR);
		if (! open(FILE, ">$indexFile")) {
			&Error("Can't open $indexFile");
			next;
		}
		print FILE "<HTML>\n<PRE>\n";
		print FILE "<A NAME=\"Top\"></A>\n";
		print FILE "Please click on one of the commands below to see its help message:\n<BR>\n";

		$i = 0;
		foreach $cmd (sort @lsout) {
			$i = $i + 1;
			$cmd =~ s/\.html$//;
			print FILE "<A HREF=\"#$cmd\">$cmd</A> ";
			if ($i >= $cmdPerLine) {
				$i = 0;
				print FILE "<BR>\n";
			}
		}
		print FILE "<BR>\n\n";

		foreach $cmd (sort @lsout) {
			$file = "$htmlDir/$toolType/${cmd}${htmlSuffix}";
			if (! open(FILE2, "$file")) {
				&Error("Can't open $file\n");
				next;
			}
			print FILE "<a NAME=$cmd></a>\n";
			map {if (! /(<\/*HTML>)|(<\/*PRE>)/) {print FILE $_}} <FILE2>;
			print FILE "<font face=\"Arial\" size=\"-5\"><a href=\"#Top\">Back to Top</a></font>\n";
			close(FILE2);
		}

		print FILE "\n<H4>To return to tooldept home page, click <A HREF=$tooldeptHomePage>return-to-tooldept-homepage</A></H4>\n";
		print FILE "\n</PRE>\n</HTML>";
		close(FILE);
	}
}

sub LoadCmdHelpTable
{
	local($cmdHelpTable) = @_;
	local($cmd, $helpArg, $toolType);

	if (open(HELPFILE, "$cmdHelpTable")) {
		while (defined($_ = <HELPFILE>)) {
			chop($_);
			if ($_ =~ /^#|^(\s*$)/) {
				next;
			}
			($cmd,$helpArg,$toolType) = split(/\s+/,$_,3);
			if (defined($cmd) && defined($helpArg) && defined($toolType)) {
				$CMDHELP{$cmd} = "$helpArg";
				$CMDTYPE{$cmd} = "$toolType";
				$TOOLTYPE{$toolType} = 1;
			}
		}
		close(HELPFILE);
	} else {
		die "BUILD_ERROR. $p: Can't open $cmdhelp"; 
	}
}

sub ReadFileToStr
{
	local (*buf, $infile) = @_;
	local ($BUFFERSIZE) = 16384;

	if (!open(INFILE, $infile)) {
		&Error("open failed on '$infile'\n");
		return(1);
	}

	$buf = "";
	local ($nbytes, $totalbytes, $mybuf) = (0,0,"");

	while ($nbytes = read(INFILE, $mybuf, $BUFFERSIZE)) {
		$buf .= $mybuf;
		$totalbytes += $nbytes;
	}

	close INFILE;

	if (!defined($nbytes)) {
		#read returns undef on error
		&Error("error reading input file $infile\n");
		return(3);
	}

	return(0);
}

sub Usage
{
	print <<"!";
Usage: $p [-help|-h] [-genindex] [-c cmds]
     -help     : Display this help message.
     -c cmds   : Commands to build html help files for.
                 cmds are separated by space. If -c is not
                 specified, install.map is used to get the 
                 list of commands for the current directory.
     -genindex : Generate index files.

 NOTE: html help files and index files are created in
       DISTROOT/src/cmdhelp.

!
	return 0;
}

sub Error
{
	local($msg) = @_;

	print "BUILD_ERROR: $p: $msg\n";
}

sub Warning
{
	local($msg) = @_;

	print "BUILD_WARNING: $p: $msg\n";
}

1;
