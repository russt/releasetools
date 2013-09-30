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
# @(#)makedrv.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# makedrv - a driver for build operations.
#
# TAB SETTINGS: tabstop=4, shiftwidth=4
#
#

##################################### INIT ####################################
                 
package makedrv;    #portable version of the makedrv command

require "os.pl";
require "sp.pl";    #support routines.
require "path.pl";  #pathname routines.
require "listutil.pl";  #list utilities

$p = $'p;       #$main'p is the program name set by the skeleton
$OS = $'OS;
$NT = $'NT;
$UNIX = $'UNIX;

&init;

##################################### MAIN ####################################

sub main
# NOTE ON RETURN VALUES:
#   &os' routines:  0 on success
#
# this module:
#   ALL ROUTINES:  0 on success, <nerrs> on failure.
#
#PERL:
#   symlink:    >0 on success
#   unlink:     >0 on success
{
    local(*ARGV, *ENV) = @_;
    local($nerrs) = 0;

    &init;

    local($status) = &parse_args();
    if ($status != 0) {
        return (0) if ($status == 2);   #not an error to ask for help.
        return $status;
    }

    if ($help) {
        foreach $cmd (@CMD) {
            if (defined($CMD_HELP{$cmd})) {
                $cmdproc = $CMD_HELP{$cmd};
                eval("$cmdproc('$cmd')");
                if ($@ ne "") {
                    print "BUILD_ERROR: $@\n";
                    $nerrs++;
                }
            } else {
                &error("Command $cmd is unknown. $!");
                $nerrs++;
            }
        }
        exit $nerrs;
    }

    if (!&check_env) {
        return 1;
    }

    if (&set_service_lists != 0) {
        if (grep("bdb", @CMD)) {
            @CMD = grep($_ ne "bdb", @CMD);
            &cmd_bdb("bdb");
        }
        #if we still can't set it...
        if (&set_service_lists != 0) {
            print "BUILD_ERROR: cannot find valid services file.\n";
            return 1;
        }
    }

#printf "CWD_FLAG=%d CURRENT_SRC_DIR='%s' DOSVC=(%s)\n", $CWD_FLAG, $CURRENT_SRC_DIR, join(',', @DOSVC);
#exit 0;

    foreach $cmd (@CMD)
    {
        print "cmd='$cmd'\n" if ($debug);
        if (defined($CMD_PROCESSOR{$cmd})) {
            #check for and source the bdb definition file for this command:
            &source_cmd_definitons($cmd) unless ($NORC);

            $cmdproc = $CMD_PROCESSOR{$cmd};
            printf("\$nerrs += $cmdproc('$cmd')\n") if ($debug);
            eval("\$nerrs += $cmdproc('$cmd')");        #eval works on os390
            # check for static (syntax, semantic, etc) errors from the eval
            if ($@ ne "") {
                print "BUILD_ERROR: $@\n";
            }
        } else {
            $nerrs += &cmd_generic($cmd);
        }
    }

    return $nerrs;

    &squawk_off;    #shut up extraneous perl warnings
}


sub source_cmd_definitons
#look for a file of the form <cmd>.rc in the bdb lib path.
#if it exists, require it.  This can cause syntax errors.
{
    local ($cmd) = @_;

    foreach $BDB (@BDB_LIBPATH) {
        my $fn = &path::mkpathname($BDB, $cmd . ".rc");
        print("looking for command definition file $fn\n") if ($debug);

        next if (! -r $fn);

        printf("Reading definition file '%s' for command '%s'\n", $fn, $cmd) unless ($QUIET);

        my $result = eval "require '$fn'";
        if ($result ne 1) {
            printf STDERR "%s:  BUILD_ERROR while processing definition file '%s' for command '%s'\n", $p, $fn, $cmd;
            return 1;
        }
    }

    return 0;   #success
}

########################## MAKEDRV COMMAND PROCESSORS ##########################

sub cmd_generic
{
    local ($command_name) = @_;

    #if the command name is of the form <cmd>.<target>:
    local (@tmp) = split('\.', $command_name);
    if ($#tmp == 1) {
        ($cmd,$target) = (@tmp);
    } else {
        ($cmd,$target) = ($command_name,$command_name) 
    }

#printf STDERR "cmd='%s' target='%s';\n", $cmd, $target;

    local(@LISTS) = ("$cmd.$FORTE_PORT", "$cmd.cmn");

    return &do_it($cmd, "$MAKECMD $EFLAG $KFLAG $target $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
}

sub cmd_cvsupdate
# NOTE:  this command requires that you pass it the name of a bdb.
{
    local ($command_name) = @_;
    my(@alldirs, $ss, %uniqsrv, $cmd, $revarg);
    my($nerrs) = 0;
    my($CVS_BRANCH_NAME) = $ENV{'CVS_BRANCH_NAME'};
    my($CVS_SRCROOT_PREFIX) = $ENV{'CVS_SRCROOT_PREFIX'};
    my($CVS_CO_ROOT) = $ENV{'CVS_CO_ROOT'};
    my($CVS_OPTS) = (defined($ENV{'CVS_OPTS'})? $ENV{'CVS_OPTS'} : "-q -z6");

    if ($#BDB_FILELIST < 0) {
        printf STDERR "%s:  BUILD_ERROR: %s requires an explicit -b <bdblist> argument\n", $p, $command_name;
        ++$nerrs;
    }

    if (!defined($CVS_BRANCH_NAME)) {
        printf STDERR "%s:  BUILD_ERROR: %s: env. var. CVS_BRANCH_NAME is undefined.\n", $p, $command_name;
        printf STDERR "\t  HINT: set CVS_BRANCH_NAME to 'trunk' or 'main' for main trunk.\n";
        ++$nerrs;
    }

    if ( (!defined($CVS_CO_ROOT)) || ($CVS_CO_ROOT eq "") ) {
      $CVS_CO_ROOT = $SRCROOT;
    }

    if ( (!defined($CVS_SRCROOT_PREFIX)) || ($CVS_SRCROOT_PREFIX eq "") ) {
        $CVS_SRCROOT_PREFIX = "";
    } else {
        $CVS_SRCROOT_PREFIX = $CVS_SRCROOT_PREFIX . "/";
    }
    
    return 1 if ($nerrs > 0);   #FAILED

    if ($CVS_BRANCH_NAME =~ /^(main|trunk)$/i) {
        $revarg = "";
    } else {
        $revarg = "-r $CVS_BRANCH_NAME";
    }

    @svc = @SVC_IN_SERVICES;    #normally, svc eliminates non-existant services.
    @alldirs = &select_directories(0, "");

    #reduce directory list to list of top-level directories:
    for $ss (@alldirs) {
        $ss =~ s/\/.*//;
        $ss = $CVS_SRCROOT_PREFIX . $ss;
        $uniqsrv{$ss}++
    }

#printf "command=%s dir list is (%s)\n", $command_name, join(",", @alldirs);
#printf "uniqsrv=(%s)\n", join(",", keys %uniqsrv);

    #NOTE:  we use checkout because it will also create or update.
    #NOTE:  we use -A to remove sticky tags for tools.  this is not strictly correct
    #       for release builds, but the alternative is tools might not get updated,
    #       which can break the build.  RT 5/19/04
    $cmd = sprintf("cd %s; cvs %s -f -r checkout -A %s %s", $CVS_CO_ROOT, $CVS_OPTS, $revarg, join(" ", sort keys %uniqsrv));

    #NOTE:  cvs returns non-zero when it finds CONFLICTS during a merge.
    my($ret) = &os::run_cmd($cmd, 1);   #show the command

#printf "cmd='%s' returned %d\n", $cmd, $ret;
    if ($ret != 0) {
        printf STDERR "%s:  BUILD_ERROR: %s completed with errors - check for merge conflicts.\n", $p, $command_name;
    }

    return $ret;
}

sub help_mmf
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command runs mmfdrv to install files for directories listed in
mmf.<port> and mmf.cmn.

!
}

sub help_ant
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command runs '$cmd' in each directory listed in $cmd.cmn.

!
}

sub help_printmap
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command creates tool information database used by 'wheresrc' to locate
the source associated with a tool.

!
}

sub help_bdb
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command runs mmfdrv for all directories under \$SRCROOT/bb/src
to install bdb files into \$SRCROOT/bdb.

!
}

##########################################################################

sub cmd_bdb
    # Run mmfdrv -r in $SRCROOT/bb/src
    # We do that instead of relying on bdb/bdb.cmn, because we can't trust that
    # bdb/bdb.cmn has been created yet.  bdb/bdb.cmn is still kept around
    # for the printmap.
{
    local ($command_name) = @_;

    if (!defined($ENV{'TARGET_OS_LIST'})) {
        chop($TARGET_OS_LIST = `$BLDHOSTCMD -a -psuedo -port -comma`);
        $ENV{'TARGET_OS_LIST'} = $TARGET_OS_LIST;
    }
    if ($CWD_FLAG) {
        return &os::RunSkel("$MMFCMD");
    }

    if (&os::chdir("$SRCROOT")) {
        print STDERR "BUILD_ERROR: Failed to cd into $SRCROOT/bb/src: $!\n";
        return 1;
    }
    my($ret);
    &os::RunSkel("$MMFCMD -r $EXTRA_MAKE_ARGS bb/src");
    $ret = $?;

    return $ret;
}

sub cmd_makemf
{
    local ($command_name) = @_;

    local(@LISTS) = "$command_name.$FORTE_PORT";
    push(@LISTS, "$command_name.cmn");
    
    return &do_it($command_name, "makemf -f make.mmf -o Makefile $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
}

sub cmd_mmf
{
    local ($command_name) = @_;

    if (!defined($ENV{'TARGET_OS_LIST'})) {
        chop($TARGET_OS_LIST = `$BLDHOSTCMD -a -psuedo -port -comma`);
        $ENV{'TARGET_OS_LIST'} = $TARGET_OS_LIST;
    }
    local(@LISTS) = "$command_name.$FORTE_PORT";
    push(@LISTS, "$command_name.cmn");
    
    return &do_it($command_name, "$MMFCMD $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
}

sub cmd_ant
{
    local ($command_name) = @_;

    push(@LISTS, "$command_name.cmn");
    
    return &do_it($command_name, "ant", "1", 1, @LISTS);
}

sub cmd_printmap
{
    local ($command_name) = @_;

    if (!defined($ENV{'TARGET_OS_LIST'})) {
        chop($TARGET_OS_LIST = `$BLDHOSTCMD -a -psuedo -port -comma`);
        $ENV{'TARGET_OS_LIST'} = $TARGET_OS_LIST;
    }
    local(@LISTS) = "mmf.$FORTE_PORT";
    push(@LISTS, "mmf.cmn", "bdb.cmn");
    return &do_it($command_name, "$MMFCMD -t printmap $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
}

############################## MAKEDRV SUBROUTNES ##############################

sub set_service_lists
#returns 0 if no errors.
{
    local($file) = "";
    local($svctext) = "";

    @svc = ();          #RESULT
    @SVC_TO_BUILD = (); #RESULTS

    if (-r ($file = &path::mkpathname($SRCROOT, "bdb", "services"))) {
        ;
    } else {
        return 1;
    }

    if (&os'read_file2str(*svctext, $file) != 0) {
        printf "BUILD_ERROR: %s: failed to read service list from %s\n", $p, $file;
        return 1;
    }

    @SVC_IN_SERVICES = split(' ', $svctext);

    local(@srcdirs) = ();
    &path::ls(*srcdirs, $SRCROOT);      #returns empty list on failure.

    @SVC_IN_SRCROOT = &list::AND(*SVC_IN_SERVICES, *srcdirs);

    local(@tmp) = &list::OR(*NOSVC, *DOSVC);
    @NO_SUCH_SERVICES = &list::MINUS(*tmp, *SVC_IN_SERVICES);
    if ($#NO_SUCH_SERVICES >= 0) {
        printf "BUILD_ERROR: %s: no such service(s):  %s\n", $p, join(':', @NO_SUCH_SERVICES);
        return 1;
    }

    #
    # SVC_TO_BUILD = {SVC_IN_SRCROOT AND DOSVC} - NOSVC
    #
    if ($#DOSVC >= 0) {
        @SVC_TO_BUILD = &list::AND(*SVC_IN_SRCROOT, *DOSVC);
    } else {
        ### build ALL services we have if none selected:
        @SVC_TO_BUILD = &list::AND(*SVC_IN_SRCROOT, *SVC_IN_SRCROOT);
    }

    ### subtract off NOSVC if any specified:
    @SVC_TO_BUILD = &list::MINUS(*SVC_TO_BUILD, *NOSVC);

    @svc = @SVC_TO_BUILD;       #old global name for SVC_TO_BUILD
#printf "svc=(%s)\n", join(",", @svc);
    return 0;
}

sub select_directories
#note - added BDB_LIBPATH mods, 8/27/97.  (russt)
{
    local($sort, @lists) = @_;
    local(*LIST, $list, *dirs, $re);
    local ($bdbfile);
    local (%BDB_FOUND) = ();

    if ($CWD_FLAG) {
        return ($CURRENT_SRC_DIR);
    }

    #if we had a -bdb <file_list> arg, then use instead of standard:
    @lists = @BDB_FILELIST if ($#BDB_FILELIST >= 0);

    foreach $BDB (@BDB_LIBPATH) {
        foreach $list (@lists) {
            next if (defined($BDB_FOUND{$list}));
            $bdbfile = "$BDB/$list";
            next if (! -e $bdbfile);

            if (!open(LIST, $bdbfile)) {
                print "$p:  BUILD_ERROR: can't open bdb file '$bdbfile' ($!)\n";
                return 1;
            }

            printf "%s:  reading bdb file %s...\n", $p, $bdbfile unless ($QUIET);
            push(@dirs, <LIST>);        #READ IN THE ENTIRE FILE

            #mark the file as found:
            ++$BDB_FOUND{$list};
            close(LIST);
        }
    }

#printf "T1 dirs=(%s)\n", join(',', @dirs);

    #print warnings for all bdb files not found:
    foreach $list (@lists) {
        if (!defined($BDB_FOUND{$list})) {
            print "$p:  BUILD_WARNING: bdb file $list not found in $BDB_LIBPATH\n";
        }
    }

    if ($PruneDir ne "") {
        @dirs = grep(! /$PruneDir/, @dirs);
    }

#printf "T2 dirs=(%s)\n", join(',', @dirs);
#printf "T2 dirs=(%s) svc=(%s)\n", join(',', @dirs), join(',', @svc);

    $re = join("|", @svc);
    @dirs = grep(m"^($re)/"o, @dirs);
    foreach (@dirs) {
        chop;
        if (m"^ds/src/xm/(.*)") {
            foreach $winsys (@WINBLD) {
                $dirs{"ds/src/$winsys/$1"} = 1;
            }
        } else {
            $dirs{$_} = 1;
        }
    }

#printf "T3 dirs=(%s)\n", join(',', @dirs);

    if ($sort eq "1") {
        return sort keys %dirs;
    } else {
        return @dirs;
    }
}

sub do_it
{
    local($op, $command, $sort, $print_header, @LISTS) = @_;
    local(@alldirs) = &select_directories($sort, @LISTS);
    local(@dirs);
    local($dirCount, $dirsPerProc);
    local($ret, $childLog);
    local($SYSCMD);
    local ($errs) = 0;

#printf "doit: T0 op='%s'\n", $op;

    if ($#alldirs < 0) {
        print STDERR "$p:  BUILD_WARNING: nothing to build for command $op for service list.\n";
        return 0;
    }
    &starting($op);

    if ($sort && $processorCount > 1) {
        # If we are allowed to sort the list, then there are no
        # intradependencies within the list; consequently, we can just
        # break up the list into chunks and hand each processor a
        # single chunk of directories to go through.
        
        # evenly distribute the number of directories over all the processors
        $dirCount = scalar(@alldirs);
        $dirsPerProc = int($dirCount / $processorCount) + 1;
        print "dirCount = $dirCount  processorCount = $processorCount  dirsPerProc = $dirsPerProc\n" if ($debug);
        while (@alldirs) {
            @dirs = splice(@alldirs, 0, $dirsPerProc);
            print "\ndirs = @dirs\n" if ($debug);

            if ($pid = fork) {
                # I am the parent.  I made a child at $pid
                print "created child process $pid\n" unless $QUIET;
                $childPidList{$pid} = 1;
            } elsif (defined $pid) {
                # I am the child.  My pid is $$
                undef %childPidList;

                # Redirect stdout & stderr to our designated log file.
                $childLog = "$LOG_DIR/makedrv.$$.log";
                open(REAL_STDOUT, ">&STDOUT");
                open(REAL_STDERR, ">&STDERR");
                if (!open(STDOUT, ">>$childLog")) {
                    print STDERR "BUILD_ERROR: failed to redirect stdout to '$childLog': $!\n";
                } else {
                    if (!open(STDERR, ">&STDOUT")) {
                        print STDERR ("Unable to switch STDERR to STDOUT\n");
                    }
                }

                # Now go through directories that I've been assigned and
                # execute the command
                foreach $dir (@dirs) {
                    if (! &os::chdir("$SRCROOT/$dir")) {
                        if ($print_header) {
                            print "======================= $dir\n" unless $QUIET;
                        } else {
                            print "$dir\n" unless $QUIET;
                        }
                        if ($op eq "printmap") {
                            print "SRCDIR=$dir\n";
                        }

                        $SYSCMD = "$MAKE_PREFIX$command";
                        print "$SYSCMD\n" if (!$QUIET && $print_header);
                        if ($SYSCMD =~ /^mmfdrv /) {
                            # For commands that are prlskel scripts.
                            $ret = &os::RunSkel($SYSCMD);
                        } else {
                            $ret = &os'run_cmd($SYSCMD, 0, $SHOWRET);
                        }
                        if ($ret ne 0) {
                            print "$p: BUILD_ERROR: '$SYSCMD' ($op) failed in $dir\n";
                            $errs += $ret;
                        }
                    } else {
                        print "$p: BUILD_ERROR: cannot find \"$SRCROOT/$dir\", skipping...\n";
                    }
                }
                exit $errs;
            } else {
                die "$p: BUILD_ERROR: tried forking and got a pid of $pid\n";
            }
        }
        # Now that we've forked everything off, we need to wait for
        # them to finish.

        sleep 1;
        print "Waiting for child processes to do $op\n" unless $QUIET;
        local($childPid);
        do {
            $childPid = wait;
            # $childPid has finished.  Now cat his log.
            if ($debug) {
                $date = &sp'GetDateStr;
                print "MARK $date: child $childPid just finished\n";
            }
            # need to remove this child from the childPidList
            $childPidList{$childPid} = 0;
            $childLog = "$LOG_DIR/makedrv.$childPid.log";
            if ($childPid > 0 && -r $childLog) {
                local($output) = "";
                &os'read_file2str(*output, $childLog);
                print $output;
                &os'rmFile($childLog);
            }
        } while ($childPid > 0);
    } else {
#print "doit: T1\n";
        # order is important, so we must do all of them in this order,
        # by using only one processor
        foreach $dir (@alldirs) {
            if (! &os::chdir("$SRCROOT/$dir")) {
                if ($print_header) {
                    print "======================= $dir\n" unless $QUIET;
                } else {
                    print "$dir\n" unless $QUIET;
                }
                if ($op eq "printmap" || $op eq "wfprintmap" || $op eq "webprintmap") {
                    print "SRCDIR=$dir\n";
                }
                $SYSCMD = "$MAKE_PREFIX$command";
                print "$SYSCMD\n" if (!$QUIET && $print_header);
                if ($SYSCMD =~ /^mmfdrv /) {
                    # For commands that are prlskel scripts.
                    $ret = &os::RunSkel($SYSCMD);
                } else {
                    $ret = &os'run_cmd($SYSCMD, 0, $SHOWRET);
                }
                if ($ret != 0) {
                    $errs += $ret;
                    print "$p: BUILD_ERROR: '$SYSCMD' ($op) failed in $dir\n";
                    if ($ret & 0xff) {
                        sleep 1;
                    }
                }
            } else {
                print "$p: BUILD_ERROR: cannot find \"$SRCROOT/$dir\", skipping...\n";
            }
        }
    }
#print "doit: T9\n";
    &finished($op);

    return $errs;
}

sub starting
{
    return if $QUIET;
    local($command) = @_;
    local($date) = &sp'GetDateStr;

    print <<"!";
================================================================
Starting "$command" for path $SRCROOT
on $FORTE_PORT on $date
MARK $date: Starting $command
================================================================
!
}

sub finished
{
    return if $QUIET;
    local($command) = @_;
    local($date) = &sp'GetDateStr;

    print <<"!";
================================================================
Finished "$command" for path $SRCROOT
on $FORTE_PORT on $date
MARK $date: Finished $command
================================================================
!
}

sub error
{
    local($msg) = @_;
    print "$p:  BUILD_ERROR:  $msg\n";
}

sub init
{
    @CMD = ();
    @DOSVC = ();
    @NOSVC = ();
    @BDB_FILELIST = ();
    
    $TOOLROOT   = $ENV{'TOOLROOT'};
    $SRCROOT    = $ENV{'SRCROOT'};
    $PRODUCT    = $ENV{'PRODUCT'};
    $RELEASE_ROOT = $ENV{'RELEASE_ROOT'};
    $LOGNAME       = $ENV{'LOGNAME'};
    $FORTE_PORT = $ENV{'FORTE_PORT'};
    $LOG_DIR    = $ENV{'LOG_DIR'} || "/tmp";
    $BDB_LIBPATH    = $ENV{'BDB_LIBPATH'} || "$SRCROOT/bdb;";
    @BDB_LIBPATH    = split(';', $BDB_LIBPATH);

    $CWD_FLAG   = 0;    #build current working dir only
    $EFLAG      = "-e";
    $KFLAG      = "";
    $MFLAG      = "off";
    $BUILD_MASTER   = 0;
    $EXTRA_MAKE_ARGS = "";
    @BDB_FILELIST = ();
    $MAKE_PREFIX = "";
    $MMFCMD     = "mmfdrv -q -all -rc mmfdrv.rc -glean install.map PERL4_CHECK=0";

    $BLDHOSTCMD = "NO_BLDHOST_COMMAND";
    $BLDHOSTCMD = "bldhost" if ($OS == $UNIX);
    $BLDHOSTCMD = "sh bldhost" if ($OS == $NT);

    $debug      = 0;
    $help       = 0;
    $SHOWRET    = 0;    #don't show return codes from &os'run_cmd
    $QUIET      = 0;
    $AUTO       = 0;
    $|          = 1;
    # If PruneDir is a nonempty string, then apply it to every directory read
    # in from the bdb's, and if it matches, then ignore that directory.
    $PruneDir = "";
    # default to using just one processor
    $processorCount = 1;

    # List of all children, so that we may kill them when we exit.  If
    # their value is true, then we kill them.
    $childPidList{$$} = 0;

    # Call cleanup when we get these signals.
    # For instance, cleanup will go through childPidList and kill all
    # orphaned children.
    if ($OS == $UNIX) {
        $SIG{'INT'} = 'sig_handler';
        $SIG{'KILL'} = 'sig_handler';
        $SIG{'QUIT'} = 'sig_handler';
        $SIG{'HUP'} = 'sig_handler';
        $SIG{'TERM'} = 'sig_handler';

        $MAKECMD = "make";
        $MAKER   = "makemake.gnu";
        &init_unix_processors;
    } elsif ($OS == $NT) {
        $MAKECMD = "make";
        $MAKER   = "makemake.gnu";
        &init_nt_processors;
    }
}

sub init_nt_processors
#set up global command processor table for nt version
{
    %CMD_PROCESSOR = (
        'ant', 'cmd_ant',
        'mmf', 'cmd_mmf',
        'makemf', 'cmd_makemf',
        'printmap', 'cmd_printmap',
        'bdb', 'cmd_bdb',
        'cvsupdate', 'cmd_cvsupdate',
    );
}

sub init_unix_processors
#set up global command processor table for unix version
{
    %CMD_PROCESSOR = (
        'ant', 'cmd_ant',
        'mmf', 'cmd_mmf',
        'makemf', 'cmd_makemf',
        'printmap', 'cmd_printmap',
        'bdb', 'cmd_bdb',
        'cvsupdate', 'cmd_cvsupdate',
    );
}

sub check_env
#return 1 if okay, 0 to abort.
{
    printf "%s:  BDB_LIBPATH=(%s)\n", $p, join(';', @BDB_LIBPATH) unless ($QUIET);
    return 1;
}

############################### USAGE SUBROUTNES ###############################

sub usage
{
    local($status) = @_;
    local(@cmds)  = sort keys %CMD_PROCESSOR;
    local($ii);

    #only print 6 commands per line:
    for ($ii = 6; $ii <= $#cmds; $ii+=6) {
        $cmds[$ii] .= "\n   ";
    }

    print <<"!";
Usage: $p [-help] [-c commands] [-auto] [-quiet] [-debug] [-norc]
          [-k] [-m] [-t] [-not] [-w] [-notoolgen] [-j njobs] [-b bdbs] [-C]
          [-s service[:service]...] [-S service[:service]...]
          [-d dir[:dir]...] [-D dir[:dir]...]
          -master -c commands [var=value...]

Options:
 -h[elp]      Display this usage message. Display command(s) information 
              if command(s) is specified.
 -auto        Don't require any user input.
 -q[uiet]     Be less verbose.
 -debug       Display debug messages.

 -norc        Do not source bdb/<cmd>.rc files.

 -k           Invokes make with the -k flag.
 -j njobs     allow make to run <njobs> in parallel (unix only).

 -b bdbs      use colon-delimited <bdbs> list instead of standard bdbs
              implied by command names.
 -C           Build the current directory only.
 -s services  Do only named services. E.g., -s tl:t3
 -S services  Do all but named services.
 -d dirs      Build only named directories (as listed in bdb's for command).
 -D dirs      Build all but named directories.
 -c commands  execute colon-delimited list of command directives. If of the form
              <command>.<target>, will look for bdbs named after <command>,
              and will attempt to build <target>.  THIS ARGUMENT IS REQUIRED.
 var=value... define makefile <var> to have <value>.

ENVIRONMENT:
 BDB_LIBPATH  format:  dir1;dir2; ...
              if defined, will search for bdb files in dir1,
              then dir2, etc.

<cmd>.rc      If this file is present in the BDB_LIBPATH, then
              evaluate (require) it prior to processing <cmd>.
              Use '-norc' option to avoid evaluating this file.

NOTES:
 The commands for this platform are:
    @cmds

 Non-standard commands will build if there is a corresponding
 bdb entry, and a make target of the same name, or the make target
 is specified via the <command>.<target> syntax.  For example:
     makedrv -c java.lib
 
 will look for the bdb files (tst bdbs skipped if -not option):
     java.cmn java.\$FORTE_PORT tstjava.\$FORTE_PORT tstjava.cmn
 
 and will attempt to build the makefile target "lib".
 
 An alternate way to specify the same actions:
     makedrv -c lib -b java.cmn:java.\$FORTE_PORT:tstjava.\$FORTE_PORT:tstjava.cmn

 I.e., use the -b option to specify the bdb files explicitly.
 This will overide any internal defaults.

 If neither -s nor -S are specified, then all services in the path
 are built.
 
EXAMPLES:
 Build libraries, executable, & shared libraries in the os service:

     % makedrv -not -c lib:exe:shlib -s os
 
 Same command, but use custom bdb files:

     % setenv BDB_LIBPATH "\$SRCROOT/mybdbs"
     % makedrv -not -c lib:exe:shlib -s os

 Build lib makefile target using user-specified bdb in src & tst:

     % makedrv -b myjava -c lib -s fo

 Run mmf command with \$FOO defined in the environment:

      % cat > \$SRCROOT/bdb/mmf.rc
      \$ENV{'FOO'} = 'hello';
      1;
      ^D

      % makedrv -c mmf

 Same mmf command, but without processing mmf.rc file:

      % makedrv -norc -c mmf

!
    return($status);
}

sub get_current_src_dir
#pull current path dir from environment & SRCROOT setting.
#   e.g., /toolt3/d/rt1/tl/src/cmn/gnumake --> tl/src/cmn/gnumake
#return dir or "" if error.
{
    local($pwd) = &path'pwd;
    local($srcroot) = $SRCROOT;

#printf "pwd='%s' srcroot='%s'\n", $pwd, $srcroot;

    if ($OS == $NT) {
        #down-case names on nt:
        $pwd =~ tr/A-Z/a-z/;
        $srcroot =~ tr/A-Z/a-z/;
    } elsif ($OS == $UNIX && $pwd =~ "^/forte11/d/") {
        #e.g., /forte11/d/ui --> /forte1/d/ui
        $pwd =~ s./forte11/./forte1/.;
    }

    $pwd =~ s.$srcroot/.#.;

    #split rec, in case we have /net, or other garbage in pwd
    local (@rec) = split('#', $pwd);

#printf "pwd='%s' rec=(%s) srcroot='%s'\n", $pwd, join(',', @rec), $srcroot;
    
    if ($#rec < 1) {
        #substitution failed
        return "";
    } else {
        return $rec[1];
    }
}

sub parse_args
{
    local ($badargs) = 0;

    $DIRLIST_OPT = 0;
    $NODIRLIST_OPT = 0;
    $NORC = 0;

    while ($arg = shift @ARGV) {
        if ($arg eq "-h" || $arg eq "-help") {
            $help = 1;
        } elsif ($arg eq "-norc") {
            $KFLAG = "-k";
            $NORC = 1;
        } elsif ($arg eq "-k") {
            $KFLAG = "-k";
        } elsif ($arg eq "-C") {
            $CWD_FLAG = 1;
        } elsif ($arg eq "-m") {
            $EFLAG = "";
            $MFLAG = "on";
        } elsif ($arg eq "-auto") {
            $AUTO = 1;
        } elsif ($arg eq "-debug") {
            $debug = 1;
            $SHOWRET = 1;   #show returns as well.
        } elsif ($arg eq "-q" || $arg eq "-quiet") {
            $QUIET = 1;
        } elsif ($arg =~ /^-(c|s|S|j|b|d|D)(.*)$/) {
            $x = length($2) ? $2 : (shift(@ARGV) || ($badargs = 1));
#printf "x='%s'\n", $x;
            $badargs = 1 if ($x =~ /^-/);
            if ($badargs) {
                print "$p:  BUILD_ERROR: bad args\n";
                return &usage(1);
            }
            if ($1 eq 'c') {
                push(@CMD, split(':', $x));
                @CMD = grep ($_ ne "", @CMD);   #kill null ops.
            } elsif ($1 eq 's') {
                push(@DOSVC, split(':', $x));
                @DOSVC = grep ($_ ne "", @DOSVC);
            } elsif ($1 eq 'S') {
                push(@NOSVC, split(':', $x));
                @NOSVC = grep ($_ ne "", @NOSVC);
            } elsif ($1 eq 'd') {
                $DIRLIST_OPT = 1;
                push(@ARGDIRS, split(':', $x));
#printf "ARGDIRS=(%s)\n", join(',', @ARGDIRS);
            } elsif ($1 eq 'D') {
                $NODIRLIST_OPT = 1;
                push(@ARGDIRS, split(':', $x));
            } elsif ($1 eq 'b') {
                push(@BDB_FILELIST, split(':', $x));
                @BDB_FILELIST = grep ($_ ne "", @BDB_FILELIST);
            } elsif ($1 eq 'j') {
                if ($OS != $UNIX) {
                    print "$p:  -j option not supported on this platform\n";
                    return 1;
                }
                $processorCount = $x;
                if ($processorCount <= 0) {
                    print "$p:  The processor count (-j) must be 1 or more.\n";
                    return 1;
                }
            }
        } else {
            if ($arg =~ /=/) {
                # It must be an env variable definition
                # local($varName, $value) = ($arg =~ /(\S+)\s*=\s*(.*)/);
                # $ENV{$varName} = $value;
                $EXTRA_MAKE_ARGS = "$EXTRA_MAKE_ARGS \"$arg\"";
            } else {
                print "$p:  BUILD_ERROR: bad arg, $arg\n";
                return &usage(1);;
            }
        }
    }

    if ($help && scalar(@CMD) == 0) {
        &usage(2);
    }

    if (! defined($ENV{'SRCROOT'} || $SRCROOT eq "")) {
        print "$p:  BUILD_ERROR: SRCROOT not set, You must run usePath.\n";
        return(1);
    }

    if (! $FORTE_PORT) {
        print "$p:  BUILD_ERROR: FORTE_PORT=\"$FORTE_PORT\" not set correctly, exiting...\n";
        return(1);
    }

    if (! @CMD) {
        print "$p:  BUILD_ERROR: must give at lease one -c command.\n";
        return(1);
    }

    if ($DIRLIST_OPT != 0 &&  $NODIRLIST_OPT != 0) {
        print "$p:  BUILD_ERROR: -d and -D are mutually exclusive.\n";
        return(1);
    }

    if (@DOSVC && @NOSVC) {
        print "$p:  BUILD_ERROR: -s and -S are mutually exclusive.\n";
        return(1);
    }

    if ($CWD_FLAG) {
        if (@DOSVC || @NOSVC || @BDB_FILELIST) {
            print "$p: BUILD_ERROR: -C option incompatible with -s, -b, or -S options\n";
            return 1;
        }

        $CURRENT_SRC_DIR = &get_current_src_dir;
        if ($CURRENT_SRC_DIR eq "") {
            print "$p:  BUILD_ERROR: could not derive service dir for -C, are you within SRCROOT?\n";
            return 1;
        } 
    }

    if ( defined($ENV{'MAKEDRV_MAKE_COMMAND'}) ) {
        $MAKECMD = $ENV{'MAKEDRV_MAKE_COMMAND'};
        printf "%s:  using make command MAKEDRV_MAKE_COMMAND='%s'\n", $p, $MAKECMD if ($debug);
    }

    return(0);
}

sub squawk_off
{
    if (1 > 2) {
        *sig_handler = *sig_handler;
    }
}

package main;

sub sig_handler
#signal handlers like to be in main package
{
    local($sig) = @_;
    local($dosleep);
    
    print "\n$'p [package makedrv.pl]: ($$) received a SIG$sig\n";
    if ($sig eq "HUP") {
        print "Ignoring SIGHUP.\n";
        return;
    }
    $dosleep = 0;
    foreach $childPid (keys %makedrv'childPidList) {
        if ($makedrv'childPidList{$childPid}) {
            print "sending a kill 15 to pid $childPid\n";
            kill 15, $childPid;
            $dosleep = 1;
        } else {
            print "did not kill pid $childPid.\n" if ($makedrv'debug);
        }
    }
    sleep 1 if ($dosleep);
    exit 0;
}

package makedrv;

1;
