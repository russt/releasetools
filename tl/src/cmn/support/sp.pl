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
# @(#)sp.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# base.pl
# a common base of Forte standard perl routines

package sp;

&init;
sub init
{
	$p = $'p;
	$OS = $::OS;
	$MACINTOSH = $::MACINTOSH;

	$DEBUG = 0;
	$VERBOSE = 0;

	$RM_FLAG = "";  # used for RunUsePath


	$TIMEZONE = "TZ_UNDEF";

	######
	# note:  TZ on solaris is set to point to a file in /usr/share/lib/zoneinfo.
	# e.g:  /usr/share/lib/zoneinfo/US/Pacific
	# date +%Z will return the old form, such as PST or PDT.
	######
	my($tmp) = `sh -c "date +%Z"`;
	$status = ($? >> 8);
	if ($status == 0){
		chomp $tmp;
		$TIMEZONE = $tmp;
	}

}

sub check_env
#check that a list of env. vars is available
{
	local(@evars) = @_;
	local($nerrs) = 0;

	for (@evars) {
		if (!$ENV{$_}) {
			++$nerrs;
			printf("%s:  ERROR, '%s' must be defined on command line or in envronment\n",
				$p, $_);
		}
	}

	return $nerrs;
}

sub tool_disabled
# Return true if this tool is disabled, otherwise false.
# Assumptions:
#   $PS is defined to be the path separator.
#   $TOOLROOT is defined in the environment.
#   $p holds the name of the tool.
{
	return if (&check_env('TOOLROOT') != 0);
    $TOOLROOT = $ENV{'TOOLROOT'};
    $HOST_NAME = $ENV{'HOST_NAME'} || `uname -n` if (!defined($HOST_NAME));

    $DISABLE_DIR = "$TOOLROOT${PS}lib${PS}denyTool${PS}$p";
    $DISABLE_FILE = "$DISABLE_DIR${PS}$HOST_NAME";
    $ALLOW_DIR = "$TOOLROOT${PS}lib${PS}alowTool${PS}$p";
    $ALLOW_FILE = "$ALLOW_DIR${PS}$HOST_NAME";

    if (0) {
        # debugging 
        print "TOOLROOT = $TOOLROOT\n";
        print "HOST_NAME = $HOST_NAME\n";
        print "toolName = $p\n";
        print "DISABLE_FILE = $DISABLE_FILE\n";
    }

    local($isDisabled) = 0;
    # check to see if we're disabled
    if (-e "$DISABLE_DIR${PS}+") {
        $isDisabled = 1;
        $DISABLE_FILE = "$DISABLE_DIR${PS}+";
    } elsif (-e "$DISABLE_FILE") {
        $isDisabled = 1;
    }
    # check to see if we're enabled
    if (-e "$ALLOW_DIR${PS}+") {
        $isDisabled = 0;
        $ALLOW_FILE = "$ALLOW_DIR${PS}+";
    } elsif (-e "$ALLOW_FILE") {
        $isDisabled = 0;
    }

    if ($isDisabled) {
        print "\nTOOL_ERROR: $p is disabled on $HOST_NAME.\n";
        print "\t$DISABLE_FILE:\n";
        system "cat $DISABLE_FILE";
    }
    return $isDisabled;
}

sub RunUsePath
{
	local($pathName, $package) = @_;
	local($ret);
	
	if ($pathName eq "main") {
		$pathName = "-m";
	}
	print "usePathDef $RM_FLAG $pathName >/tmp/csh.$$\n" if ($DEBUG);
	$ret = system "usePathDef $RM_FLAG $pathName >/tmp/csh.$$";
	if ($ret) {
		print STDERR "Call of 'usePathDef $RM_FLAG $pathName' failed.\n";
		return 1;
	}
	# system "cat /tmp/csh.$$";
	&EvalCshFile("/tmp/csh.$$", $package);
	unlink "/tmp/csh.$$";
	
	return 0;
}

sub EvalCshFile
	# Take a file and sources it (like we were csh), we need to know
	# which package to put the variables into.
{
    local($fileName, $package) = @_;
    local($line);
	local($errorCount) = 0;
	
    open(CSHSCRIPT, "$fileName") || warn "Unable to EvalCshFile $fileName: $!\n";
    while (defined($line = <CSHSCRIPT>)) {
		$errorCount += &EvalCshLine($line, $package);
    }
    close(CSHSCRIPT);
	return $errorCount;
}

sub EvalCshLine
	# Take a line (string) and evaluate it like we were csh.
	# setenv: changes the ENV and makes that variable visible to perl.
	# unsetenv: undef's the ENV and the perl variable
	# umask: change the current umask
	# rehash: do nothing
{
	local($line, $package) = @_;
	local(@fields, $cmd);
	$line =~ s/;$//;
	$line =~ s/\s+$//;
	@fields = split(' ', $line, 3);
	$cmd = $fields[0];
	if ($cmd eq "setenv") {
		# input format:   setenv VAR "VALUE";
		local($var) = $fields[1];
		local($value) = $fields[2];
		$value =~ s/^("|')//;
        $value =~ s/("|')$//;
		$ENV{$var} = $value;
		# print "\$$var = \"$value\"\n";
		eval "\$$package\'$var = \"$value\"";
		# print $line;
		# print "HOST_NAME = $HOST_NAME - $var\n";
	} elsif ($cmd eq "unsetenv") {
		# input format:   unsetenv VAR;
		# print "$fields[0] $fields[1]\n";
		local($var) = $fields[1];
		if (defined($ENV{$var})) {
			delete $ENV{$var};
			# print "undef \$$var\n";
			eval "undef \$$package\'$var";
		}
	} elsif ($cmd eq "umask") {
		local($value) = $fields[1];
		umask($value);
	} elsif ($cmd eq "rehash") {
		# do nothing as we don't need to rehash
	} else {
		print "unrecognised csh command: $cmd\n";
		return 1;
	}
	return 0;
}

sub GetDateStr
	# Return the current date as if you ran `date`
{
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdt) = localtime();
	$date = (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
	$date .= " ";
	$date .= (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];;
	$date .= " ";
	$year += 1900;
	$date .= sprintf("%2d %02d:%02d:%02d %s %4d",
					 $mday, $hour, $min, $sec, $TIMEZONE, $year );
}

sub GetDateStrFromUnixTime
{
	local($tme) = @_;
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdt) = localtime($tme);
	$date = (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
	$date .= " ";
	$date .= (Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];;
	$date .= " ";
	$year += 1900;
	$date .= sprintf("%2d %02d:%02d:%02d %s %4d",
					 $mday, $hour, $min, $sec, $TIMEZONE, $year );
	return $date;
}

sub CmpDateStr
# return 0 if d1 = d2, 1 if d1 > d2, -1 if d1 < d2
# -99 if error
{
	local($DATE1, $DATE2) = @_;
	local(@list1, @list2);
	local($year1, $month1, $day1, $hominsec1, $mymonth1, $myday1, $canonical1);
	local($year2, $month2, $day2, $hominsec2, $mymonth2, $myday2, $canonical2);
	local(%ConvertMonth);
	%ConvertMonth = ("Jan", "01",
					 "Feb", "02",
					 "Mar", "03",
					 "Apr", "04",
					 "May", "05",
					 "Jun", "06",
					 "Jul", "07",
					 "Aug", "08",
					 "Sep", "09",
					 "Oct", "10",
					 "Nov", "11",
					 "Dec", "12");

	@list1 = split(' ', $DATE1);
	@list2 = split(' ', $DATE2);

	$year1 = $list1[5];
	if (!defined($year1)) {
		print STDERR "year1 is not defined for date '$DATE1'\n";
		return -99;
	}
	$month1 = $list1[1];
	$day1 = $list1[2];
	$hominsec1 = $list1[3];
	$hominsec1 =~ s/://g;

	$mymonth1 = $ConvertMonth{$month1};
	$myday1 = &PadDay($day1);

	$year2 = $list2[5];
	if (!defined($year2)) {
		print STDERR "year2 is not defined for date '$DATE2'\n";
		return -99;
	}
	$month2 = $list2[1];
	$day2 = $list2[2];
	$hominsec2 = $list2[3];
	$hominsec2 =~ s/://g;

	$mymonth2 = $ConvertMonth{$month2};
	$myday2 = &PadDay($day2);

	$canonical1 = "$year1$mymonth1$myday1$hominsec1";
	$canonical2 = "$year2$mymonth2$myday2$hominsec2";

	if ($canonical1 eq $canonical2) {
        #  print $DATE1, "  =  ", $DATE2, "!\n";
		return 0;
	} elsif ($canonical1 gt $canonical2) {
        #  print $DATE1, "  >  ", $DATE2, "\n";
		return 1;
	} else {
        #  print $DATE1, "  <  ", $DATE2, "\n";
		return -1;
	}
}
sub PadDay
	# a supporting function to CmpDateStr
{
   local($day) = pop(@_);
   if (length($day) == 1) {
      $day = "0$day";
   }
   return $day;
}

sub UnixTimeAt
	# startTime will normally be the current time (in seconds)
	# endHour is the destination time in hours (24 hour modulus).
	# endMinute is the destination time in minutes (60 minute modulus).
	# Say you want an alarm to go off at 8am, then you take the
	# current unix time as startTime, endHour as 8, and endMinute as 0;
	# this function will return the unix time of 8am the next day.
{
	local($startTime, $endHour, $endMinute);
	$startTime = shift @_;
	$endHour = shift @_;
	$endMinute = shift @_;
	if (!defined($endMinute)) {
		$endMinute = 0;
	}
	local($endTime, $startSeconds, $startMinute, $startHour);
	($startSeconds, $startMinute, $startHour) = localtime($startTime);
	local($diffHour, $diffMinute, $diffSecond);
	$diffHour = $endHour - $startHour;
	$diffMinute = $endMinute - $startMinute;
	$diffSecond = $diffHour * 60 * 60 + $diffMinute * 60;
	if ($diffSecond < 0) {
		# add 24 hours, so that we're forward looking (won't produce a
		# time in the past).
		$diffSecond += 24 * 60 * 60;
	}
	$endTime = $startTime + $diffSecond;
	#printf("start time = %d end time = %s\n", $startTime,
	#	   &GetDateStrFromUnixTime($endTime));
	return $endTime;
}

sub uudecode
# Args: 1) uuencoded file 2) destination of extracted file
{
	# If this code gets more convoluted it might be best replaced
	# by the Perl uudecode.

	my($argSrcFile, $argDstFile) = @_;
	my($srcFile, $dstFile);
	# print("uudecode: argSrcFile=$argSrcFile argDstFile=$argDstFile\n");

	require "os.pl";
	require "path.pl";
	# Prevent two processes from uudecoding the same file in the same dir
	# by uudecoding in a private temp dir.  Remember to chdir back to
	# $masterDir and delete the temp dir before returning from this function.
	my($masterDir) = &path::pwd;
    my($tempDir) = &os::TempDir;
	if (&os::mkdir_p($tempDir, 0755)) {
		return 1;
	}
	&os::chdir($tempDir);
	# Since work is being done in a private temp dir relative paths need
	# to be made into absolute paths.
	if ($argSrcFile =~ m%^${::PS_IN}.*%) {
		#print("DEBUG:A\n");
		$srcFile = $argSrcFile;
	} else {
		#print("DEBUG:B\n");
		$srcFile = &path::mkpathname($masterDir, $argSrcFile);
	}
	if ($argDstFile =~ m%^${::PS_IN}.*%) {
		$dstFile = $argDstFile;
	} else {
		$dstFile = &path::mkpathname($masterDir, $argDstFile);
	}
	if ($DEBUG) {
		print(__FILE__,":",__LINE__,":Debug: ::PS_IN=$::PS_IN ::PS_OUT=$::PS_OUT argSrcFile=$argSrcFile srcFile=$srcFile argDstFile=$argDstFile  dstFile=$dstFile \n");
	}
	if (-e $dstFile) {
		&os::rename($dstFile, $dstFile . ".bak$$");
	}
	if (!open(UUFILE, $srcFile)) {
		&error("Failed to open $srcFile for read: $!");
		&os::chdir($masterDir);
		&os::rm_recursive($tempDir);
		return 1;
	}
	local($firstLine);
	$firstLine = <UUFILE>;
	close(UUFILE);
	chop($firstLine);
	# example firstLine: begin 664 file350.fsw
	local($begin, $mode, $uufilename);
	($begin, $mode, $uufilename) = split(/\s+/, $firstLine, 3);
	local($ret);
	# $ret = &os::run_cmd("uudecode -p $srcFile > $dstFile", 0);
	if ($uufilename eq $dstFile) {
		# we can simply run the normal uudecode
		$ret = &os::run_cmd("uudecode '$srcFile'", 0);
	} else {
		local($moveBack) = 0;
		if (-e $uufilename) {
			if (&os::rename($uufilename, "$uufilename.outofway$$")) {
				&os::chdir($masterDir);
				&os::rm_recursive($tempDir);
				return 1;
			}
			$moveBack = 1;
		}
		$ret = &os::run_cmd("uudecode '$srcFile'", 0);
		$ret += &os::rename($uufilename, $dstFile);
		if ($moveBack) {
			if (&os::rename("$uufilename.outofway$$", $uufilename)) {
				&os::chdir($masterDir);
				&os::rm_recursive($tempDir);
				return 1;
			}
		}
	}
	
	if (! $ret) {
		&os::rmFile($dstFile . ".bak$$");
	} else {
		print "uudecode failed.";
		if (-e $dstFile . ".bak$$") {
			print " Left backup as $dstFile.bak$$";
		}
		print "\n";
	}
	&os::chdir($masterDir);
	&os::rm_recursive($tempDir);
	return $ret;
}

sub uuencode
{
	local($srcFile, $dstFile, $uufilename) = @_;

	require "os.pl";
	local($cmd);
	$cmd = "uuencode '$srcFile' '$uufilename' > '$dstFile'";
	return &os::run_cmd($cmd);
}

sub RunCommandToFile
{
	local($cmd, $outputFile) = @_;
	local($errorCode);

	if (!open(OUT, ">$outputFile")) {
		warn "failed to open $outputFile for write: $!\n";
		return -1;
	}
	if (!open(CMD, "$cmd|")) {
		warn "'$cmd' failed to start running\n";
		return -1;
	}
	while (<CMD>) {
		print OUT;
	}
	close(CMD);
	close(OUT);
	$errorCode = $?;
	if ($errorCode) {
		warn "'$cmd' returned $errorCode\n";
	}
	return $errorCode;
}

sub GetStr
#display a prompt and input a string.
#on the mac, the prompt string will be in the input,
#and so must be filtered out.
#note that mpw does some strange things  - when the worksheet
#is edited prior to running this routine, sometimes
#you have to hit ENTER multiple times to get a read on <STDIN>
{
    local ($prompt) = @_;
    local($response);
	

#printf("\ngetting...\n");
	print $prompt;
    $response = <STDIN>;
    if ($OS == $MACINTOSH) {
#printf("\nresponse='%s'\n", $response);
		# Shouldn't execute a "die", but we don't have exceptions.
		die "Interrupt...\n" if (!defined($response));
		local(@tmp) = split("\n", $prompt);
		if ($#tmp >= 0) {
			local($eprompt) = $tmp[$#tmp];
			$eprompt =~ s/(\W)/\\$1/g;		#escape any meta-chars
			$response =~ s/^.*$eprompt//;
			chop $response;
		} else {
			$response = "";
		}
	} else {
		if (defined($response)) {
			chop $response;
		}
	}

#printf("\nresponse='%s'\n", $response);

    return $response;
}

sub GetStrDefault
{
	local($prompt, $default) = @_;
	local($response);

	$response = &GetStr($prompt);
	if (!defined($response) || $response eq "") {
		return $default;
	} else {
		return $response;
	}
}

sub AskYNDefN
{
	local($prompt) = @_;
	local($response);

	while (1) {
		$response = &GetStr($prompt);
		if (!defined($response)) {
			# EOF is opposite of default
			return "y";
		}

		if ($response eq "" || $response =~ /^n/i) {
			return "n";
		}
		if ($response !~ /^y/i) {
			print "\n$response is not a valid input: Just y or n.\n";
		} else {
			return "y";
		}
	}
}

sub AskYNDefY
{
	local($prompt) = @_;
	local($response);

	while (1) {
		$response = &GetStr($prompt);
		if (!defined($response)) {
			# EOF is opposite of default
			return "n";
		}

		if ($response eq "" || $response =~ /^y/i) {
			return "y";
		}
		if ($response !~ /^n/i) {
			print "\n$response is not a valid input: Just y or n.\n";
		} else {
			return "n";
		}
	}
}

sub IsInList
{
	local($search_element, @lst) = @_;
	local($element);
	foreach $element (@lst) {
		if ($search_element eq $element) {
			return 1;
		}
	}
	return 0;
}

sub uniq
{
	local(%seen);
	@seen{@_} = (1) x @_;
	return sort keys %seen;
}

sub File2List
{
	local($filename) = @_;

	local(@lst) = ();
	if (!open(FIN, $filename)) {
		print STDERR "BUILD_ERROR: Failed to open $filename for read: $!\n";
		return undef;
	}
	push(@lst, <FIN>);
	close(FIN);
	chop(@lst);
	return @lst;
}

sub List2File
{
	local($filename, @lst) = @_;

	if (!open(FOUT, ">$filename")) {
		print STDERR "BUILD_ERROR: Failed to open $filename for write: $!\n";
		return 1;
	}
	foreach $el (@lst) {
		print FOUT "$el\n";
	}
	close(FOUT);
	return 0;
}

sub AppendList2File
{
	local($filename, @lst) = @_;

	if (!open(FOUT, ">>$filename")) {
		print STDERR "BUILD_ERROR: Failed to open $filename for append: $!\n";
		return 1;
	}
	foreach $el (@lst) {
		print FOUT "$el\n";
	}
	close(FOUT);
	return 0;
}

sub RemoveFromFile
	# Remove all lines from a file that match a particular pattern.
	# If there are no more lines left, the file will be removed.
{
	local($file, $pattern) = @_;

	local($errCnt) = 0;
	local(@entries);
	local($entry, $lastmtime);
	if (! -e $file) {
		return 0;
	}
	$lastmtime = &os::modTime($file);
	@entries = &sp::File2List($file);
	if (!open(NEWRF, ">$file.$$")) {
		&error("Failed to open $file.$$ for write: $!");
		return 1;
	}
	foreach $entry (@entries) {
		#print "Scanning entry: $entry\n";
		if ($entry =~ /$pattern/) {
			#print "removing ours\n";
			next;
		}
		print NEWRF "$entry\n";
	}
	close(NEWRF);
	if ($lastmtime != &os::modTime($file)) {
		print "warning: someone made a change to $file while we were editing, retrying...\n" if ($DEBUG || $VERBOSE);
		return &RemoveFromFile($file, $pattern);
	}
	$errCnt += &os::rename($file, "$file.bak.$$");
	if (-z "$file.$$") {
		$errCnt += &os::rmFile("$file.$$");
		$errCnt += &os::rmFile("$file.bak.$$");
	} else {
		if (&os::rename("$file.$$", $file)) {
			&error("Failed to mv $file.$$ $file");
			++$errCnt;
			if ($lastmtime > 0) {
				$errCnt += &os::rename("$file.bak.$$", $file);
			}
		} else {
			$errCnt += &os::rmFile("$file.bak.$$");
		}
	}
	return $errCnt;
}

sub error
{
	local($msg) = @_;

	print "BUILD_ERROR: $p: $msg\n";
}

sub showPerlStackTrace
    # Print a Perl stack trace.
{
    my($i);

    print("Perl stack trace follows:\n");
    while (($pack, $file, $line, $subName,
	    $hasArgs, $wantArray) = caller($i++))
    {
	print("package=$pack file=$file line=$line\n");
	print("subName=$subName hasArgs=$hasArgs wantArray=$wantArray\n\n");
    }
}

sub Pause
	# Wait for the user to push a kit before continuing
{
	print "Execution paused.  Press <return> to continue.\n";
	<>;
}

1;
