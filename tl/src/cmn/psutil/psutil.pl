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
# @(#)psutil.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# psutil.pl - utility routines to manage processes in a portable way
#

use strict;

package psutil;

require "listutil.pl";
require "path.pl";

#global variables:
my($PS_HEADER) = "";
my(@PSOUT) = ();
my($MAX_DEPTH) = 25;
my($p);
my($PID_POS, $PPID_POS, $PS_CMD, $PS_CMD2, $USER_POS);
my(%PID_USERS, %PID_COMMANDS, %PARENT, %CHILDREN);
my(@USER_LIST, @COMMAND_LIST) = ();
my($PS_TABLEINIT) = 0;
my($DEBUG) = 0;
my($DDEBUG) = 0;
my($SHOW_ALL) = 1;
my($SHOW_EXE) = 0;

&init;

sub main
#this is a test driver only.
#Usage:  ln -s `fwhich prlskel` psutil; psutil <pid> [maxdepth]
{
    local(*ARGV, *ENV) = @_;

    if ($#ARGV < 0) {
        printf STDERR ("Usage:  %s pid [maxdepth]\n", $p);
        return 1
    }

    my($thepid) = shift @ARGV;

    if ($#ARGV >= 0) {
        $MAX_DEPTH = shift @ARGV;
    }

    printf "%s:  pid=%d maxdepth=%d\n", $p, $thepid, $MAX_DEPTH;

    if (&is_active_process($thepid)) {
        printf "%s:  pid %d is an active process.\n", $p, $thepid;
    } else {
        printf "%s:  pid %d is not an active process - halt.\n", $p, $thepid;
        return 1;
    }

    my(@kids) =  &get_process_subtree($thepid);
    printf "%s:  found %d kids of %d: (%s)\n", $p, $#kids+1, $thepid, join(',', @kids);

    &show_process_tree($thepid);

    return 0;
}

sub is_active_process
#return 1 if process is active, otherwise 0
#note that the "kill 0" method suggested in the perl manual does
#not work on NT.
{
    my ($pid) = @_;

    #cygwin does not have this form of the command:
    return &is_active_process2($pid) if ($PS_CMD2 eq "NULL");

    $! = 0;
    my(@PSOUT) = `sh -c "$PS_CMD2 $pid 2> /dev/null"`;
    my($status) = ($? >> 8);        #lower eight bits hold the status.

    printf STDERR "is_active_process: pid=%d status=%d PSOUT=(%s) errno=%s[%d]\n", $pid, $status, join("", @PSOUT), $!, $! if ($DEBUG);

    return 1 if ($status == 0);     #process is active.

    return 0;
}

sub is_active_process2
#return 1 if process is active, otherwise 0
#this variant is for cygwin, which does not have "ps -p" option.
{
    my ($pid) = @_;
    my(@ptree) = ();

    #read and parse the process table
    if (&init_ps_data() !=  0) {
        printf STDERR "%s[is_active_process2]:  ERROR:  failed to initialize the process data table\n", $p;
        return 0
    }

    printf STDERR "is_active_process2: pid=%d cmd='%s'\n", $pid, $PID_COMMANDS{$pid} if ($DEBUG);

    return defined($PID_COMMANDS{$pid}) ? 1 : 0;
}

sub any_active
#true if any process id's in the arg list are ative
{
    my(@plist) = @_;

    my($nactive) = 0;
    my($pp);

    foreach $pp (@plist) {
        ++$nactive if (&is_active_process($pp));
    }

    return ($nactive > 0);
}

sub kill_process_tree
#kill a process and it's CHILDREN.
#first try normal interrupt, and allow time for the process to
#clean up.  If that doesn't work, then send a stronger signal.
#
#return 1 if successful.
{
    my ($pid) = @_;

    return 1 if (! &is_active_process($pid));   #success

    my (@plist) = &get_process_subtree($pid);

    &kill_wait(2, $pid);     #this will send signals to kids
    sleep(5);   #give them a chance to cleanup

    push (@plist, $pid);

    #make sure:
    &kill_wait(2, @plist);
    &kill_wait(15, @plist);
    &kill_wait(9, @plist);    #no-op if already dead

    #we have to assume that we killed the process tree, but it won't
    #really take effect until this command returns to the shell.
    return 1;
}

sub parent_process_list
{
    my(@u_pidlist, @c_pidlist) = ();
    my($user, $cmd, $pid);

    if ($#USER_LIST + 1 < 1 && $#COMMAND_LIST + 1 < 1 ) {
        # we're not searching by either user or cmd - return all DEFINED PPID's
        return &list::UNIQUE(keys(%PID_COMMANDS));
    }
    if ($#USER_LIST + 1 > 0 ) {
        foreach $user (@USER_LIST) {
            foreach $pid (keys %PID_USERS) {
                if ( $PID_USERS{$pid} =~ /$user/i ) {
                    push(@u_pidlist, $pid);
                }
            }
        }
    }
    if ($#COMMAND_LIST + 1 > 0 ) {
        foreach $cmd (@COMMAND_LIST) {
            foreach $pid (keys %PID_COMMANDS) {
                if ($SHOW_ALL && $PID_COMMANDS{$pid} =~ /$cmd/ ) {
                    push(@c_pidlist, $pid);
                }
                elsif  ($SHOW_EXE) {
                    my (@commands) = split( /\s/, $PID_COMMANDS{$pid});
#printf ("in SHOW_EXE of psutil - %s\n", &path::tail($commands[0]));
                    if($cmd eq &path::tail($commands[0])) {
                        push(@c_pidlist, $pid);
                    }
                }
            }
        }
    }
    if ($#USER_LIST + 1 > 0  && $#COMMAND_LIST + 1 > 0 ) {
        # we're searching by both user or cmd - return intersection PPID's
        return &list::AND(*u_pidlist, *c_pidlist);
    }
    elsif ($#USER_LIST + 1 > 0 ) {
        # we're searching by user
        return @u_pidlist;
    }
    else {
        # we're searching by command
        return @c_pidlist;
    }
}

sub kill_wait
{
    my($sig, @plist) = @_;
    my($cmd)="";

    my ($pid,$cnt) = (0,0);
    for $pid (@plist) {
        next unless (&is_active_process($pid));
        ++$cnt;
        if ($main::OS == $main::NT) {
            $cmd = sprintf ("sh -c 'kill %d 2> /dev/null'", $pid);
            system ($cmd);
        } else {
            $cmd = sprintf ("sh -c 'kill -%d %d 2> /dev/null'", $sig, $pid);
            system ($cmd);
        }
    }

    sleep 1 if ($cnt > 0);      #skip sleep if we didn't do anything.
}

sub numerically {return $a <=> $b;}

sub get_process_subtree
#this returns all the nodes in a process tree where <pid> is the root
{
    my($pid) = @_;
    my(@ptree) = ();

    #read and parse the process table
    if (&init_ps_data() !=  0) {
        printf STDERR "%s:  ERROR:  failed to initialize the process data table\n", $p;
        return (@ptree);
    }

    &do_process_tree_walk($pid,\@ptree, 0, 0);

    return(sort numerically &list::UNIQUE(@ptree));
}

sub display_process
{
    my($pid, $indent) = @_;

    printf ("%s%s (pid %d) (%s)\n", (" " x $indent), ($PID_COMMANDS{$pid}) ? $PID_COMMANDS{$pid} : "CMD UNKNOWN" , $pid, ($PID_USERS{$pid}) ? $PID_USERS{$pid} : "USER UNKNOWN");

#
#example:
#-csh (pid 20780) (russt)
#  vi pstree.pl psutil.pl (pid 482) (russt)
#  perl -x -S /lathe1/cvs/rtsodor/devtools/tools/bin/cmn/pstree 20780 (pid 5787) (russt)
#    /usr/bin/ps -ef (pid 5789) (root)
}

sub show_process_tree
#this displays a process tree, and returns all the kids in the sub-tree.
{
    my($pid) = @_;
    my(@ptree) = ();

    #read and parse the process table
    if (&init_ps_data() !=  0) {
        printf STDERR "%s:  ERROR:  failed to initialize the process data table\n", $p;
        return (@ptree);
    }

    &do_process_tree_walk($pid,\@ptree, 0, 1);  #yes display

    return(sort numerically &list::UNIQUE(@ptree));
}

sub do_process_tree_walk
#return 0 if successful
{
    my($pid, $ptree_ref, $depth, $show) = @_;

    push @{$ptree_ref}, $pid if ($depth > 0);

    #we can have loops in process trees on NT:
    if ($depth > $MAX_DEPTH) {
        printf STDERR "%s:  ERROR: exceeded maximum recursion depth of %d while walking process tree\n", $p, $MAX_DEPTH;
        return 1;
    }

    &display_process($pid, $depth) if ($show);

    #walk kids:
    my($kid, $errs) = (0,0);
    foreach $kid (&get_process_kids($pid)) {
        $errs += &do_process_tree_walk($kid, $ptree_ref, $depth+1, $show);
        last if ($errs > 0);
    }

    printf STDERR "do_process_tree_walk: pid=%d depth=%d, ptree=(%s)\n", $pid, $depth, join(',', @{$ptree_ref}) if ($DDEBUG);

    return $errs;
}

sub get_process_kids
#return the kids of <pid>
{
    my ($ppid) = @_;
    my (@plist) = ();

    my($tmp) = $CHILDREN{$ppid};
    if (defined($tmp)) {
        @plist = split($;, $tmp);
#printf "get_process_kids: tmp='%s'\n", $tmp;
    }

    return (@plist)
}

sub init_ps_data
#read and parse the ps data
#return 0 if successful
{
    my($cnt)=0;

    return 0 if ($PS_TABLEINIT);

    @PSOUT = `sh -c "$PS_CMD"`;
    if ($#PSOUT < 0) {
        return 1;
    }

    $PS_HEADER = shift @PSOUT;
    chomp $PS_HEADER;

    printf STDERR "PS_HEADER='%s', cnt=%d, nlines=%d\n", $PS_HEADER, $cnt, $#PSOUT if ($DEBUG);

    #
    # Figure out where the command column is.
    #
    my($cmd_pos) = index($PS_HEADER, "CMD");
    if ($cmd_pos == -1) {
        $cmd_pos = index($PS_HEADER, "COMMAND");
        if ($cmd_pos == -1) {
            $cmd_pos = index($PS_HEADER, "COMD");
        }       
    }
    
#print "cmd_pos = $cmd_pos\n";

    %PID_USERS = ();
    %PID_COMMANDS = ();
    %CHILDREN = ();
    %PARENT = ();
    #
    # Go thru each line of the ps output and parse out the parts we want
    # to know about.
    #
    foreach (@PSOUT) {
        chomp;

        # Get the command portion of the ps output
        my($cmd) = substr($_, $cmd_pos);

        # Get rid of the inital spaces
        s/^\s+//;

        # Get rid of duplicate spacing
        s/\s+/ /g;

        my(@columnList) = split(/ /, $_);
        my($user, $pid, $ppid) = ($columnList[$USER_POS], $columnList[$PID_POS], $columnList[$PPID_POS]);

        printf STDERR "init_ps_data: user='%s' ppid='%s' pid='%s' cmd='%s'\n", $user, $ppid, $pid, $cmd if ($DEBUG);

        $PID_USERS{$pid} = $user;
        $PID_COMMANDS{$pid} = $cmd;

        #save children unless child and parent are the same (this happens for process id 0)
        if ($pid != $ppid) {
            $PARENT{$pid} = $ppid;
            if (defined($CHILDREN{$ppid})) {
                $CHILDREN{$ppid} .= $; . $pid;
            } else {
                $CHILDREN{$ppid} = $pid;
            }
        }
        &remove_loop_ppids($pid, $pid);
    }

    # we don't want to include child pids when this script is executed.
    &delete_pid_fromtable($$);

    #this is to get around problems that some versions of perl have
    #in "deleting" hash elements.  instead of deleting keys, we undef them
    #and then re-allocate the tables:
    &reallocate_tables();

    $PS_TABLEINIT = 1;
    return 0;
}

sub remove_loop_ppids
# Remove branch loops in the pid tree - problem exists on Windows
# platforms searchs for the case (109, 232) and child node 
# (232, 109 ) where we remove the false parent pid 232 of the node
# (109, 232) thus node (109, ) becomes the root.  The alogrithm 
# starts at the leaf node and moves backward on the tree toward
# the root 0 pid.  Usage: &remove_loop_ppids( childpid, childpid );
{
    my($currentpid, $childpid) = @_;
    my($cpid);

    my($tmp) = $PARENT{$currentpid};

    if (defined($tmp)) {
#print STDERR "Current pid: $currentpid Child pid: $childpid parent of current: $tmp\n";
        if ( $childpid == $tmp ) {
            $PARENT{$currentpid} = undef;
            my(@childpids) = split($;, $CHILDREN{$tmp});
#printf STDERR ("Children of $tmp : %s\n", join( " ", @childpids));
            @childpids = &remove_child($currentpid, @childpids);
            delete $CHILDREN{$tmp};
            if ( $#childpids + 1 > 0 ) {
                $CHILDREN{$tmp} = join( $;, @childpids);
#print STDERR "New children of $tmp : $CHILDREN{$tmp}\n";
            }
        }
        else {
            &remove_loop_ppids($tmp, $childpid);
        }
    }
}

sub remove_child
{
    my($currentpid, @childpids) = @_;

    return grep("$_" ne "$currentpid", @childpids);
}

sub delete_pid_fromtable
{
    my($pid) = @_;

    my($cpid);
    my(@newchildpids) = ();
    my(@childpids) = ();
   
    $PID_USERS{$pid} = undef if defined($PID_USERS{$pid});
    $PID_COMMANDS{$pid} = undef if defined($PID_COMMANDS{$pid});

    #remove us from our parent:
    if ( defined($PARENT{$pid}) ) {
        my $ppid = $PARENT{$pid};

        if ( defined($CHILDREN{$ppid}) ) {
            @childpids = split( $;, $CHILDREN{$ppid});
            @newchildpids = &remove_child($pid, @childpids) if ($#childpids >= 0);
            if ( $#newchildpids >= 0 ) {
                $CHILDREN{$ppid} = join($;, @newchildpids);
            } else {
                #I am an only child:
                $CHILDREN{$ppid} = undef;
            }
        }
    }

#print STDERR "deleting $pid  Children: $CHILDREN{$pid}\n";

    if ( defined($CHILDREN{$pid}) ) {
        @childpids = split($;, $CHILDREN{$pid});

        #now delete our children, so the recursive call won't have to do it:
        $CHILDREN{$pid} = undef;

        #recursive call:
        foreach $cpid (@childpids) {
            &delete_pid_fromtable($cpid);
        }
    }
}

sub set_command_list
{
    @COMMAND_LIST = @_;
}

sub debug_on { print STDERR "DEBUG is ON\n"; $DEBUG = 1; }
sub debug_off { $DEBUG = 0; }
sub ddebug_on { print STDERR "DDEBUG is ON\n"; $DDEBUG = 1; }
sub ddebug_off { $DDEBUG = 0; }

sub set_user_list
{
    @USER_LIST = @_;
}

sub set_ps_commands
{
    my($PS);
    my($systemType) = `uname -s`;

    # The default columns for PS_CMD:
    $USER_POS = 0;
    $PID_POS = 1;
    $PPID_POS = 2;

    ##########
    #the basic strategy here is to use the system V
    #form of the ps command instead of the UCB form:
    ##########
    if ($systemType =~ /linux/i) {
        $PS_CMD  = "/bin/ps -jaxwww";
        $PS_CMD2 = "/bin/ps -p";

        $USER_POS = 7;
        $PID_POS = 1;
        $PPID_POS = 0;
    } elsif ($systemType =~ /CYGWIN/i) {
        $PS_CMD  = "/bin/ps -fW";
        #cygwin does not have the -p option:
        $PS_CMD2 = "NULL";

        #for ps -fW:  UID     PID    PPID TTY     STIME COMMAND
        $USER_POS = 0;
        $PID_POS = 1;
        $PPID_POS = 2;
    } elsif ($systemType =~ /Darwin/i) {
        $PS_CMD  = "/bin/ps -jaxwww";
        $PS_CMD2 = "/bin/ps -p";
    } elsif (-x "/usr/bin/ps") {
        $PS_CMD  = "/usr/bin/ps -ef";
        $PS_CMD2 = "/usr/bin/ps -p";
    } elsif (-x "/bin/ps") {
        $PS_CMD  = "/bin/ps -ef";
        $PS_CMD2 = "/bin/ps -p";
    } else {
        $PS_CMD  = "ps -ef";
        $PS_CMD2 = "ps -p";
    }


    printf STDERR "PS_CMD='%s' PS_CMD2='%s'\n", $PS_CMD, $PS_CMD2 if ($DEBUG);
}

sub init
{
    if (defined($'p)) {
        $p = $main::p . '[psutil]';
    } else {
        $p = '[psutil]';
    }

    $MAX_DEPTH = 25;    #avoid infinite recursion

    &set_ps_commands();
}

sub reallocate_tables
#reallocate our global tables, deleting undefined entries.
{
    my (%users, %cmds, %children, %parent);

    printf STDERR "count of PID_USERS before=%d\n" , &count_hash(\%PID_USERS) if ($DEBUG);

    &copy_hash(\%users, \%PID_USERS);
    &copy_hash(\%cmds, \%PID_COMMANDS);
    &copy_hash(\%children, \%CHILDREN);
    &copy_hash(\%parent, \%PARENT);

    %PID_USERS = %users;
    %PID_COMMANDS = %cmds;
    %CHILDREN = %children;
    %PARENT = %parent;

    printf STDERR "count of PID_USERS after=%d\n" , &count_hash(\%PID_USERS) if ($DEBUG);
}

sub count_hash
#return the number of keys in a hash
{
    my ($ref) = @_;
    my (@tmp) = keys %{$ref};

    return $#tmp +1;
}

sub copy_hash
#copy all keys in a has that have a defined value
{
    my ($toref, $fromref) = @_;

    my $kk = undef;

    #we're looking to see if the value of each key is defined:
    foreach $kk (grep(defined(${$fromref}{$_}), keys %{$fromref})) {
        ${$toref}{$kk}  = ${$fromref}{$kk};
    }
}

1;
