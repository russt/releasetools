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
# @(#)bldmsg.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# bldmsg.pl
#	Add pull transactions for source files.
#

package bldmsg;

require "sp.pl";

sub main
{
	local(*ARGV, *ENV) = @_;
	local($errCnt) = 0;
	local($arg, $file, $ret);

	&init;
	$ret = &ParseArgs;
	if ($ret == 2) {
		# non-error exit (like, they requested help)
		return 0;
	} elsif ($ret) {
		return $ret;
	}

	if (defined($BUILDTIME_LOG)) {
		$errCnt += &ReadEvents;
	}
	$errCnt += &bldmsg;
	if (defined($BUILDTIME_LOG) && $NeedToWriteEvents) {
		$errCnt += &WriteEvents;
	}

	return $errCnt;
}

sub Usage
{
	print <<"!"
Usage: bldmsg [-help]
              [-mark|-markbeg|-markend] [-status <number>]
              [-error|-warn] [-p|-prog <program name>]
              <message>

Print out a message in the correct syntax and also log starts and finishs as
an event if the env var BUILDTIME_LOG is set.  The BUILDTIME_LOG has the
following format (event_msg is the key, only 1 per file) (tab separated):
  (builddate, codeline, platform, hostname, start, finish, elapsed, status, event_msg)
where the values come from
  builddate  <- env var \$BUILD_DATE
  codeline   <- env var \$PATHNAME
  platform   <- env var \$FORTE_PORT
  hostname   <- env var \$HOST_NAME
  start      <- the current time (seconds since epoch) when -markbeg was done
  finish     <- the current time (seconds since epoch) when -markend was done
  elapsed    <- the difference between finish and start
  status     <- an exit status (aka error code)
  event_msg  <- the event message

-mark     Print out a MARK line
-markbeg  Print out a MARK line preceding the event with a Starting
          message.  Also log the event's start time into BUILDTIME_LOG.
-markend  Print out a MARK line preceding the event with a Finished
          message.  Also log the event's end time into BUILDTIME_LOG.
-status   Set the status code for the log.
-error    Make it an error message (set status to 1).
-warn     Make it a warning message.
-p        Take the next argument as the program name.
-prog     Alias for -p
	
    eg: bldmsg -markbeg run of c4tstdrv
    eg: bldmsg -markend run of c4tstdrv
    eg: bldmsg -mark Create trigger file for foo
    eg: bldmsg -status \$status -markend run of bar
    eg: bldmsg -error -p \$prog Unable to find to find c4tstdrv
    eg: bldmsg -warn -p \$prog Did not find xxx, continuing hoping things will be okay.
!
}

sub ParseArgs
{
	local($arg);
	while (defined($arg = shift @ARGV)) {
		if ($arg eq "-auto") {
			$AUTO = 1;
		} elsif ($arg eq "-debug") {
			$DEBUG = 1;
		} elsif ($arg eq "-help" || $arg eq "-h") {
			&Usage;
			return 2;
		} elsif (lc($arg) eq "-mark") {
			$PREFIX = $PREFIX_MARK;
		} elsif (lc($arg) eq "-markbeg") {
			$PREFIX = $PREFIX_STARTING;
		} elsif (lc($arg) eq "-markend") {
			$PREFIX = $PREFIX_FINISHED;
		} elsif (lc($arg) eq "-status") {
			$Status = shift @ARGV;
			if ($Status !~ /^\d+$/) {
				&warning("Argument to -status is nonnumeric ($Status).");
			}
		} elsif (lc($arg) eq "-error") {
			$MESSAGE_STATUS = "BUILD_ERROR";
			$Status = 1;
		} elsif (lc($arg) eq "-warn") {
			$MESSAGE_STATUS = "BUILD_WARNING";
		} elsif (lc($arg) eq "-prog" || lc($arg) eq "-p") {
			$MESSAGE_PROG = shift @ARGV;
		} else {
			if ($MESSAGE eq "") {
				$MESSAGE = $arg;
			} else {
				$MESSAGE .= " " . $arg;
			}
		}
	}
	return 0;
}

&init;
sub init
{
	$p = $'p;
	
	$DEBUG = 0;
	$VERBOSE = 1;

	$BUILDTIME_LOG = $ENV{"BUILDTIME_LOG"};
	$HOST_NAME = $ENV{"HOST_NAME"};
	if (!defined($HOST_NAME)) {
		$HOST_NAME = "unknown";
	}
	$BUILD_DATE = $ENV{"BUILD_DATE"};
	if (!defined($BUILD_DATE)) {
		$BUILD_DATE = $ENV{"DATE"};
		if (!defined($BUILD_DATE)) {
			$BUILD_DATE = "unknown";
		}
	}
	$FORTE_PORT = $ENV{"FORTE_PORT"};
	if (!defined($FORTE_PORT)) {
		$FORTE_PORT = "unknown";
	}
	$PATHNAME = $ENV{"PATHNAME"};
	if (!defined($PATHNAME)) {
		$PATHNAME = "unknown";
	}

	$PREFIX_NONE = 0;
	$PREFIX_MARK = 1;
	$PREFIX_STARTING = 2;
	$PREFIX_FINISHED = 3;

	$PREFIX = $PREFIX_NONE;
	$MESSAGE = "";
	$MESSAGE_STATUS = "";
	$MESSAGE_PROG = "";
	$Status = 0;

	$NeedToWriteEvents = 0;

	%EventStartTime = ();
	%EventEndTime = ();
	%EventMessage = ();
}

sub bldmsg
{
	if ($MESSAGE_PROG ne "") {
		$MESSAGE = $MESSAGE_PROG . ": " . $MESSAGE;
	}
	if ($MESSAGE_STATUS ne "") {
		$MESSAGE = $MESSAGE_STATUS . ": " . $MESSAGE;
	}
	if ($PREFIX == $PREFIX_NONE) {
		print "$MESSAGE\n";
	} elsif ($PREFIX == $PREFIX_MARK) {
		&mark($MESSAGE);
	} elsif ($PREFIX == $PREFIX_STARTING) {
		&starting($MESSAGE);
	} elsif ($PREFIX == $PREFIX_FINISHED) {
		&finished($MESSAGE);
	} else {
		return 1;
	}
	return 0;
}

sub starting
{
	my($msg) = @_;
	my($key) = &Event2Key($msg);

	$EventMessage{$key} = $msg;
	if (defined($EventStartTime{$key})) {
		&warning("Event '$key' already has been started.  Use a different event name.");
	}
	$EventDate{$key} = $BUILD_DATE;
	$EventPort{$key} = $FORTE_PORT;
	$EventPathName{$key} = $PATHNAME;
	$EventHostName{$key} = $HOST_NAME;
	$EventStartTime{$key} = time;
	$EventEndTime{$key} = -1;
	$EventElapsedTime{$key} = -1;
	$EventStatus{$key} = $Status;
	$NeedToWriteEvents = 1;
	&mark("Starting $msg");
}

sub finished
{
	my($msg) = @_;
	my($key) = &Event2Key($msg);

	$EventMessage{$key} = $msg;
	$EventDate{$key} = $BUILD_DATE;
	$EventPort{$key} = $FORTE_PORT;
	$EventPathName{$key} = $PATHNAME;
	$EventHostName{$key} = $HOST_NAME;
	$EventEndTime{$key} = time;
	if (defined($EventStartTime{$key})) {
		$EventElapsedTime{$key} = $EventEndTime{$key} - $EventStartTime{$key};
	} else {
		$EventStartTime{$key} = -1;
		$EventElapsedTime{$key} = -1;
	}
	$EventStatus{$key} = $Status;
	$NeedToWriteEvents = 1;
	&mark("Finished $msg");
}

sub mark
{
	my($msg) = @_;
	my($date);
	$date = &sp::GetDateStr;
	print "\nMARK $date\: $msg\n";
# 	if ($MarkWritesToStatus) {
# 		&WriteStatus($msg);
# 	}
}

sub Event2Key
{
	my($event) = @_;
	$event =~ s/^BUILD_ERROR://;
	$event = lc($event);
	$event =~ s/^\s+//;
	$event =~ s/\s+$//;
	return $event;
}

sub ReadEvents
{
	if (! -e $BUILDTIME_LOG) {
		# Nothing to read; we're done.
		return 0;
	}
	if (!open(IN, $BUILDTIME_LOG)) {
		&error("Failed to open $BUILDTIME_LOG for read: $!");
		return 1;
	}
	my($line);
	my($event, $date, $pathName, $fortePort, $hostName, $startTime, $endTime, $elapsedTime, $status);
	while (defined($line = <IN>)) {
		chomp($line);
		($date, $pathName, $fortePort, $hostName, $startTime, $endTime, $elapsedTime, $status, $event) =
			split(/\s+/, $line, 9);

		if (! defined($event)) {
			next;
		}

		my($key) = &Event2Key($event);
		print "ReadEvents: key='$key' event='$event'\n" if ($DEBUG);
		
		$EventMessage{$key} = $event;
		$EventDate{$key} = $date;
		$EventPort{$key} = $fortePort;
		$EventPathName{$key} = $pathName;
		$EventHostName{$key} = $hostName;
		$EventStartTime{$key} = $startTime;
		$EventEndTime{$key} = $endTime;
		$EventElapsedTime{$key} = $elapsedTime;
		$EventStatus{$key} = $status;
	}
	close(IN);
	return 0;
}

sub WriteEvents
{
	if (!open(OUT, ">$BUILDTIME_LOG")) {
		&error("Failed to open $BUILDTIME_LOG for write: $!");
		return 1;
	}
	my(@events);
	@events = keys %EventStartTime;
	push(@events, keys %EventEndTime);
	@events = &sp::uniq(@events);

	my($event, $date, $pathName, $fortePort, $hostName, $startTime, $endTime, $elapsedTime, $status);
	foreach $key (@events) {
		$event = $EventMessage{$key};
		if (!defined($event)) {
			&error("event is undefined for key '$key'.");
		}
		$date = $EventDate{$key};
		if (!defined($date)) {
			$date = "";
		}
		$fortePort = $EventPort{$key};
		if (!defined($fortePort)) {
			$fortePort = "";
		}
		$pathName = $EventPathName{$key};
		if (!defined($pathName)) {
			$pathName = "";
		}
		$hostName = $EventHostName{$key};
		if (!defined($hostName)) {
			$hostName = "";
		}
		$startTime = $EventStartTime{$key};
		if (!defined($startTime)) {
			$startTime = -1;
		}
		$endTime = $EventEndTime{$key};
		if (!defined($endTime)) {
			$endTime = -1;
		}
		$elapsedTime = $EventElapsedTime{$key};
		if (!defined($elapsedTime)) {
			$elapsedTime = -1;
		}
		$status = $EventStatus{$key};
		if (!defined($status)) {
			$status = 0;
		}
		print OUT "$date\t$pathName\t$fortePort\t$hostName\t$startTime\t$endTime\t$elapsedTime\t$status\t$event\n";
	}
	close(OUT);
	return 0;
}

sub warning
{
	local($msg) = @_;

	print "BUILD_WARNING: $p: $msg\n";
}

sub error
{
	local($msg) = @_;

	print "BUILD_ERROR: $p: $msg\n";
}

1;
