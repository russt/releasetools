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
# @(#)junitreport.pl - ver 1.1 - 08/16/2007
#
# Copyright 2007-2007 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# junitreport - show junit test totals
#

package junitreport;

use strict;

&init;      #init globals

my (
    $p,
    #options:
    $VERBOSE,
    $DEBUG,
    $DDEBUG,
    $HELPFLAG,
    $CONTINUOUS,
    $LOOP_DELAY,
    #accumulators:
    $TEST_TOTAL_COUNT,
    $TEST_TOTAL_FAILURES,
    $TEST_TOTAL_ERRORS,
    $TEST_TOTAL_TIME,
    $TEST_RUNNING,
) = (
    $main::p,       #$main'p is the program name set by the skeleton
    0,    #VERBOSE option
    0,    #DEBUG
    0,    #DDEBUG
    0,    #HELPFLAG option
    0,    #CONTINUOUS (-loop) option
    1,    #LOOP_DELAY - seconds between loops if -loop
    0,    #TEST_TOTAL_COUNT
    0,    #TEST_TOTAL_FAILURES
    0,    #TEST_TOTAL_ERRORS
    0,    #TEST_TOTAL_TIME
    "NONE",    #TEST_RUNNING
);

sub main
{
    local(*ARGV, *ENV) = @_;

    &init;      #init globals

    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    my (@filelist) = (@ARGV);

    if ($#filelist < 0) {
	push @filelist, "-";
    }

    my $last_test = "";
    my $current_test_runtime = 0;

    for (;;) {
	&init_counts();
	$last_test = $TEST_RUNNING;

	for (@filelist) {
	    &junit_summary($_);
	}

	if ($last_test eq $TEST_RUNNING) {
	    $current_test_runtime += $LOOP_DELAY 
	} else {
	    $current_test_runtime = 0;
	}

	printf "%s=%d\n%s=%d\n%s=%d\n%s=%.2f\n%s%s=%s\n",
	    "junit.test.count", $TEST_TOTAL_COUNT,
	    "junit.error.count", $TEST_TOTAL_FAILURES,
	    "junit.failure.count", $TEST_TOTAL_ERRORS,
	    "junit.total.time", $TEST_TOTAL_TIME,
	    "junit.running", ($CONTINUOUS ? sprintf("[%03d]", $current_test_runtime) : ""), $TEST_RUNNING,
	    ;

	last unless ($CONTINUOUS);

	## loop again:

	sleep($LOOP_DELAY);

    }

    return 0;
}

sub junit_summary
#return 0 if no errors
{
    my ($filename) = @_;

    if (!open(INFILE, $filename)) {
        printf STDERR "%s:  cannot open file '%s'\n", $p, $filename;
        return 0;
    }

    my($line, $linecnt) = ("", 0);
    my($errcnt) = 0;

    while (defined($line = <INFILE>)) {
        ++$linecnt;
        chomp $line;

        printf STDERR ("Reading line [%d] %s\n", $linecnt, $line) if ($VERBOSE);

        #keep track of last test that is running:
        # [junit] Running com.sun.jbi.internationalization.MessagesTest
        # [surefire] Running com.sun.jbi.component.mgmt.task.TaskXmlWriterTest

        if ( $line =~ /\[(junit|surefire)\] Running / ) {
	    $TEST_RUNNING = $line;
	    $TEST_RUNNING =~ s/^.*Running\s+//;
	}

        if ( $line =~ /(Tests run:.*)/ ) {
	    #eliminate junit/maven prefixes:
            $line = $1;
        } else {
            #no test result string; skip line:
            next;
        }

	#skip summary lines:
        next if ( $line !~ /Time elapsed:/ );

#printf "line='%s'\n", $line;

        #Tests run: 5, Failures: 0, Errors: 0, Time elapsed: 1.673 sec
	#Tests run: 2, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 1.133 sec

        my(@rec) = split(/,\s*/, $line);
        if ($#rec < 3) {
	    printf STDERR "QUESIONABLE[%d]: %s\n", $linecnt, $line;
            next;
        }

printf "#rec=%d rec=(%s)\n", $#rec, join("|", @rec) if ($DEBUG);


	#Skipped tests are not reported uniformly - delete:
	@rec = grep($_ !~ /Skipped:/, @rec);

        #separate and reduce fields:
        my ($run, $failed, $errors, $elapsed) = (@rec);
        $run     = $1 if ( $run     =~ /(\d+)$/     );
        $failed  = $1 if ( $failed  =~ /(\d+)$/     );
        $errors  = $1 if ( $errors  =~ /(\d+)$/     );
        $elapsed = $1 if ( $elapsed =~ /(\d+(\.\d+)?)/ );
printf "run='%s' failures='%s' errors='%s' elapsed='%s'\n", $run, $failed, $errors, $elapsed if ($DEBUG);

        #add test data to global counts:
        $TEST_TOTAL_COUNT    += $run;
        $TEST_TOTAL_FAILURES += $failed;
        $TEST_TOTAL_ERRORS   += $errors;
        $TEST_TOTAL_TIME     += $elapsed;
    }

    close(INFILE);

    return $errcnt;
}

sub init
{
    &init_counts();
}

sub init_counts
{
    $TEST_TOTAL_COUNT = $TEST_TOTAL_FAILURES = $TEST_TOTAL_ERRORS = $TEST_TOTAL_TIME = 0;
    print `clear` if ($CONTINUOUS);
}

sub parse_args
#proccess command-line aguments
{
    local(*ARGV, *ENV) = @_;

    #eat up flag args:
    my ($flag);
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
        $flag = shift(@ARGV);

        if ($flag =~ '^-v') {
            $VERBOSE = 1;
        } elsif ($flag =~ '^-d') {
            $DEBUG = 1;
        } elsif ($flag =~ '^-dd') {
            $DDEBUG = 1;
        } elsif ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return &usage(0);
        } elsif ($flag =~ '^-l') {
	    $CONTINUOUS = 1;
        } else {
            printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
            return &usage(1);
        }
    }

    #eliminate empty args (this happens on some platforms):
    @ARGV = grep(!/^$/, @ARGV);

    return 0;
}

sub usage
{
    my($status) = @_;

    print STDERR <<"!";
Usage:  $p [-help] [-verbose] [-loop] [file ..]

SYNOPSIS
  Read one or more files containing junit test summary lines,
  and calculate and display total test counts.

OPTIONS
  -help    Display this help message.
  -verbose Display informational messages.
  -debug   Display debug messages.

  -loop    rescan results every $LOOP_DELAY second(s).
           (Hit interrupt key to quit).

EXAMPLE
  %  junitreport test.out
  junit.test.count=1791
  junit.error.count=0
  junit.failure.count=0
  junit.total.time=732.08
  junit.running=FooTest

  The junit.running test is the last test that was scanned.  In -loop
  mode, junit.running is the test currently running, displayed with
  the accumulated seconds since it was first scanned.  This display
  is updated every $LOOP_DELAY second(s).

CONFIGURATION
  The $p command scans for summary lines in the junit output
  to construct test statistics.  You can configure junit
  to display these lines as follows:

  Maven surefire configuration:

    <plugin>
	<artifactId>maven-surefire-plugin</artifactId>
	...
	<configuration>
	    <printSummary>true</printSummary>
  

  Ant junit configuration:

    <junit ...  printsummary="yes" .. >
	...
    </junit>

!
    return ($status);
}

sub cleanup
{
}
1;
