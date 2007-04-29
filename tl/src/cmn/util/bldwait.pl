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
# @(#)bldwait.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#bldwait - wait for trigger files.
#
#  27-Feb-98 (russt)
#	Initial revision
#

package bldwait;

require "bldmsg.pl";

#################################### MAIN #####################################

&init;

sub main
{
	local(*ARGV, *ENV) = @_;

	#set global flags:
	if (&parse_args != 0) {
		return 1;
	}

	if ($#TRIGGERS < 0) {
		&start_msg($CALLER, $MESSAGE, "$MAX_SECONDS seconds");
		sleep($MAX_SECONDS);
		&finish_msg(0, $CALLER, $MESSAGE, "$MAX_SECONDS seconds");
	} else {
		for $fn (@TRIGGERS) {
			#wait forever
			if ($MAX_SECONDS == 0) {
				&start_msg($CALLER, $MESSAGE, $fn);
				for (;;) {
					last if (-f $fn);
					sleep($INTERVAL);
				}
				&finish_msg(0, $CALLER, $MESSAGE, $fn);
			} else {
				$nintervals = $MAX_SECONDS / $INTERVAL;
				$rem = $MAX_SECONDS % $INTERVAL;
				&start_msg($CALLER, $MESSAGE, $fn);
				for ($ii=1; $ii<= $nintervals; ++$ii ) {
					last if (-f $fn);
					sleep($INTERVAL);
				}

				if (! -f $fn && $rem > 0) {
					sleep($rem);
				}

				$wstatus = 0;
				$wstatus = 2 if (! -f $fn);

				&finish_msg($wstatus, $CALLER, $MESSAGE, $fn);
				return $wstatus if ($wstatus != 0);
			}
		}
	}

	return(0);
}

################################### SUBROUTINES ##################################

sub eventmsg
{
	return if ($DOMSG == 0);

	my ($event, $status, $prog, $msg, $trg) = @_;
	local (@args) = ();


	#
	# setup -mark, -markbeg, or -markend:
	#
	if ($MARKTIME) {
		push(@args, "-markbeg") if ($event == $BEG_EVENT);
		push(@args, "-markend") if ($event == $END_EVENT);
		if ($msg eq "") {
			$msg = "wait";
			$msg .= " for $trg" if ($trg ne "");
		}
	} else {
		push(@args, "-mark");
		if ($msg eq "") {
			$msg = "wait";
			$msg .= " for $trg" if ($trg ne "");
		}
		$msg = "Starting " . $msg if ($event == $BEG_EVENT);
		$msg = "Finished " . $msg if ($event == $END_EVENT);
	}

	#
	# setup program name arg:
	#
	push(@args, "-p", $prog) if ($prog ne "");

	push(@args, "-status", "$status");
	push(@args, $msg);

#printf "args=(%s)\n", join(',', @args);

	$'p = "bldmsg";
	&bldmsg'main(*args, *ENV);
	$'p = $p;
}

sub finish_msg
{
	local($status, @args) = @_;

	&eventmsg($END_EVENT, $status, @args);
}

sub start_msg
{
	&eventmsg($BEG_EVENT, 0, @_);
}

sub GetDateStr
	# Return the current date as if you ran `date`
{
	local (@days) = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat");
	local (@months) =
		("Jan","Feb","Mar","Apr","May","Jun", "Jul","Aug","Sep","Oct","Nov","Dec");

	#0   1   2    3    4   5    6    7    8
	#sec min hour mday mon year wday yday isdt
	local ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdt) = localtime();
	$yday = $yday if (1 > 2);	#squawk off

	#######
	#Example output:
	#Tue Mar  3 13:27:53 PST 1998
	#######
	return sprintf "%s %s %2d %02d:%02d:%02d %s %4d",
					 $days[$wday], $months[$mon], $mday,
					 $hour, $min, $sec, $isdt ? "PDT" : "PST",
					 ($year < 90 ? $year += 2000:$year += 1900);
}

################################ USAGE SUBROUTINES ###############################

sub usage
{
	local($status) = @_;

    print STDERR <<"!";
Usage:  $p [-help] [-i interval] [-max max_seconds] [-nomsg] [-marktime]
        [-p program_name] [-m mmessage_text] [trigger_files...]

 Waits for each trigger file to come into existence.

 If time is specified and trigger files are not - the
 behavior is equivalent to "sleep <max_seconds>".

OPTIONS
 -help
    show this usage message
 -i interval
    check for trigger files each <interval> seconds.
 -max max_seconds
    Wait up to max_seconds for each trigger file
    to come into existence.
 -nomsg
    don't display start/stop messages.
 -marktime
    generate -markbeg, -markend messages as in bldmsg(1).
 -p program_name
    Display <program_name> with begin/end messages.
 -m message_text
    Display <message_text> with begin/end messages
    instead of default message ("waiting").

NOTES
 If -p or -m specified, then will display MARK messages
 of the form:

   MARK <date>: <program>: Starting <message_text>
   MARK <date>: <program>: Finished <message_text>

 Default message text is "waiting [for <trigger_file>]"

 Start/Finished messages are displayed for each trigger file.

ENVIRONMENT
 If the -marktime option is provided, then wait times
 will be saved in the BUILD_TIMES log (see bldmsg).

EXIT CODES
 Status 0 if triggers satisfied.

 Status 1 if usage or other error.
 
 Status 2 if -max flag & times out waiting for one of
 the specified trigger files.

EXAMPLES
  $p -max 600 -marktime \$PATHREF/bldlock/build_4gl.rdy
!
    return($status);
}

sub parse_args
#proccess command-line aguments
{
	local ($flag);

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flag = shift(@ARGV);

		if ($flag eq '-max') {
			if ($#ARGV < 0) {
				printf STDERR "%s: -max requires a numeric parameter\n", $p;
				return &usage(1);
			}
			$MAX_SECONDS = shift(@ARGV);
			if ($MAX_SECONDS !~ /^[0-9]+$/) {
				printf STDERR "%s: ERROR: non-numeric value (%s) specified for -max.\n", $p, $MAX_SECONDS;
				return &usage(1);
			}
		} elsif ($flag eq '-p' || $flag eq '-prog') {
			if ($#ARGV < 0) {
				printf STDERR "%s: -p requires program name string.\n", $p;
				return &usage(1) 
			}
			$CALLER = shift(@ARGV);
		} elsif ($flag eq '-m') {
			if ($#ARGV < 0) {
				printf STDERR "%s: -m requires quoted message text\n", $p;
				return &usage(1) 
			}
			$MESSAGE = shift(@ARGV);
		} elsif ($flag eq '-nomsg') {
			$DOMSG = 0;
		} elsif ($flag eq '-marktime') {
			$MARKTIME = 1;
		} elsif ($flag eq '-i') {
			if ($#ARGV < 0) {
				printf STDERR "%s: -i requires a numeric parameter\n", $p;
				return &usage(1);
			}
			$INTERVAL = shift(@ARGV);
			if ($MAX_SECONDS !~ /^[0-9]+$/) {
				printf STDERR "%s: ERROR: non-numeric value (%s) specified for -i.\n", $p, $INTERVAL;
				return &usage(1);
			}
		} elsif ($flag =~ '^-h') {
			return &usage(2);
		} else {
			printf STDERR "%s: unrecognized option, '%s'\n", $p, $flag;
			return &usage(1);
		}
    }

	$INTERVAL=$MAX_SECONDS if ($MAX_SECONDS > 0 && $MAX_SECONDS < $INTERVAL);

    #take remaining args as trigger files:
    if ($#ARGV >= 0 && $ARGV[0] ne "") {
		@TRIGGERS = @ARGV;
		$HAVE_TRIGGERS=1;
	}

	#if nothing to do, then don't display message:
	$DOMSG = 0 if (!$HAVE_TRIGGERS && $MAX_SECONDS <= 0);

	return 0;
}

sub init
{
	$HAVE_TRIGGERS=0;
	$MAX_SECONDS = 0;
	$INTERVAL = 30;		#how long between file checks
	$CALLER = "";		#name of calling program
	$MESSAGE = "";		#message to display before/after wait MARKS
	$DOMSG = 1;		#default is to display start/finish message
	$MARKTIME = 0;	#call bldmsg -markbeg & bldmsg -markend

	$BEG_EVENT = 100;
	$END_EVENT = 101;

	# Flush stdout immidiately; otherwise, the user won't necessarily see
	# our output about waiting until the trigger happens.
	$| = 1;
}

1;
