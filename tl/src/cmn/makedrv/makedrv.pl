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

    push(@LISTS, "tst$cmd.$FORTE_PORT", "tst$cmd.cmn")
        if ($DOTST);

    return &do_it($cmd, "$MAKECMD $EFLAG $KFLAG $target $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
}

sub cmd_makemakedepend
{
    local($errs) = 0;
    $errs += &cmd_makemake("makemake");
    $errs += &cmd_makedepend("makedepend");
    return($errs);
}

sub cmd_makemake
{
    local ($command_name) = @_;
    local (@LISTS);

    if ($JAVA_ONLY) {
        @LISTS = ("java.cmn", "javajar.cmn");
    } else {
        if ($BUILD_MASTER) {
            @LISTS = "makemake.master";
        } else {
            @LISTS = "ccgs.$FORTE_PORT";
            push(@LISTS, "scope.cmn", "lib.$FORTE_PORT", "shlib.$FORTE_PORT", 
                      "exe.$FORTE_PORT", "pexe.$FORTE_PORT", "tool.cmn");
            push(@LISTS, "tstlib.$FORTE_PORT", "tstexe.$FORTE_PORT") if $DOTST;
        }
    }
    return &do_it($command_name, $MAKER, "1", 0, @LISTS);
}

sub cmd_makedepend
{
    local ($command_name) = @_;
    local (@LISTS);

    if ($BUILD_MASTER) {
        @LISTS = "ccgs.master";
    } else {
        @LISTS = "ccgs.$FORTE_PORT";
    }
    push(@LISTS, "lib.$FORTE_PORT", "shlib.$FORTE_PORT", "exe.$FORTE_PORT", "pexe.$FORTE_PORT");
    push(@LISTS, "tstlib.$FORTE_PORT", "tstexe.$FORTE_PORT") if $DOTST;
    push(@LISTS, "scope.cmn");

    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name $EXTRA_MAKE_ARGS DEPENDFILE=SUPPRESS", "1", 1, @LISTS);
}

sub cmd_ccgs
{
    local ($command_name) = @_;
    local (@LISTS);

    if ($BUILD_MASTER) {
        @LISTS = "ccgs.master";
    } else {
        @LISTS = "ccgs.$FORTE_PORT";
#       push(@LISTS, "tst$command_name.cmn") if $DOTST;
    }
    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
}

sub cmd_scope
{
    local ($command_name) = @_;

    local(@LISTS) = "$command_name.cmn";
    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
}

sub cmd_reccgs
{
    local ($command_name) = @_;
    local (@LISTS);

    if ($BUILD_MASTER) {
        @LISTS = "ccgs.master";
    } else {
        @LISTS = "ccgs.$FORTE_PORT";
#       push(@LISTS, "tstccgs.cmn") if $DOTST;
    }
    return &do_it("ccgs", "$MAKECMD $EFLAG $KFLAG $command_name $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
}

sub cmd_tool
{
    local ($command_name) = @_;

    local(@LISTS) = "tool.cmn";
    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name DEPENDFILE=SUPPRESS $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
}

sub cmd_nodependfile
{
    local ($command_name) = @_;

    local(@LISTS) = "$command_name.cmn";
    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name DEPENDFILE=SUPPRESS $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
}

sub cmd_lib
{
    local ($command_name) = @_;

    local(@LISTS) = "lib.$FORTE_PORT";
    push(@LISTS, "tstlib.$FORTE_PORT") if $DOTST;
    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
}

sub cmd_cleanjava
{
    local ($command_name) = @_;

    &starting($command_name);
    #we don't care if this fails:
    &os'run_cmd("rm -rf $SRCROOT/obj/*", !$QUIET, $SHOWRET);    #don't show errors
    &os'run_cmd("rm -f $SRCROOT/lib/cmn/*.jar", !$QUIET, $SHOWRET);
    &finished($command_name);

    return 0;
}

sub cmd_idl2java
{
    local ($command_name) = @_;

    local(@LISTS) = "idl2java.cmn";

    &do_it($command_name, "$MAKECMD $EFLAG $KFLAG idl2java DEPENDFILE=SUPPRESS $EXTRA_MAKE_ARGS", "0", 1, @LISTS);

    ### this re-runs makemake for the idl dirs:
    return &do_it("Re-makemake $command_name", $MAKER, "1", 0, @LISTS);
}

sub cmd_java
{
    local ($command_name) = @_;

    local(@LISTS) = "java.cmn";
    if ($OS == $NT) {
        return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG all DEPENDFILE=SUPPRESS $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
    } else {
        return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG lib DEPENDFILE=SUPPRESS $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
    }
}

sub cmd_makemakejava
{
    local ($command_name) = @_;

    $JAVA_ONLY = 1;
    $ret = &cmd_makemake("makemake");
    $JAVA_ONLY = 0;
    return $ret;
}

sub cmd_makedependjava
{
    local ($command_name) = @_;
    my(@LISTS);
    @LISTS = ("java.cmn");
    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name DEPENDFILE=SUPPRESS $EXTRA_MAKE_ARGS", "1", 0, @LISTS);
}

sub cmd_makemakedependjava
{
    local($errs) = 0;
    $errs += &cmd_makemakejava("makemakejava");
    $errs += &cmd_makedependjava("makedependjava");
    return $errs;
}

sub cmd_makemaketool
{
    my($command_name) = @_;
    my(@LISTS);

    @LISTS = ("tool.cmn", "codegen.cmn");
    return &do_it($command_name, $MAKER, "1", 0, @LISTS);
}

sub cmd_cleanjavainstr
{
    local ($command_name) = @_;

    #we don't care if this fails:
    &os'run_cmd("rm -rf $SRCROOT/java_instr", !$QUIET, $SHOWRET);  #don't show errors;

    return 0;
}

sub cmd_javainstr
{
    local ($command_name) = @_;

    local(@LISTS) = ("genjava.cmn", "java.cmn");
    $ret = &do_it($command_name, "$MAKECMD $EFLAG $KFLAG javainstr DEPENDFILE=SUPPRESS $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
    return $ret;
}

sub cmd_jar
{
    local ($command_name) = @_;

    local(@LISTS) = ("javajar.cmn");
    $ret = &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name DEPENDFILE=SUPPRESS $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
    return $ret;
}

sub cmd_codegen
{
    local($command_name) = @_;

    # Make sure TOOL_LIB_PHASE isn't set.
    delete $ENV{"TOOL_LIB_PHASE"};
    local(@LISTS) = "codegen.cmn";
    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name DEPENDFILE=SUPPRESS $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
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
    $cmd = sprintf("cd %s; cvs -q -f -r checkout -A %s %s", $CVS_CO_ROOT, $revarg, join(" ", sort keys %uniqsrv));

    #NOTE:  cvs returns non-zero when it finds CONFLICTS during a merge.
    my($ret) = &os::run_cmd($cmd, 1);   #show the command

#printf "cmd='%s' returned %d\n", $cmd, $ret;
    if ($ret != 0) {
        printf STDERR "%s:  BUILD_ERROR: %s completed with errors - check for merge conflicts.\n", $p, $command_name;
    }

    return $ret;
}

sub help_makemake
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command creates makefiles for directories listed in:
bdb/ccgs.<port>, scope.cmn, lib.<port>, shlib.<port>, exe.<port>,
pexe.<port>, tool.cmn, tstlib.<port> and tstexe.<port>.
If '-master' is specified, bdb/makemake.master is used instead.

!
}

sub help_makedepend
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command creates dependency files for directories listed in:
bdb/lib.<port>, shlib.<port>, exe.<port>, pexe.<port>, tstlib.<port>
tstexe.<port> and scope.cmn.
If '-master' is specified, bdb/ccgs.master is included, otherwise
bdb/ccgs.<port> is included.

!
}

sub help_makemakedepend
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd is a shortcut for makemake:makedepend.

!
    &help_makemake("makemake");
    &help_makedepend("makedepend");
}

sub help_ccgs
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command builds target $cmd for directories listed in bdb/ccgs.<port>.
If '-master' is specified, the bdb file used is bdb/ccgs.master.

This command also classparses .cdf files to generate .ccg and .cdg files.

!
}

sub help_prelib
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command builds lib for a subset of directories (bdb/prelib.cmn) that
should be built first before we let other machines do their lib.

!
}

sub help_lib
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command builds target $cmd for directories listed in bdb/lib.<port>
and tstlib.<port>.

!
}

sub help_shlib
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command builds shared libraries for directories listed in bdb/shlib.<port>.

!
}

sub help_exe
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command builds executables for directories listed in bdb/exe.<port>
and tstexe.<port>

!
}

sub help_pexe
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command builds executables for directories listed in bdb/pexe.<port>,
tstexe.<port> and exe.<port>

!
}

sub help_cplib
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command copies
\$PATHREF/<service>/lib/<port>/*.a to \$SRCROOT/<service>/lib/<port>
\$PATHREF/<service>/obj/<port>/libqq* to \$SRCROOT/<service>/obj/<port>

Files that are checked out in \$SRCROOT are touched.

!
}

sub help_cpbin
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command copies executables and shared libraries from:
\$PATHREF/bin/<port> to \$SRCROOT/bin/<port>
\$PATHREF/lib/<port> to \$SRCROOT/lib/<port>

!
}

sub help_clean_all
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command removes objects, libraries, shared libraries and executables 
built in directories listed in bdb/lib.<port>, ccgs.<port>, shlib.<port>,
exe.<port>, pexe.<port>, tstlib.<port> and tstexe.<port>.

!
}

sub help_scope
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command scopeparses directories listed in bdb/scope.cmn.

!
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

sub help_makemakecmdhelp
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command runs mmfdrv -nomk to create makefile for directories listed
in mmf.<port> and mmf.cmn.

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

sub help_wfprintmap
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command is same as 'printmap' but it is used in conductor (workflow)
codeline.

!
    &help_printmap("printmap");
}

sub help_webprintmap
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command is same as 'printmap' but it is used in websdk codeline.

!
    &help_printmap("printmap");
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

sub help_vlib
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command runs mmfdrv for all directories under \$SRCROOT/vl/src.

!
}

sub help_reccgs
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command classparses .cdf files to create .cdg and .ccg files.

!
}

sub help_java
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
On NT, $cmd command builds target all for directories listed in
bdb/java.cmn. On other platforms, $cmd command builds target lib.

!
}

sub help_makemakejava
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command creates makefiles for directories listed in bdb/java.cmn

!
}

sub help_makedependjava
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command make .properties files.

!
}

sub help_makemakedependjava
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd is a shortcut for makemakejava:makedependjava

!
}

sub help_jar
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command builds .jar files from .class files.

!
}

sub help_cleanjava
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command removes \$SRCROOT/obj/com directory.

!
}

sub help_javainstr
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command instruments java source files to \$SRCROOT/java_instr
and builds them.

!
}

sub help_cleanjavainstr
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command removes \$SRCROOT/java_instr.

!
}

sub help_makemaketool
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command creates makefiles for TOOL directories listed in
bdb/tool.cmn and codegen.cmn.

!
}

sub help_tool
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command builds target $cmd for directories listed in 
bdb/tool.cmn.

!
}

sub help_nodependfile
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command builds target $cmd for directories listed in $cmd.cmn.

!
}

sub help_codegen
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd;
$cmd command takes TOOL code and codegenerated C++ for directories
listed in bdb/codegen.cmn.

!
}

sub help_cmdhelp
{
    local($cmd) = @_;

    print <<"!";
$p -c $cmd:
$cmd command creates html files that list the help messages of our tools.

!
}

##########################################################################

sub ServicesOfBdbFile
    # Returns a list of services from a file which has a bunch of path
    # relative directories in it.
{
    my($file) = @_;

    print "Scanning bdb file = $file\n" if ($debug);
    my(@dirs);
    @dirs = &sp::File2List($file);
    return map(&ServiceName($_), @dirs);
}

sub ServicesOfMetaBdbFile
{
    my($file) = @_;
    my($suite);
    my(@services);
    @services = ();
    foreach $suite (&sp::File2List($file)) {
        push(@services,
             &ServicesOfBdbFile(&path::mkpathname(&path::head($file), "$suite.reg")));
    }
    return @services;
}

sub ServiceName
    # Take a filename (presumably one from FullSourceFileName) and
    # figure out the initial directory (presumably which service it belongs to)
    #    svc1/src/cmn/testdir/foo.cc -> svc1
    #    svc1/src/cmn/testdir -> svc1
{
    local($dirfile) = @_;
    $dirfile =~ s|/.*$||;
    return $dirfile;
}

##########################################################################

sub cmd_prelib
    # prelib should be a subset of the lib directories.
    # It's for those directories that we should do before we let other
    # machines do their lib.
{
    local ($command_name) = @_;

    local(@LISTS) = ();
    push(@LISTS, "$command_name.cmn");
    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG lib $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
}

sub cmd_shlib
{
    local ($command_name) = @_;
    local ($errs) = 0;

    if ($FORTE_PORT ne "sequent") {
        local(@LISTS) = "$command_name.$FORTE_PORT";
        # pass a 0 for the sort flag as these libs must be
        # built in order.
        $errs += &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name $EXTRA_MAKE_ARGS", "0", 1, @LISTS);
        $errs += &do_special_shlib;
    } else {
        print "Skipping $command_name build operation on $FORTE_PORT." unless $QUIET;
    }

    return $errs;
}

sub cmd_exe
{
    local ($command_name) = @_;
    local ($errs) = 0;

    local(@LISTS) = "$command_name.$FORTE_PORT";
    push(@LISTS, "tstexe.$FORTE_PORT") if $DOTST;
    if ($OS == $NT) {
#printf STDERR "calling doit with exes\n";
        $errs += &do_it($command_name, "$MAKECMD $EFLAG $KFLAG exes $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
        $errs += &do_special_exe_nt;
    } else {
#printf STDERR "calling doit with exe\n";
        $errs += &do_it($command_name, "$MAKECMD $EFLAG $KFLAG exe $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
        $errs += &do_special_exe_unix;
    }

    return $errs;
}

sub cmd_pexe
    #
    # The pexe command should only be used for nightBuilds.  The command
    # forces the build of shipped exes and proto-exes.  The execs we
    # ship only have ORACLE linked-in, customers must link the proto-exes
    # with their SYBASE libraries on-site.
    #
{
    local ($command_name) = @_;
    local ($errs) = 0;

    local(@LISTS) = "$command_name.$FORTE_PORT";
    push(@LISTS, "tstexe.$FORTE_PORT") if $DOTST;
    $errs += &do_it("exe", "$MAKECMD $EFLAG $KFLAG exe $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
    $errs += &do_it("exeobj", "$MAKECMD $EFLAG $KFLAG exeobj $EXTRA_MAKE_ARGS", "1", 1, @LISTS);

    @LISTS = "exe.$FORTE_PORT";
    push(@LISTS, "tstexe.$FORTE_PORT") if $DOTST;
    $errs += &do_it("exe", "$MAKECMD $EFLAG $KFLAG exe $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
    $errs += &do_special_exe_unix;

    return $errs;
}

sub cmd_clean
{
    local ($command_name) = @_;

    #on nt, clean_all target maps to "clean":
    return &cmd_clean_all("clean");
}

sub cmd_clean_all
{
    local ($command_name) = @_;

    local(@LISTS) = "lib.$FORTE_PORT";
    push(@LISTS, "ccgs.$FORTE_PORT");
    push(@LISTS, "shlib.$FORTE_PORT");
    push(@LISTS, "exe.$FORTE_PORT");
    push(@LISTS, "pexe.$FORTE_PORT");
    push(@LISTS, "tstlib.$FORTE_PORT") if $DOTST;
    push(@LISTS, "tstexe.$FORTE_PORT") if $DOTST;
    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name DEPENDFILE=SUPPRESS $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
}

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

sub cmd_vlib
{
    # Run mmfdrv -r in $SRCROOT/vl/src
    local ($command_name) = @_;

    if (!defined($ENV{'TARGET_OS_LIST'})) {
        chop($TARGET_OS_LIST = `$BLDHOSTCMD -a -psuedo -port -comma`);
        $ENV{'TARGET_OS_LIST'} = $TARGET_OS_LIST;
    }
    if (&os::chdir("$SRCROOT")) {
        print STDERR "BUILD_ERROR: Failed to cd into $SRCROOT: $!\n";
        return 1;
    }
    my($ret);
    &os::RunSkel("$MMFCMD -r $EXTRA_MAKE_ARGS vl/src");
    $ret = $?;

    return $ret;
}

sub cmd_cmdhelp
{
    local ($command_name) = @_;
    local (@LISTS) = "$command_name.$FORTE_PORT";

    push(@LISTS, "$command_name.cmn");
    return &do_it($command_name, "$MAKECMD $EFLAG $KFLAG $command_name $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
}

sub cmd_makemakecmdhelp
{
    local($command_name) = @_;
    local(@LISTS) = "cmdhelp.$FORTE_PORT";

    push(@LISTS, "cmdhelp.cmn");
    return &do_it($command_name, "$MMFCMD -nomk $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
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

sub cmd_wfprintmap
{
    local ($command_name) = @_;

    if (!defined($ENV{'TARGET_OS_LIST'})) {
        chop($TARGET_OS_LIST = `$BLDHOSTCMD -a -psuedo -port -comma`);
        $ENV{'TARGET_OS_LIST'} = $TARGET_OS_LIST;
    }
    local(@LISTS) = "wfmmf.$FORTE_PORT";
    push(@LISTS, "wfmmf.cmn");
    return &do_it($command_name, "$MMFCMD -t printmap $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
}

sub cmd_webprintmap
{
    local ($command_name) = @_;

    if (!defined($ENV{'TARGET_OS_LIST'})) {
        chop($TARGET_OS_LIST = `$BLDHOSTCMD -a -psuedo -port -comma`);
        $ENV{'TARGET_OS_LIST'} = $TARGET_OS_LIST;
    }
    local(@LISTS) = "webmmf.$FORTE_PORT";
    push(@LISTS, "webmmf.cmn");
    return &do_it($command_name, "$MMFCMD -t printmap $EXTRA_MAKE_ARGS", "1", 1, @LISTS);
}

# ADDED 03/01/93 to support the "cplib" command.
# Copies all $PATHREF/<SERVICE>/lib/<PORT>/*.a to
#   $PATHREF/<PATH>/<SERVICE>/lib/<PORT> and touches all files listed in
#   $PATHREF/<PATH>/changes.dat.
sub cmd_cplib
{
    local ($command_name) = @_;
    local ($errs) = 0;
    local(@stardota);
    local($svc, $dir);
    local(@libdirs, @objdirs);

    if ($PATHREF eq $SRCROOT) {
        printf "%s: WARNING:  PATHREF=SRCROOT, cplib operation not valid\n", $p;
        return 0;
    }

    # sequent doesn't have -p, -p on hp doesn't work
    local  ($CP_P) = ($FORTE_PORT =~ /^(sequent|hp9000)$/) ? "" : "-p";

    &starting($command_name);

    ### collect obj & dir names - warn about non-existent dirs.
    foreach $svc (@svc) {
        $dir = "$PATHREF/$svc/lib/$FORTE_PORT";
        if (-d "$dir") {
            push(@libdirs, "$svc/lib/$FORTE_PORT");
        }
    }

    if ($#libdirs < 0) {
        printf "%s: BUILD_WARNING: no lib directories found for service list in PATHREF (%s).\n", $p, $PATHREF;
        ++$errs;
    }

    ### at this point, we're down to the existing lib dirs, so
    ### copy these.  not an error if the dir is there but has no libs.

    foreach $dir (@libdirs) {

        print "======================= $dir\n" unless $QUIET;

        #### create local dir if doesn't exist:
        if (! -d "$SRCROOT/$dir") {
            if ($LINKROOT eq "") {
                &os'mkdir_p("$SRCROOT/$dir", 0775);
            } else {
                $errs += &os'mkdir_p("$LINKROOT/$dir", 0775);
                $errs += &os'symlink ("$LINKROOT/$dir", "$SRCROOT/$dir");
            }
        }

        ### read the PATHREF contents:
        if (!opendir(DOTA, "$PATHREF/$dir")) {
            printf STDERR "%s:  BUILD_ERROR: cannot read directory '%s'\n", $p, "$PATHREF/$dir";
            ++$errs;
            next;
        }

        @stardota = readdir(DOTA);
        closedir(DOTA);

        ### eliminate non-library files from listing:
        if ($FORTE_PORT eq "rs6000") {
            @stardota = grep($_ =~ /\.a$/ || $_ =~ /\.a\.exp$/, @stardota);
        } else {
            @stardota = grep($_ =~ /\.a$/, @stardota);
        }

#printf "stardota=(%s)\n", join(",", @stardota);

        #skip if no lib files...
        next if ($#stardota < 0);

        $errs += &os'run_cmd("cp $CP_P $PATHREF/$dir/*.a $SRCROOT/$dir", !$QUIET, $SHOWRET);

        if ($FORTE_PORT eq "rs6000") {
            $errs += &os'run_cmd("cp -p $PATHREF/$dir/*.a.exp $SRCROOT/$dir", !$QUIET, $SHOWRET);
        }

    }

    ### collect objdirs that exist in PATHREF
    foreach $svc (@svc) {
        $objdir = "$PATHREF/$svc/obj/$FORTE_PORT";
        if (-d "$objdir") {
            push(@objdirs, "$svc/obj/$FORTE_PORT");
        }
    }

    if ($#objdirs < 0) {
        printf "%s: BUILD_WARNING: no obj directories found for service list in PATHREF (%s).\n", $p, $PATHREF;
    }

    foreach $objdir (@objdirs) {
        print "======================= $objdir\n" unless $QUIET;
        if (! -d "$SRCROOT/$objdir") {
            if ($LINKROOT eq "") {
                $errs += &os'mkdir_p("$SRCROOT/$objdir", 0775);
            } else {
                $errs += &os'mkdir_p("$LINKROOT/$objdir", 0775);
                $errs += &os'symlink ("$LINKROOT/$objdir", "$SRCROOT/$objdir");
            }
        }
        local(*DIR, $arcdir, @archdirs);
        if (opendir(DIR, "$PATHREF/$objdir")) {
            @archdirs = readdir(DIR);
            closedir(DIR);
            foreach $arcdir (@archdirs) {
                if ($arcdir =~ /libqq*/) {
                    &os'run_cmd("rm -rf $SRCROOT/$objdir/$arcdir", !$QUIET, $SHOWRET);
                    $errs += &os'run_cmd("cp -r $CP_P $PATHREF/$objdir/$arcdir $SRCROOT/$objdir", !$QUIET, $SHOWRET);
                }
            }
        } else {
            print "WARNING: unable to process this directory.\n" unless $QUIET;
        }
    }

    local(*CHANGES, $changed_file, @changed_files);
    if (open(CHANGES, "$SRCROOT/changes.dat")) {
        @changed_files = <CHANGES>;
        close(CHANGES);
        chop(@changed_files);
        print "======================= touching checked out compiler source files\n" unless $QUIET;
        foreach $changed_file (grep(&is_ccfile($_), @changed_files)) {
            $errs += &os'touch("$SRCROOT/$changed_file");
        }
    }

    &finished($command_name);

    return $errs;
}

sub is_ccfile
#Usage:  is_ccfile($fn)
#true if <fn> is a file that we compile or pre-process.
#used by cplib to force our source to be newer then copied objects.
{
    local ($_) = @_;

    return (/\.cc$|\.h|\.c|\.cdf|\.cdg|\.msh/);
}

# ADDED 09/13/93 to support the "cpbin" command.
# Copies all executables and shared libraries from mainline to a path.
#
sub cmd_cpbin
{
    local ($command_name) = @_;
    local ($errs) = 0;

    # sequent doesn't have -p, -p on hp doesn't work
    local  ($CP_P) = ($FORTE_PORT =~ /^(sequent|hp9000)$/) ? "" : "-p";

    &starting($command_name);

    # Create the bin/PORT directory if it does not already exist.
    if (! -d "$SRCROOT/bin/$FORTE_PORT") {
        if ($LINKROOT eq "") {
            $errs += &os'mkdir_p("$SRCROOT/bin/$FORTE_PORT", 0775);
        } else {
            $errs += &os'mkdir_p("$LINKROOT/bin/$FORTE_PORT", 0775);
            $errs += &os'symlink ("$LINKROOT/bin/$FORTE_PORT", "$SRCROOT/bin/$FORTE_PORT");
        }
    }
    print "Copying executables from $PATHREF/bin/$FORTE_PORT to " .
        "$SRCROOT/bin/$FORTE_PORT\n" unless $QUIET;

    #get rid of these or there will be permission errors:
    unlink "$SRCROOT/bin/$FORTE_PORT/fscript";
    unlink "$SRCROOT/bin/$FORTE_PORT/escript";
    unlink "$SRCROOT/bin/$FORTE_PORT/tescript";
    unlink "$SRCROOT/bin/$FORTE_PORT/fcli";

    $errs += &os'run_cmd("cp -r $CP_P $PATHREF/bin/$FORTE_PORT/* $SRCROOT/bin/$FORTE_PORT", ! $QUIET, $SHOWRET);

    print "ln -s $TOOLROOT/bin/cmn/fscript $SRCROOT/bin/$FORTE_PORT/fscript\n" unless $QUIET;
    $errs += &os'symlink("$TOOLROOT/bin/cmn/fscript", "$SRCROOT/bin/$FORTE_PORT/fscript");

    print "ln -s $TOOLROOT/bin/cmn/tescript $SRCROOT/bin/$FORTE_PORT/tescript\n" unless $QUIET;
    $errs += &os'symlink("$TOOLROOT/bin/cmn/tescript", "$SRCROOT/bin/$FORTE_PORT/tescript");

    print "ln -s $RELEASE_ROOT/cmn/install/bin/escript $SRCROOT/bin/$FORTE_PORT/escript\n" unless $QUIET;
    $errs += &os'symlink("$RELEASE_ROOT/cmn/install/bin/escript", "$SRCROOT/bin/$FORTE_PORT/escript");

    print "ln -s $RELEASE_ROOT/cmn/install/bin/fcli $SRCROOT/bin/$FORTE_PORT/fcli\n" unless $QUIET;
    $errs += &os'symlink("$RELEASE_ROOT/cmn/install/bin/fcli", "$SRCROOT/bin/$FORTE_PORT/fcli");

    # Create the lib/PORT directory if it does not already exist.
    if (! -d "$SRCROOT/lib/$FORTE_PORT") {
        if ($LINKROOT eq "") {
            $errs += &os'mkdir_p("$SRCROOT/lib/$FORTE_PORT", 0775);
        } else {
            $errs += &os'mkdir_p("$LINKROOT/lib/$FORTE_PORT", 0775);
            $errs += &os'symlink ("$LINKROOT/lib/$FORTE_PORT", "$SRCROOT/lib/$FORTE_PORT");
        }
    }

    if ($FORTE_PORT ne "sequent")
    {
        &os'run_cmd("rm -f $SRCROOT/lib/$FORTE_PORT/*", !$QUIET, $SHOWRET);

        $errs += &os'run_cmd("cp -r $CP_P $PATHREF/lib/$FORTE_PORT/* $SRCROOT/lib/$FORTE_PORT", !$QUIET, $SHOWRET);
    }

    &finished($command_name);

    return $errs;
}

sub set_ccgs_bdb
{
    require "codeline.pl";
    local(@ccgsports) = &cl'unix_ports;

    #since nt,axpnt,mvs390 also make use of ccgs.cmn, we need to add them.      
    push(@ccgsports, "nt", "axpnt", "mvs390", "mac", "alpha");   

    local(@ccgsbdb) = "ccgs.cmn";

    if ($BUILD_MASTER) {
        foreach $port (@ccgsports) {
            push(@ccgsbdb, "ccgs.$port");
        }       
    } else {
        push(@ccgsbdb, "ccgs.$FORTE_PORT");
    }
    return @ccgsbdb;
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

sub do_special_shlib
    # There are a few libraries that are not built the normal way, yet
    # something still expects them to be in the normal shlib place.
{
    local ($errs) = 0;

    if ($OS != $UNIX) {
        # this is a unix only thing
        return 0;
    }
    
    &starting("Archive static libraries");

    # libqqxtraxm.a
    if (grep($_ eq "ds", @svc)) {
        unlink "$SRCROOT/ds/lib/$FORTE_PORT/libqqxtraxm.a";
        $errs += &os'run_cmd("ar -ruv $SRCROOT/ds/lib/$FORTE_PORT/libqqxtraxm.a $SRCROOT/ds/obj/$FORTE_PORT/libqqxtraxm.a/*.o", !$QUIET, $SHOWRET);
        if ($RANLIB_TYPE eq "ranlib") {
            $errs += &os'run_cmd("ranlib $SRCROOT/ds/lib/$FORTE_PORT/libqqxtraxm.a", ! $QUIET, $SHOWRET);
        }
        if (! -e "$SRCROOT/lib/$FORTE_PORT/libqqxtraxm.a") {
            print "ln -s $SRCROOT/ds/lib/$FORTE_PORT/libqqxtraxm.a $SRCROOT/lib/$FORTE_PORT/libqqxtraxm.a\n" unless $QUIET;
            $errs += &os'symlink("$SRCROOT/ds/lib/$FORTE_PORT/libqqxtraxm.a",
                    "$SRCROOT/lib/$FORTE_PORT/libqqxtraxm.a");
        }
    }

    # libqqob.a
    if (grep($_ eq "ob", @svc)) {
        if ($FORTE_REPOSTYPE eq "ob") {
            unlink "$SRCROOT/ob/lib/$FORTE_PORT/libqqob.a";
            $errs += &os'run_cmd("ar -ruv $SRCROOT/ob/lib/$FORTE_PORT/libqqob.a $SRCROOT/ob/obj/$FORTE_PORT/libqqob.a/*.o", ! $QUIET, $SHOWRET);
            if ($RANLIB_TYPE eq "ranlib") {
                $errs += &os'run_cmd("ranlib $SRCROOT/ob/lib/$FORTE_PORT/libqqob.a", ! $QUIET, $SHOWRET);
            }
        }
    }

    # libqqfor.a
    if (! -e "$SRCROOT/lib/$FORTE_PORT/libqqfor.a" && $FORTE_PORT ne "rs6000" && -r "$SRCROOT/oracle/lib/$FORTE_PORT/libqqfor.a") {
        print "ln -s $SRCROOT/oracle/lib/$FORTE_PORT/libqqfor.a $SRCROOT/lib/$FORTE_PORT/libqqfor.a\n" unless $QUIET;
        $errs += &os'symlink("$SRCROOT/oracle/lib/$FORTE_PORT/libqqfor.a",
                "$SRCROOT/lib/$FORTE_PORT/libqqfor.a");
    }

    # libXp
    #if (grep($_ eq "ds", @svc)) {
    #   &os'run_cmd("rm -f $SRCROOT/lib/$FORTE_PORT/libXp.*", ! $QUIET, $SHOWRET);
    #   $errs += &os'run_cmd("cp $PATHREF/xprinter/lib/$FORTE_PORT/libXp.* $SRCROOT/lib/$FORTE_PORT", ! $QUIET, $SHOWRET);
    #}

    # libqqknpthrd.a.exp
    if ($FORTE_PORT eq "rs6000" &&
        (! -e "$SRCROOT/lib/$FORTE_PORT/libqqknpthrd.a.exp") &&
        grep($_ eq "os", @svc)) {
        print "ln -s $SRCROOT/kn/lib/$FORTE_PORT/libqqknpthrd.a.exp $SRCROOT/lib/$FORTE_PORT/libqqknpthrd.a.exp\n" unless $QUIET;
        $errs += &os'symlink("$SRCROOT/kn/lib/$FORTE_PORT/libqqknpthrd.a.exp",
                "$SRCROOT/lib/$FORTE_PORT/libqqknpthrd.a.exp");
    }

    # libqqdb.a.exp & qqsy.a
    if ($FORTE_PORT eq "rs6000" && grep($_ eq "db", @svc)) {
        if (! -e "$SRCROOT/lib/$FORTE_PORT/libqqdb.a.exp") {
            print "ln -s $SRCROOT/db/lib/$FORTE_PORT/libqqdb.a.exp $SRCROOT/lib/$FORTE_PORT/libqqdb.a.exp\n" unless $QUIET;
            $errs += &os'symlink("$SRCROOT/db/lib/$FORTE_PORT/libqqdb.a.exp",
                    "$SRCROOT/lib/$FORTE_PORT/libqqdb.a.exp");
        }
        if (! -e "$SRCROOT/lib/$FORTE_PORT/qqsy.a") {
            print "ln -s $SRCROOT/db/lib/$FORTE_PORT/libqqsy.a $SRCROOT/lib/$FORTE_PORT/qqsy.a\n" unless $QUIET;
            $errs += &os'symlink("$SRCROOT/db/lib/$FORTE_PORT/libqqsy.a",
                    "$SRCROOT/lib/$FORTE_PORT/qqsy.a");
        }
    }

    if ($FORTE_PORT ne "rs6000" && $FORTE_PORT ne "ptxi86" && $FORTE_PORT ne "mvs390"
        && grep($_ eq "db", @svc)) {
            unlink "$SRCROOT/lib/$FORTE_PORT/qqsy.a";
            $errs += &os'run_cmd("ar -ruv $SRCROOT/lib/$FORTE_PORT/qqsy.a $SRCROOT/db/obj/$FORTE_PORT/libqqsy.a/*.o", ! $QUIET, $SHOWRET);
    }


    # libqqol.a.exp
    if ($FORTE_PORT eq "rs6000" && grep($_ eq "fo", @svc)) {
        if (! -e "$SRCROOT/lib/$FORTE_PORT/libqqol.a.exp") {
            print "ln -s $SRCROOT/fo/lib/$FORTE_PORT/libqqol.a.exp $SRCROOT/lib/$FORTE_PORT/libqqol.a.exp\n" unless $QUIET;
            $errs += &os'symlink("$SRCROOT/fo/lib/$FORTE_PORT/libqqol.a.exp",
                    "$SRCROOT/lib/$FORTE_PORT/libqqol.a.exp");
        }
    }

    # libstd.so
    if ($FORTE_PORT eq "ptxi86" &&
        (! -e "$SRCROOT/lib/$FORTE_PORT/libstd.so") &&
        grep($_ eq "os", @svc)) {
        print "ln -s /opt/epc/lib/libstd.so $SRCROOT/lib/$FORTE_PORT/libstd.so\n" unless $QUIET;
        $errs += &os'symlink("/opt/epc/lib/libstd.so",
                "$SRCROOT/lib/$FORTE_PORT/libstd.so");
    }

    
    &finished("Archive static libraries");

    return $errs;
}

sub do_special_exe_nt
    # There are a few "executables" that arn't built the normal way.
{
    local ($errs) = 0;

    return $errs;
}

sub do_special_exe_unix
    # There are a few "executables" that arn't built the normal way.
{
    local ($errs) = 0;

    if ($PRODUCT eq "forte") {
        # Only do these for the forte product, these symlinks screw up
        # other product's builds.
        if (! -e "$SRCROOT/bin/$FORTE_PORT/fscript" && -r "$TOOLROOT/bin/cmn/fscript") {
            print "ln -s $TOOLROOT/bin/cmn/fscript $SRCROOT/bin/$FORTE_PORT/fscript\n" unless $QUIET;
            $errs += &os'symlink("$TOOLROOT/bin/cmn/fscript",
                    "$SRCROOT/bin/$FORTE_PORT/fscript");
        }
        if (! -e "$SRCROOT/bin/$FORTE_PORT/tescript" && -r "$TOOLROOT/bin/cmn/tescript") {
            print "ln -s $TOOLROOT/bin/cmn/tescript $SRCROOT/bin/$FORTE_PORT/tescript\n" unless $QUIET;
            $errs += &os'symlink("$TOOLROOT/bin/cmn/tescript",
                    "$SRCROOT/bin/$FORTE_PORT/tescript");
        }
        if (! -e "$SRCROOT/bin/$FORTE_PORT/escript" && -r "$RELEASE_ROOT/cmn/install/bin/escript") {
            print "ln -s $RELEASE_ROOT/cmn/install/bin/escript $SRCROOT/bin/$FORTE_PORT/escript\n" unless $QUIET;
            $errs += &os'symlink("$RELEASE_ROOT/cmn/install/bin/escript",
                    "$SRCROOT/bin/$FORTE_PORT/escript");
        }
        if (! -e "$SRCROOT/bin/$FORTE_PORT/fcli" && -r "$RELEASE_ROOT/cmn/install/bin/fcli") {
            print "ln -s $RELEASE_ROOT/cmn/install/bin/fcli $SRCROOT/bin/$FORTE_PORT/fcli\n" unless $QUIET;
            $errs += &os'symlink("$RELEASE_ROOT/cmn/install/bin/fcli",
                    "$SRCROOT/bin/$FORTE_PORT/fcli");
        }
    }

    # Create $FORTE_LINKROOT/regress if there's a FORTE_LINKROOT
    if ($LINKROOT ne "") {
        if (! -e "$LINKROOT/regress") {
            $errs += &os'mkdir_p("$LINKROOT/regress", 0775);
        }
        if (! -e "$SRCROOT/regress") {
            $errs += &os'symlink ("$LINKROOT/regress", "$SRCROOT/regress");
        }
    } else {
        # Make sure $SRCROOT/regress exists
        if (! -e "$SRCROOT/regress") {
            $errs += &os'mkdir_p("$SRCROOT/regress", 0775);
        }
    }

    return $errs;
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
    $PATHREF    = $ENV{'PATHREF'};
    $SRCROOT    = $ENV{'SRCROOT'};
    $PRODUCT    = $ENV{'PRODUCT'} || "forte";
    $RELEASE_ROOT = $ENV{'RELEASE_ROOT'} || "$PATHREF/release";
    $LOGNAME       = $ENV{'LOGNAME'};
    $FORTE_PORT = $ENV{'FORTE_PORT'};
    $LINKROOT   = $ENV{'FORTE_LINKROOT'} || "";
    $FORTE_REPOSTYPE = $ENV{'FORTE_REPOSTYPE'};
    $RANLIB_TYPE = $ENV{'RANLIB_TYPE'};
    $LOG_DIR    = $ENV{'LOG_DIR'} || "/tmp";
    $BDB_LIBPATH    = $ENV{'BDB_LIBPATH'} || "$SRCROOT/bdb;";
    @BDB_LIBPATH    = split(';', $BDB_LIBPATH);
    $WINSYS     = ($ENV{'FORTE_WINSYS'} || 'nows');
    @WINBLD     = split(' ', ($ENV{'FORTE_BUILD_WINSYS'} || $WINSYS));

    $CWD_FLAG   = 0;    #build current working dir only
    $EFLAG      = "-e";
    $KFLAG      = "";
    $MFLAG      = "off";
    $BUILD_MASTER   = 0;
    $DOTST      = 1;    # warning: DOTST is more than just a flag for
                        # testing; it says whether or not to build the
                        # test drivers
    $EXTRA_MAKE_ARGS = "";
    @BDB_FILELIST = ();
    $MAKE_PREFIX = "";
    $MMFCMD     = "mmfdrv -q -all -rc mmfdrv.rc -glean install.map PERL4_CHECK=0";

    $BLDHOSTCMD = "NO_BLDHOST_COMMAND";
    $BLDHOSTCMD = "bldhost" if ($OS == $UNIX);
    $BLDHOSTCMD = "sh bldhost" if ($OS == $NT);

    $HELP2HTML  = "help2html";
    $debug      = 0;
    $help       = 0;
    $SHOWRET    = 0;    #don't show return codes from &os'run_cmd
    $QUIET      = 0;
    $AUTO       = 0;
    $|          = 1;
    $JAVA_ONLY = 0;
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
        &init_unix_help_table;
    } elsif ($OS == $NT) {
        $MAKECMD = "make";
        $MAKER   = "makemake.gnu";
        &init_nt_processors;
        &init_nt_help_table;
    }
}

sub init_nt_help_table
#set up help table for makedrv commands.
{
    %CMD_HELP = (
        'ant', 'help_ant',
        'makemake', 'help_makemake',
        'makedepend', 'help_makedepend',
        'makemakedepend', 'help_makemakedepend',
        'ccgs', 'help_ccgs',
        'lib', 'help_lib',
        'loadlib', 'help_lib',
        'sbr', 'help_lib',
        'shlib', 'help_shlib',
        'exe', 'help_exe',
        'clean_all', 'help_clean',
        'java', 'help_java',
        'makemakejava', 'help_makemakejava',
        'cleanjava', 'help_cleanjava',
        'jar', 'help_jar',
        'makemaketool', 'help_makemaketool',
        'import', 'help_tool',
        'importpartial', 'help_tool',
        'export', 'help_tool',
        'remproj', 'help_tool',
        'freshrepos', 'help_tool',
        'image', 'help_nodependfile',
        'install', 'help_nodependfile',
        'codegen', 'help_codegen',
        'slavecodegen', 'help_codegen',
        'fcompile', 'help_codegen',
        'copyup', 'help_nodependfile',
    );
}

sub init_unix_help_table
#set up help table for makedrv commands.
{
    %CMD_HELP = (
        'ant', 'help_ant',
        'makemake', 'help_makemake',
        'makedepend', 'help_makedepend',
        'makemakedepend', 'help_makemakedepend',
        'ccgs', 'help_ccgs',
        'prelib', 'help_prelib',
        'lib', 'help_lib',
        'shlib', 'help_shlib',
        'exe', 'help_exe',
        'pexe', 'help_pexe',
        'cplib', 'help_cplib',
        'cpbin', 'help_cpbin',
        'clean_all', 'help_clean_all',
        'scope', 'help_scope',
        'mmf', 'help_mmf',
        'printmap', 'help_printmap',
        'wfmmf', 'help_mmf',
        'wfprintmap', 'help_wfprintmap',
        'webmmf', 'help_mmf',
        'webprintmap', 'help_webprintmap',
        'bdb', 'help_bdb',
        'vlib', 'help_vlib',
        'reccgs', 'help_reccgs',
        'makemaketool', 'help_makemaketool',
        'import', 'help_tool',
        'importpartial', 'help_tool',
        'export', 'help_tool',
        'remproj', 'help_tool',
        'freshrepos', 'help_tool',
        'image', 'help_nodependfile',
        'install', 'help_nodependfile',
        'codegen', 'help_codegen',
        'slavecodegen', 'help_codegen',
        'fcompile', 'help_codegen',
        'copyup', 'help_nodependfile',
        'java', 'help_java',
        'jar', 'help_jar',
        'makemakejava', 'help_makemakejava',
        'makemakedependjava', 'help_makemakedependjava',
        'makedependjava', 'help_makedependjava',
        'cleanjava', 'help_cleanjava',
        'javainstr', 'help_javainstr',
        'cleanjavainstr', 'help_cleanjavainstr',
        'cmdhelp', 'help_cmdhelp',
        'makemakecmdhelp', 'help_makemakecmdhelp',
    );
}

sub init_nt_processors
#set up global command processor table for nt version
{
    %CMD_PROCESSOR = (
        'ant', 'cmd_ant',
        'makemake', 'cmd_makemake',
        'makedepend', 'cmd_makedepend',
        'makemakedepend', 'cmd_makemakedepend',
        'ccgs', 'cmd_ccgs',
        'lib', 'cmd_lib',
        'loadlib', 'cmd_lib',   #uses lib bdb, target loadlib
        'sbr', 'cmd_lib',       #uses lib bdb, target sbr
        'shlib', 'cmd_shlib',
        'exe', 'cmd_exe',
        'clean_all', 'cmd_clean',
        'java', 'cmd_java',
        'makemakejava', 'cmd_makemakejava',
        'makemakedependjava', 'cmd_makemakedependjava',
        'makedependjava', 'cmd_makedependjava',
        'cleanjava', 'cmd_cleanjava',
        'jar', 'cmd_jar',
        'makemaketool', 'cmd_makemaketool',
        'import', 'cmd_tool',
        'importpartial', 'cmd_tool',
        'export', 'cmd_tool',
        'remproj', 'cmd_tool',
        'freshrepos', 'cmd_tool',
        'image', 'cmd_nodependfile',
        'install', 'cmd_nodependfile',
        'codegen', 'cmd_codegen',
        'slavecodegen', 'cmd_codegen',
        'fcompile', 'cmd_codegen',
        'copyup', 'cmd_nodependfile',
        'mmf', 'cmd_mmf',
        'makemf', 'cmd_makemf',
        'printmap', 'cmd_printmap',
        'bdb', 'cmd_bdb',
        'vlib', 'cmd_vlib',
        'cvsupdate', 'cmd_cvsupdate',
    );
}

sub init_unix_processors
#set up global command processor table for unix version
{
    %CMD_PROCESSOR = (
        'ant', 'cmd_ant',
        'makemake', 'cmd_makemake',
        'makedepend', 'cmd_makedepend',
        'makemakedepend', 'cmd_makemakedepend',
        'ccgs', 'cmd_ccgs',
        'prelib', 'cmd_prelib',
        'lib', 'cmd_lib',
        'shlib', 'cmd_shlib',
        'exe', 'cmd_exe',
        'pexe', 'cmd_pexe',
        'cplib', 'cmd_cplib',
        'cpbin', 'cmd_cpbin',
        'clean_all', 'cmd_clean_all',
        'scope', 'cmd_scope',
        'mmf', 'cmd_mmf',
        'makemf', 'cmd_makemf',
        'printmap', 'cmd_printmap',
        'wfmmf', 'cmd_mmf',
        'wfprintmap', 'cmd_wfprintmap',
        'webmmf', 'cmd_mmf',
        'webprintmap', 'cmd_webprintmap',
        'bdb', 'cmd_bdb',
        'vlib', 'cmd_vlib',
        'reccgs', 'cmd_reccgs',
        'makemaketool', 'cmd_makemaketool',
        'import', 'cmd_tool',
        'importpartial', 'cmd_tool',
        'export', 'cmd_tool',
        'remproj', 'cmd_tool',
        'freshrepos', 'cmd_tool',
        'image', 'cmd_nodependfile',
        'install', 'cmd_nodependfile',
        'codegen', 'cmd_codegen',
        'slavecodegen', 'cmd_codegen',
        'fcompile', 'cmd_codegen',
        'copyup', 'cmd_nodependfile',
        'java', 'cmd_java',
        'idl2java', 'cmd_idl2java',
        'makemakejava', 'cmd_makemakejava',
        'makemakedependjava', 'cmd_makemakedependjava',
        'makedependjava', 'cmd_makedependjava',
        'cleanjava', 'cmd_cleanjava',
        'jar', 'cmd_jar',
        'javainstr', 'cmd_javainstr',
        'cleanjavainstr', 'cmd_cleanjavainstr',
        'makemakecmdhelp', 'cmd_makemakecmdhelp',
        'cmdhelp', 'cmd_cmdhelp',
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
 -m           Yes, you really want to build in mainline.
 -t           Build test directories also (DEFAULT).
 -not         Do not build test directories.
 -w           makemake command:  generate makefiles for Windows 3.x.
 -notoolgen   Do not do anything with toolgen directories.
 -j njobs     allow make to run <njobs> in parallel (unix only).

 -b bdbs      use colon-delimited <bdbs> list instead of standard bdbs
              implied by command names.
 -C           Build the current directory only.
 -s services  Do only named services. E.g., -s ds:rp:sh.
 -S services  Do all but named services.
 -d dirs      Build only named directories (as listed in bdb's for command).
 -D dirs      Build all but named directories.
 -master      Do all directories listed in all ccgs.<port> files as well.
              (for ccgs, makemake, makedepend). The default is just
              ccgs.cmn and ccgs.<port>.
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
        } elsif ($arg eq "-not") {
            $DOTST = 0;
        } elsif ($arg eq "-t") {
            $DOTST = 1;
        } elsif ($arg eq "-master") {
            $BUILD_MASTER = 1;
        } elsif ($arg eq "-notoolgen") {
            $PruneDir = "toolgen";
        } elsif ($arg eq "-auto") {
            $AUTO = 1;
        } elsif ($arg eq "-debug") {
            $debug = 1;
            $SHOWRET = 1;   #show returns as well.
        } elsif ($arg eq "-q" || $arg eq "-quiet") {
            $QUIET = 1;
        } elsif ($arg eq "-w") {
            $MAKER = "makemake.w3";
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

    $ENV{'ROOT'} = $SRCROOT;

    #
    # Disable the 'cplib' and 'cpbin' operations if SRCROOT is set to "/forte1/d".
    #
    $CP_CMDS = ":cplib:cpbin:";

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
