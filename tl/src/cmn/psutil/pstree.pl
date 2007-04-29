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
# @(#)pstree.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# pstree.pl - print out a process tree listing
#

package pstree;

require "psutil.pl";

&init;

#################################### MAIN #####################################

sub main
{
    local(*ARGV, *ENV) = @_;
    local($HELPFLAG);
    local($KILL_PROC);
    local($ppid);
    local(@PID_LIST, @USER_LIST, @CMD_LIST) = ();

    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    if (&psutil::init_ps_data() !=  0) {
        printf STDERR "%s:  ERROR:  failed to initialize the process data table\n", "psutil";
    }

    if ($#PID_LIST + 1 < 1) {
        #set display options:
        &psutil::set_user_list(@USER_LIST);
        &psutil::set_command_list(@CMD_LIST);
        @PID_LIST = &psutil::parent_process_list();
    }

    #note that if a PID_LIST is given, we will always display only
    #those pids even if user and command is specified.

    foreach $ppid (@PID_LIST) {
        &psutil::show_process_tree($ppid);
    }

    if ($KILL_PROC && $#PID_LIST + 1 > 0) {
        if ($FORCE_KILL == 0) {
            print "\nKill them? ";
            $ans = <STDIN>;

            if ($ans !~ /^y/i) {
                return 0;
            }
        }
        foreach $thepid (@PID_LIST) {
            if (&psutil::kill_process_tree($thepid)) {
                #successful...
            } else {
                #failed to kill process tree...
                printf STDERR "%s:  ERROR:  unable to kill process tr
ee %d\n", $p, $thepid;
            }
        }
    }
    return 0;
}

sub usage
{
    my($status) = @_;

# not supported now -   -ps      display process info similar to raw ps command

    print STDERR <<"!";
Usage:  $p [-h] [-u user] [-c cmd] [pid...]

SYNOPSIS
  Display process table in tree form.

OPTIONS
  -help    display this usage message and exit.
  -debug   turn on debugging
  -c cmd   only show process trees where the command
           string contains pattern <cmd>.
           This option can be repeated.
  -exe exe only show process trees where the command exactly
           matches <exe>
           This option can be repeated.
  -u user  only show process trees owned by <user>.
           This option can be used with -exe and/or -c to give the
           intersection of user & command
           This option can be repeated.
  -kill    kill the generated pid list
  -f       force kill - do not confirm actions. USE WITH CAUTION!

EXAMPLE
  $p 233
  $p -c daemon -u root
  $p -c csh
!

    return ($status);
}

sub parse_args
{
    local(*ARGV, *ENV) = @_;

    #Set default options:

    $KILL_PROC = 0;
    $HELPFLAG = 0;
    $DISPLAY_TYPE = $psutil::DISPLAY_NORMAL;
    @USER_LIST = ();
    @CMD_LIST = ();
    @PID_LIST = ();
    $FORCE_KILL = 0;
    $DEBUG = 0;
    $DDEBUG = 0;

    #eliminate empty args (this happens on some platforms):
    @ARGV = grep(!/^$/, @ARGV);

    my ($flag);
    while ($#ARGV >= 0 && $ARGV[0] =~ /^-/) {
        $flag = shift(@ARGV);
        if ($flag eq "-u") {
            push(@USER_LIST, shift @ARGV);
        } elsif ($flag eq "-c") {
            push(@CMD_LIST, shift @ARGV);
            $psutil::SHOW_ALL = 1;
            $psutil::SHOW_EXE = 0;
        } elsif ($flag eq "-kill") {
            $KILL_PROC = 1;
        } elsif ($flag =~ '^-dd') {
            $DDEBUG = 1;
            &psutil::ddebug_on();    #turn on deep debugging in psutil
        } elsif ($flag =~ '^-d') {
            $DEBUG = 1;
            &psutil::debug_on();    #turn on debugging in psutil
        } elsif ($flag =~ /^-f/) {
            $FORCE_KILL = 1;
        } elsif ($flag eq "-exe") {
            push(@CMD_LIST, shift @ARGV);
            $psutil::SHOW_ALL = 0;
            $psutil::SHOW_EXE = 1;
        } elsif ($flag =~ /^-h/) {
            $HELPFLAG = 1;
            return &usage(0);
        } else {
            printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
            return &usage(1);
        }
    }

    if ($#ARGV >= 0) {
        @PID_LIST = @ARGV;
    }

    #check that process id's are numeric
    for (@PID_LIST) {
        if ($_ !~ /^\d+$/) {
            printf STDERR "%s:  process id argument '%s' is not numeric - HALT.\n", $p, $_;
            return 1;
        }
    }

    if ($#PID_LIST >= 0) {
        if ($#USER_LIST >= 0) {
            printf STDERR "%s:  WARNING: will ignore -u args because process id list was given.\n", $p;
        }

        if ($#CMD_LIST >= 0) {
            printf STDERR "%s:  WARNING: will ignore -c args because process id list was given.\n", $p;
        }
    }

    return 0;
}

sub init
#copies of global vars from main package:
{
    $p = $main::p;       #set by the skeleton
}
1;
