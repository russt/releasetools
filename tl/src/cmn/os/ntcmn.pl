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
# @(#)ntcmn.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# nt.pl
# nt specific functions

package os;

require "oscmn.pl";

sub TempFile
	# Return the filename that will do as a temporary file.
	# Add it to the list of files to automatically delete.
{
	local($filename);
	### NOTE:  TMPDIR is the official mks location for NT,
	###        and will have forward slashes if it is defined.  RT 11/9/99
	$TEMPDIR = $ENV{'TMPDIR'} || $ENV{'TMP'} || "c:/tmp";
	if (! -d $TEMPDIR) {
		$TEMPDIR = ".";
	}
	do {
		++$TempFileCounter;
		$filename = "$TEMPDIR/${p}_$$.$TempFileCounter";
		# repeat until we find a file which doesn't exist already
		&warning("does $filename exist?") if ($DEBUG);
	} while (-e $filename);
	push(@'TempFileList, $filename);
	return $filename;
}

sub compare
        # Compare 2 files to see if they are the same.
        # result 0  => same
        #        !0 => diff
{
        local($file1, $file2) = @_;
        local($ret);

        $ret = &run_cmd("cmp $file1 $file2", 0);
        return $ret;
}

sub eval_cmd
{
	my ($cmdtxt, $userstatusref, $stderr_ref, $uerrtxt) = @_;
	my (@cmd_output) = ();
	my (@stderr) = ();
	chomp $cmdtxt;




	if (defined $stderr_ref) {

		$tmp1 = &TempFile;
		$tmp2 = &TempFile;

		# Since we're quoting $cmd, we need to escape any quotes already there.
		$cmdtxt =~ s/\"/\\\"/g;
		$cmdtxt = "sh -c " . "\"$cmdtxt\" " . ">$tmp1 2>$tmp2";


		$$userstatusref = 0;

		if (defined $uerrtxt) {
			$$uerrtxt = "";
		}

		# system "sh", "-cv", "$cmdtxt", ">$tmp1 2>$tmp2";
		# system "sh -cv $cmdtxt >$tmp1 2>$tmp2";
		@cmd_output = system $cmdtxt;


		$$userstatusref = ($? >>8);
		if (defined $uerrtxt) {
			$$uerrtxt = $! if ($$userstatusref !=0);
		}

		# READ STDOUT STUFF ($tmp1)
		if (open OUT, $tmp1) {
			while (<OUT>) {
				chomp;
				push (@cmd_output, $_);
			}
			close OUT;
		} else {
			if (defined($uerrtxt)) {
				if ( $$uerrtxt eq "" ) {
					$$uerrtxt = "Could not open tmp file for reading\n";
				}
			}
		}

		# READ STDERR STUFF ($tmp2)
		if (open ERR, $tmp2) {
			while (<ERR>) {
				chomp;
				push (@stderr, $_);
			}
			close ERR;
		} else {
			if (defined $uerrtxt) {
				if ( $$uerrtxt eq "" ) {
					$$uerrtxt = "Could not open tmp file for reading\n";
				}
			}
		}

		if (defined($stderr_ref)) {
			@$stderr_ref = @stderr;
			$x = join(',',@stderr);
		}
	} else { #if stdoutput is defined
		# Since we're quoting $cmd, we need to escape any quotes already there.
		$cmdtxt =~ s/\"/\\\"/g;
		$cmdtxt = "sh -c " . "\"$cmdtxt\"";

		@cmd_output = system $cmdtxt;
		# @cmd_output = `sh -c $cmdtxt`;
		if (defined $userstatusref) {
			$$userstatusref = ($? >>8);
		}
	}
	return @cmd_output;
}

sub run_cmd
{
	local($cmd, $show_cmd) = @_;
	local ($show_return) = 1;

	$show_return = $_[2] if ($#_ > 1);

# printf "RUN_CMD:  show_cmd=%d show_return=%d #_=%d\n", $show_cmd, $show_return, $#_;

	print "$cmd\n" if $show_cmd;

	# Since we're quoting $cmd, we need to escape any quotes already there.
	$cmd =~ s/\"/\\\"/g;
	$cmd = "sh -c " . "\"$cmd\"";
	
	system $cmd;
	if ($?) {
		local($ret) = $?;
		local($anySignals) = $ret & 255;
		$ret >>= 8;
		if ($show_return) {
			print "$cmd\n" if (! $show_cmd);
			&error("return value is $ret ($anySignals)");
		}
		# make will return 130 if it was killed in the middle.
		if ($anySignals || $ret == 130) {
			# Our child process received some sort of signal.  Wait a
			# second to give it an opportunity to get sent to us as
			# well.
			sleep 1;
		}
		return 1;
	}
	return 0;
}

sub mail
{
	print "mail not supported on NT\n";
}

sub rm_recursive
{
	local($dirname) = @_;

	return &run_cmd("rm -rf $dirname", 0);
}

$OS == $NT;
