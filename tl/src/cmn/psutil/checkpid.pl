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
# @(#)checkpid.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# checkpid - get/set sh/csh properties from a file
#

#use strict;
package checkpid;

require "psutil.pl";    #use process managment utilities.

my($p) = $'p;       #$main'p is the program name set by the skeleton
my($VERBOSE, $HELPFLAG, $DOKILL, $DOCLEAN, $TIMEOUT, $PIDFILE);
my($STAT_MTIME, $PGREP_AVAILABLE);

&init;      #init globals

sub main
{
    local(*ARGV, *ENV) = @_;

    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    my($thepid) = 0;

    #init again with debug:
    &psutil::init();
    
    if (!-e $PIDFILE) {
        printf STDERR ("%s:  pid file (%s) nonexistent => inactive process.\n", $p, $PIDFILE) if ($VERBOSE);
        return 0
    }

    $thepid = &read_pid($PIDFILE);
    if ($thepid <= 0) {
        printf STDERR "%s:  ERROR reading pid file '%s' => usage error.\n", $p, $PIDFILE;
        return 2
    }

    if ( ! &psutil::is_active_process($thepid) ) {
        printf STDERR ("%s:  process %d is not active\n", $p, $thepid) if ($VERBOSE);

        &doclean($PIDFILE);   #this routine displays messages.

        #always return zero if the process is not running:
        return 0
    }

    #########
    #if we get here, process is active.
    #########

    printf STDERR ("%s:  process %d is active.\n", $p, $thepid) if ($VERBOSE);

    #should we try to kill it?
    if ($DOKILL) {
        my ($runtime) = (time - &filemodtime($PIDFILE));
        if ($runtime  >= $TIMEOUT) {
            if ($VERBOSE) {
                printf STDERR
                    "%s:  process %d has been inactive for %d seconds and has timed out - attempting to kill.\n",
                    $p, $thepid, $runtime;
            }
            if (&psutil::kill_process_tree($thepid)) {
                #successful... 
                &doclean($PIDFILE);   #optional clean
                return 0;
            } else {
                #failed to kill process tree... 
                printf STDERR "%s:  ERROR:  unable to kill process tree %d\n", $p, $thepid;
                return 3;
            }
        } else {
            if ($VERBOSE) {
                printf STDERR
                    "%s:  process %d was active %d seconds ago, %d seconds left to timeout\n",
                    $p, $thepid, $runtime, $TIMEOUT - $runtime;
            }
            return 1;
        }
    } elsif ($VERBOSE) {
        &psutil::show_process_tree($thepid);
    }
    
    #process is active and we were not asked to kill it:
    return 1;
}

sub filemodtime
#stat a file and return the last modification time.
#return -1 if error.
{
    my ($fn) = @_;

    my (@rec) = stat $fn;
    
    if ($#rec >= $STAT_MTIME) {
        return( $rec[$STAT_MTIME]);
    } else {
        printf STDERR ("%s:  stat failed on '%s' - %s\n", $p, $fn, $!);
    }

    return(0);
}

sub read_pid
#return a process id contained in a file.  The pid must be alone on the first
#line of the file.
#
#return a positive process-id if file exists and number is valid.
#return < 0 if error.
{
    my ($fn) = @_;

    if (!open(IN, $fn)) {
        printf STDERR ("%s:  Failed to open %s for read: %s\n", $p, $fn, $!);
        return -1;
    }

    my($pid) = "";
    while (defined($pid = <IN>)) {
        chomp $pid;
        last;   #just read the first line
    }
    close IN;

    if ($pid eq "" ) {
        printf STDERR ("%s:  pid file '%s' is empty or first line is empty\n", $p, $fn);
        return -1;
    }

    if ($pid !~ /^\d+$/) {
        printf STDERR ("%s:  line #1 of pid file '%s' contains non-numeric data: '%s'\n", $p, $fn, $pid);
        return -1;
    }

    return $pid;
}

sub doclean
#return 0 if success
{
    return 0 if (!$DOCLEAN);

    printf STDERR ("%s:  removing pid file '%s'\n", $p, $PIDFILE) if ($VERBOSE);

    unlink($PIDFILE);

    if (-e $PIDFILE) {
        printf STDERR "%s:  ERROR:  process not running, but could not remove pid file '%s'.\n", $p, $PIDFILE;
        return 1;    #error return
    }

    return 0;
}

sub usage
{
    my($status) = @_;

    print STDERR <<"!";
Usage:  $p [-help] [-verbose]
                 [-clean] [-killontimeout timeout] pidfile

SYNOPSIS
  Check on a running process identified by first line of <pidfile>.
  If the process is running and the -killontimeout time is specified, then
  check the modification time on <pidfile> - if it hasn't been modified
  in <timeout> seconds, then attempt to kill the process tree.

  Exit with status 0 if the process is not running or
  we manage to kill it successfully, or the pidfile does
  not exist.

  Exit with non-zero status if the process is left running,
  or we cannot kill it, or the pidfile is unreadable or has
  bad data in it.

OPTIONS
  -help     Display this help message.
  -verbose  Display informational messages.
  -debug    Display debug messages.
  -ddebug   Display deep debug messages.

  -clean    Remove <pidfile> if the process is inactive or we
            kill it successfully.

  -killontimeout timeout
            If process is active and <pidfile> has not been modified
            for <timeout> seconds then attempt to kill the process tree.
            Exit with 0 status if successful.
            
EXAMPLE
  $p -clean -killontimeout 600 myserverpid.txt

!
    return ($status);
}

sub parse_args
#proccess command-line aguments
{
    local(*ARGV, *ENV) = @_;

    $VERBOSE = $HELPFLAG = $DOKILL = $DOCLEAN = $TIMEOUT = 0;
    $DEBUG = 0;
    $DDEBUG = 0;

    #eliminate empty args (this happens on some platforms):
    @ARGV = grep(!/^$/, @ARGV);

    #eat up flag args:
    my ($flag);
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
        $flag = shift(@ARGV);

        if ($flag =~ '^-v') {
            $VERBOSE = 1;
        } elsif ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return &usage(0);
        } elsif ($flag =~ '^-dd') {
            $DDEBUG = 1;
            &psutil::ddebug_on();    #turn on deep debugging in psutil
        } elsif ($flag =~ '^-d') {
            $DEBUG = 1;
            &psutil::debug_on();    #turn on debugging in psutil
        } elsif ($flag =~ '^-clean') {
            $DOCLEAN = 1;
        } elsif ($flag =~ '^-kill') {
            return &usage(1) if (!@ARGV);
            $DOKILL = 1;
            $TIMEOUT = shift(@ARGV);
        } else {
            printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
            return &usage(1);
        }
    }

    if (!@ARGV) {
        printf STDERR "%s:  you must specify a pidfile\n", $p;
        return &usage(1);
    }

    $PIDFILE = shift(@ARGV);

    return 0;
}

sub init
{
    #record defs for stat buf:
    #$N_STATBUF = 12;
    #($DEV, $INO, $MODE, $NLINK, $UID, $GID, $RDEV, $SIZE,
    # $ATIME, $MTIME, $CTIME, $BLKSIZE, $BLOCKS) =  (0..$N_STATBUF);

    $STAT_MTIME = 9;

    $PGREP_AVAILABLE = (-x "/bin/pgrep");
}

sub cleanup
{
}
1;
