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
# @(#)unix.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# unix.pl
# unix specific functions

#use strict;

require "oscmn.pl";

package os;		### This file adds to package os.

my ($TempFileCounter) = 0;

sub TempFile
	# Return the filename that will do as a temporary file.
	# Add it to the list of files to automatically delete.
	# NOTE:  files are deleted by prlskel ONLY WHEN PROCESS TERMINATES.
	#        BETTER TO CLEAN UP YOUR OWN FILES FOR A LONG PROCESS!
{
	my($filename);
	do {
		++$TempFileCounter;
		$filename = "/tmp/$main::p.$$.$TempFileCounter";
		# repeat until we find a file which doesn't exist already
		&warning("does $filename exist?") if ($os::DEBUG);
	} while (-e $filename);
	push(@'TempFileList, $filename);
	return $filename;
}

sub TempDir
	# Return a directory name that can be used for temporary purposes.
{
	my($dirname);
	do {
		++$TempFileCounter;
		$dirname = "/tmp/$main::p.$$.$TempFileCounter";
		&warning("does $dirname exist?") if ($os::DEBUG);
	} while (-e $dirname);
	push(@'TempDirList, $dirname);
	return $dirname;
}

sub mail
{
    my($to, $subject, $body) = @_;
	my($BSDmail) = 0;
	my($possibleMail, $cmd);
	
	if ($subject eq "") {
		$subject = "_";
	}
    my($mailExe) = "mail";
	if (defined($ENV{"FORTE_PORT"}) && $ENV{"FORTE_PORT"} eq "dguxi86") {
		# weird nonBSD port that has /usr/ucb/mail
	} else {
		foreach $possibleMail ("/bin/Mail", "/usr/ucb/Mail", "/usr/ucb/mail") {
			if (-x $possibleMail) {
				$mailExe = $possibleMail;
				$BSDmail = 1;
				last;
			}
		}
	}
	
	if ($BSDmail) {
		$cmd = "$mailExe -s \"$subject\" $to";
	} else {
		$cmd = "$mailExe $to";
	}
	print "BSDmail = $BSDmail cmd = '$cmd'\n" if ($os::DEBUG);
	if (!open(MAIL, "|$cmd")) {
		&error("couldn't send mail to $to (cmd = '$cmd'): $!\n");
		return 1;
	}
	if (! $BSDmail) {
		print MAIL "To: $to\n";
		print MAIL "Subject: $subject\n";
	}
    print MAIL "$body\n";
    close(MAIL);
	return 0;
}

sub eval_cmd
# mimic @foo = `cmd`;  this version saves stderr & status in caller args.
# returns list containing output, one list element for each line of output.
# return stderror output in <stderr_ref> list if defined.
# return system error message (errno text) in <uerrtxt> if defined.
{
	my ($cmdtxt, $userstatusref, $stderr_ref, $uerrtxt) = @_;
	my (@cmd_output) = ();
	my (@stdout) = ();
	my (@stderr) = ();
	my ($id) = "[unix.pl/eval_cmd]";

	my($wantstatus) = defined($userstatusref);
	my($wantstderr) = defined($stderr_ref);
	my($wanterrmsg) = defined($uerrtxt);

	my($tmp1) = &TempFile;		###NOTE:  these files get cleaned up automatically,
								###but only when the program exits.
	my($tmp2) = "/dev/null";
	
	if ($wantstderr) {
		$tmp2 = &TempFile;
	}

	chomp $cmdtxt;		#don't want newlines to mess up our redirects

	system("$cmdtxt >$tmp1 2>$tmp2");
	my($status) = ($? >> 8);		#lower eight bits hold the status.
	my($errmsg) = "";
	$errmsg = $! if ($status);

#printf "%s: status=%d $errmsg='%s' output=(%s)\n", $id, $status, $errmsg, join(',', `cat $tmp1`);

	#we always return stdout:
	if (open(INFILE, $tmp1)) {
		@stdout = <INFILE>;
		### REMOVE EOL chars.  this is different from @foo = `cmd`;
		grep(chomp, @stdout);		### short hand for:  @foo = grep(chomp($_), @foo);
		close  INFILE;
	} else {
		my($tmp) = sprintf("%s: cannot open output file, '%s', error='%s'", $id, $tmp1, $!);
		if ($errmsg ne "") {
			$errmsg = sprintf("{%s} {%s}", $errmsg, $tmp);
		} else {
			$errmsg = $tmp;
		}
	}
	unlink $tmp1;	#don't let temp files build up.

	#we return stderr only if the caller wants it:
	if ($wantstderr) {
		if (open(INFILE, $tmp2)) {
			@stderr = <INFILE>;
			close  INFILE;
		} else {
			my($tmp) = sprintf("%s: cannot open output file, '%s', error='%s'", $id, $tmp1, $!);
			if ($errmsg ne "") {
				$errmsg = sprintf("{%s} {%s}", $errmsg, $tmp);
			} else {
				$errmsg = $tmp;
			}
		}
		unlink $tmp2;
	}


	#### SAVE RESULTS:
	${$userstatusref} = $status if ($wantstatus);
	@{$stderr_ref}	= @stderr if ($wantstderr);
	${$uerrtxt}		= $errmsg if ($wanterrmsg);

	return(@stdout);
}

sub run_cmd
{
	my($cmd, $show_cmd) = @_;
	my ($show_return) = 1;

	$show_return = $_[2] if ($#_ > 1);

#printf "RUN_CMD:  show_cmd=%d show_return=%d #_=%d\n", $show_cmd, $show_return, $#_;

	print "$cmd\n" if $show_cmd;
	system $cmd;
	if ($?) {
		my($ret) = $?;
		my($anySignals) = $ret & 255;
		$ret >>= 8;
		if ($show_return) {
			print "$cmd\n" if (! $show_cmd);
			&error("return value is $ret ($anySignals)");
		}
		# make will return 130 if it was killed in the middle.
		if ($anySignals || $ret == 130) {
			if ($anySignals) {
				kill $anySignals, $$
			} else {
				kill 'INT', $$
			}
		}
		return 1;
	}
	return 0;
}

sub RunInParallel
# Run a shell command in parallel.
# It's suggested that you send the output into a separate log.
# eg: &RunInParallel("rsh -n leghorn runinpj foo commad > log 2>&1");
{
	my($cmd) = @_;
	my($pid);
	if ($pid = fork) {
		# parent here
	} elsif (defined($pid)) {
		# child here
		if (exec $cmd) {
			exit 1;
		}
		exit 1;
	} else {
		&error("can't fork: $!");
		return 1;
	}
	return 0;
}

sub get_latest_file
{
    my($dir) = @_;
    # print "Looking in $dir\n";
    my($file);
    # print "/bin/ls -1tr $dir | tail -1\n";
	if (! -d $dir) {
		if ($os::DEBUG) {
			print "debug: get_latest_file: directory doesn't exist\n";
			print "debug: $dir\n";
		}
		return ".";
	}
    chop($file = `/bin/ls -1tr $dir | tail -1`);
    # print "Got back $file\n";
    return $file;
}

sub compare
	# Compare 2 files to see if they are the same.
	# result 0  => same
	#        !0 => diff
{
	my($file1, $file2) = @_;
	my($ret);
	
	$ret = system("cmp '$file1' '$file2' > /dev/null 2>&1");
	return $ret;
}

sub get_latest_dir
{
    my($dir) = @_;
    my($latestDir);
    # print "looking in $dir\n";
	if (! -d $dir) {
		if ($os::DEBUG) {
			print "debug: get_latest_dir: directory doesn't exist\n";
			print "debug: $dir\n";
		}
		return ".";
	}
    my(@ls) = split(' ', `/bin/ls -ltr $dir | grep '^d' | tail -1`);
    $latestDir = $ls[$#ls];
    # print "found $latestDir\n";
    return $latestDir;
}

sub get_latest_time
    # figure the latest file in a particluar directory and return it's
    # time in an array of ($hour, $minute)
{
    my($dir) = @_;

    my($file);
    my($count) = 0;
    do {
        $file = &get_latest_file($dir);
        ++$count;
    } while (! -e "$dir/$file" && $count < 32);
    my($latestFileLs) = `/bin/ls -l $dir/$file`;
    my($d1,$d2,$d3,$d4,$d5,$d6,$d7,$d8,$atime,$mtime,$ctime) = stat("$dir/$file");
    # print "$file: $atime $mtime $ctime\n";
    # Trying to parse out the hour and minute from:
    # -rw-r--r--   1 cliffwd  forte          79 Mar 18 14:10 /tmp/foo.p
    my($hour, $minute) = $latestFileLs =~ /^[^:]*\s([0-9]+):([0-9]+)/;
    # print "$hour $minute $mtime\n";
    return ($hour, $minute, $mtime);
}

sub diff
	# This will diff the 2 files.  If the result is true, then there
	# was a diff; otherwise, no diff.
{
	my($file1, $file2) = @_;
	return &run_cmd("diff '$file1' '$file2'", 0);
}

sub rm_recursive
{
	my($dirname) = @_;

	return &run_cmd("/bin/rm -rf '$dirname'", 0);
}

sub IsProcessRunning
{
	my($pid) = @_;
	my($result);
	$result = `pstree $pid`;
	# ignore the first line, it just has on it the PS_CMD
	my(@lines);
	@lines = split('\n', $result);
	if ($#lines+1 > 1) {
		return 1;
	}
	return 0;
}

$main::OS == $main::UNIX;
