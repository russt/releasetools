#!/bin/perl -w
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
# @(#)release.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# release.pl
#  execute a BOM file

package release;

require "os.pl";
require "path.pl";
require "sp.pl";
require "bomparse.pl";
require "bomsuprt.pl";
require "pcrc.pl";

sub main
{
    local(*ARGV, *ENV) = @_;
    local($errorCount);

    &Init;
    return 1 if &ParseArgs;
    if ($FilterFile ne "") {
        &LoadFilter;
    }
    return 1 if &OpenLog;
    &PrepBomParse;
    foreach $file (@fileList) {
        &Log("Executing $file from $BOMLOC\n\n");
        if (!chdir($BOMLOC)) {
            &error("Failed to chdir into $BOMLOC\n");
        }
        print "About to call release on '$file'\n" if ($DEBUG);
        if (! -r $file) {
            &error("file $file is not readable in directory $BOMLOC\n");
            next;
        }
        $errorCount = $totalFiles = $filesCopied = 0;
        $errorCount = &ReleaseBOMFile($file, $releaseDir);
        &Log(sprintf("\nFile Report for $file: %d copied, %d error(s), %d total\n", $filesCopied, $errorCount, $totalFiles), 1);
    }
    if ($totalErrorCount > 0) {
        &Log("$p, Detected $totalErrorCount error(s)\n", 1);
    } else {
        &Log("$p, No errors detected\n", 1);
    }
    &CloseLog;
    return $totalErrorCount;
}

sub Init
{
    # variables from other packages
    $p = $'p;
    $OS = $'OS;
    $UNIX = $'UNIX;

    $totalErrorCount = 0;

    # variables that affect the programs direction
    $DEBUG = 0;
    $QUIET = 0;
    $VERBOSE = 0;
    $TEST = 0;
    $FILTERDEBUG = 0;
    $logIt = 1;
    $logFile = "";
    $logOpened = 0;
    $filesCopied = 0;
    $totalFiles = 0;
    $doClearLog = 0;
    @NoSymlinkTypes = ("repos");

    $DEFAULT_DIR_PERM = 0755;
    # variables that the user defined
    %USERVARDEF = ();
    @fileList = ();
    $kitFlagType = "dev";
    $BOMLOC = "";
    $useSymlinks = 0;
    $doISO9660 = 0;
    $chgrp = "";
    # whether or not to include other BOM files.
    $doInclude = 1;
    $doChecksum = 1;
    $releaseDir = "";
    $releaseBase = "";
    $checksumFile = "checksum.log";
    $FailBOM = "";
    $FilterFile = "";
    $Filter = "";
    $FollowSymlinks = 0;
    $symlinkUnder = 0;
    @symlinkUnderDirs = ();

    # variables from the environment
    $TARGET_OS = $ENV{'FORTE_PORT'} || "";
    $HOST_NAME = $ENV{"HOST_NAME"} || "unknown";
    # used by the follow symlinks code
    $SRCROOT = $ENV{"SRCROOT"};
    $PATHREF = $ENV{"PATHREF"};

    $checksumTempFile = &os::TempFile;
}

sub cleanup
{
    if ($logOpened) {
        print "$p cleanup...\n";
        print LOG "$p cleanup...\n";
        &CloseLog;
    }
    &CloseChecksum;
}

sub PrepBomParse
{
    &bomsuprt'Init($TARGET_OS, 1);
    &bomsuprt'SetKitType($kitFlagType);
    foreach $var (keys %USERVARDEF) {
        # print "Setting $var = $USERVARDEF{$var}\n";
        &bomsuprt::SetVar($var, $USERVARDEF{$var});
    }
}

sub OpenLog
{
    if ($logIt) {
        if (!open(LOG, ">>$logFile")) {
            $logIt = 0;
            $logOpened = 0;
            &error("Failed to open $logFile for append: $!");
        } else {
            $logOpened = 1;
            print LOG "\n*** Log opened on: " . &sp::GetDateStr . " ***\n\n";
        }
    }
    if ($FailBOM ne "") {
        if (!open(FAILBOMOUT, ">>$FailBOM")) {
            &error("Failed to open $FailBOM for append: $!");
            $FailBOM = "";
        } else {
            print FAILBOMOUT "# failed to release files (generated by $p on $HOST_NAME)\n";
        }
    }
    return 0;
}

sub CloseLog
{
    if ($logOpened) {
        $logOpened = 0;
        close LOG;
    }
    if ($FailBOM ne "") {
        close(FAILBOMOUT);
    }
    return 0;
}

sub OpenChecksum
{
    if ($doChecksum) {
        if ($doISO9660) {
            $checksumFile = &convertFileISO9660($checksumFile);
        }
        # if (!open(CHECKSUM, ">>$checksumFile")) {
        if (!open(CHECKSUM, ">$checksumTempFile")) {
            $doChecksum = 0;
            $checksumLogOpened = 0;
            &error("Failed to open $checksumTempFile for write: $!\n");
            return 1;
        } else {
            $checksumLogOpened = 1;
        }
    }
    return 0;
}

sub CloseChecksum
{
    if ($checksumLogOpened) {
        $checksumLogOpened = 0;
        close CHECKSUM;

        # Append the checksum log in /tmp to the real one.
        local($buf) = "";
        if (&os'read_file2str(*buf, $checksumTempFile)) {
            &error("Failed to open $checksumTempFile for read: $!\n");
            return 1;
        }
        if (&os'append_str2file(*buf, $checksumFile)) {
            &error("Failed to open $checksumFile for append: $!\n");
            return 1;
        }
        &os::rmFile($checksumTempFile);
    }
    return 0;
}

sub ParseArgs
{
    local($arg, $lcarg, $ver, $releaseBase);
    $ver = "unknown";
    $releaseBase = "";
    while (defined($arg = shift @ARGV)) {
        $lcarg = lc($arg);
        if ($arg =~ /^-/) {
            if ($arg eq "-h" || $arg eq "-help") {
                &Usage;
                return 2;
            } elsif ($arg eq "-C" || $arg eq "-w") {
                $releaseDir = shift @ARGV;
            } elsif ($arg eq "-r") {
                $releaseBase = shift @ARGV;
            } elsif ($arg eq "-v" || $arg eq "-ver") {
                $ver = shift @ARGV;
            } elsif ($arg eq "-dev") {
                $kitFlagType = "dev";
            } elsif ($arg eq "-rtv") {
                $kitFlagType = "rtv";
            } elsif ($arg eq "-fbc") {
                $kitFlagType = "fbc";
            } elsif ($arg eq "-synerjcl") {
                $kitFlagType = "synerjcl";
            } elsif ($arg eq "-kittype") {
                $kitFlagType = shift @ARGV;
            } elsif ($arg eq "-port" || $arg eq "-c" || $arg eq "-p") {
                $TARGET_OS = shift @ARGV;
            } elsif ($arg eq "-bomloc") {
                $BOMLOC = shift @ARGV;
            } elsif ($lcarg eq "-filter") {
                $FilterFile = shift @ARGV;
            } elsif ($arg eq "-chgrp") {
                $chgrp = shift @ARGV;
            } elsif ($arg eq "-include") {
                $doInclude = 1;
            } elsif ($arg eq "-noinclude") {
                $doInclude = 0;
            } elsif ($arg eq "-s" || $arg eq "-symlink") {
                $useSymlinks = 1;
            } elsif ($arg eq "-log") {
                $logIt = 1;
            } elsif ($arg eq "-nolog") {
                $logIt = 0;
            } elsif ($arg eq "-checksum") {
                $doChecksum = 1;
            } elsif ($arg eq "-nochecksum") {
                $doChecksum = 0;
            } elsif ($arg eq "-iso" || $arg eq "-iso9660" || $arg eq "-ISO9660") {
                $doISO9660 = 1;
            } elsif ($arg eq "-proto") {
                $USERVARDEF{"PROTO"} = 1;
            } elsif ($arg eq "-debug") {
                $DEBUG = 1;
                $FILTERDEBUG = 1;
                $bomparse::DEBUG = 1;
            } elsif ($lcarg eq "-filterdebug") {
                $FILTERDEBUG = 1;
            } elsif ($arg eq "-test" || $arg eq "-t") {
                $TEST = 1;
                $logIt = 0;
                $doChecksum = 0;
            } elsif ($arg eq "-noverbose") {
                $VERBOSE = 0;
            } elsif ($arg eq "-verbose") {
                $VERBOSE = 1;
                $QUIET = 0;
            } elsif ($arg eq "-q" || $arg eq "-quiet") {
                $QUIET = 1;
                $VERBOSE = 0;
            } elsif ($arg eq "-noq") {
                $QUIET = 0;
            } elsif ($lcarg eq "-fsym") {
                $FollowSymlinks = 1;
            } elsif ($lcarg eq "-nofsym") {
                $FollowSymlinks = 0;
            } elsif ($arg eq "-b") {
                push(@fileList, shift @ARGV);
            } elsif ($arg eq "-clearlog") {
                $doClearLog = 1;
            } elsif ($lcarg eq "-genfailbom") {
                $FailBOM = shift @ARGV;
            } elsif ($lcarg eq "-symlinkunder") {
                my($dir) = shift @ARGV;
                my($expr) = "^" . quotemeta($dir);
                $symlinkUnder = 1;
                push(@symlinkUnderDirs, $expr);
            } elsif ($arg eq "-overwrite" || $arg eq "-m") {
                # obsolete argument
            } elsif ($arg eq "") {
                # ignore blanks
            } else {
                &error("Unrecognized argument '$arg'\n");
                &Usage;
                return 1;
            }
        } else {
            if ($arg =~ /=/) {
                # It's a variable declaration.  Example:
                #  VAR = nt,rs6000,solsparc,alphaosf
                local($varName, $value) = ($arg =~ /(\S+)\s*=\s*(.*)/);
                $USERVARDEF{$varName} = $value;
            } else {
                push(@fileList, $arg);
            }
        }
    }
    if ($BOMLOC eq "") {
        $BOMLOC = &path'mkpathname($ENV{'RELEASE_ROOT'}, "bom");
    }
    
    if ($releaseDir eq "") {
        if ($releaseBase eq "") {
            &error("releaseDir is not set, use the -r or -w flags\n");
            &Usage;
            return 1;
        }
        if ($TARGET_OS eq "w30") {
            $releaseDir = &path'mkpathname($releaseBase, $ver,
                                           "windows");
        } elsif ($TARGET_OS eq "mac" || $TARGET_OS eq "powermac") {
            $releaseDir = &path'mkpathname($releaseBase, $ver,
                                           $TARGET_OS, "Forte");
        } else {
            $releaseDir = &path'mkpathname($releaseBase, $ver,
                                           $TARGET_OS);
        }
        $logDir = &path'mkpathname($releaseBase, "log");
    } else {
        if (! &path::isfullpathname($releaseDir)) {
            $releaseDir = &path::mkpathname(&path::pwd, $releaseDir);
        }
        $logDir = &path'mkpathname(&path'head($releaseDir), "log");
    }
    if (! $TEST && &os'mkdir_p($logDir, 0775)) {
        &error("Failed to mkdir -p $logDir\n");
        return 1;
    }
    $logFile = &path'mkpathname($logDir, "$ver.$TARGET_OS.log");
    print "Logging to $logFile\n" if ($VERBOSE);
    if ($doClearLog) {
        print "Removing log file\n" if ($VERBOSE);
        &os'rmFile($logFile);
    }

    # If the the user doesn't specify a bom file to do, then we do the
    # bom file associated with kit type.
    if ($#fileList+1 == 0) {
        if ($kitFlagType eq "dev") {
            $defaultBomFile = ($ENV{"PRODUCT"} || "forte") . ".bom";
        } else {
            $defaultBomFile = $kitFlagType . ".bom";
        }
        print "Defaulting to BOM file $defaultBomFile\n" if ($VERBOSE);
        push(@fileList, $defaultBomFile);
    }
    if (! $useSymlinks && $FollowSymlinks) {
        print "It doesn't make much sense to not create symlinks, but to try to follow them (options -s and -fsym).\n";
    }

    return 0;
}

sub LoadFilter
{
    require "filterFiles.pl";
    
    print "$p using filter $FilterFile\n";
    $Filter = ""  unless( defined($Filter = &filterFiles::ReadFilter($FilterFile)) );
    return 0;
}

sub Usage
{
    print <<"!";
usage: $p [-w <dir>] [-r <dir>] [-port <port>] [-s] [-fsym] [-iso9660]
          [-include|-noinclude] [-bomloc <dir>] [-b <bomFile>]
          [-genfailbom <outputBomFile>] [-filter <filterFile>]
          [-dev|-rtv|-fbc|-synerjcl] [-log|-nolog] [-checksum|-nochecksum]
          [-q|-noq] [-help] [-verbose] [-test] [-clearlog] [-filterdebug]
          [-chgrp <group>] [-symlinkUnder <dir>] [VAR1=value1]*
          bomFiles

  eg: $p workflow.bom -w /vanish/kits/mykit -verbose SRCROOT=/cure3/wf/d

      -w       The working directory to release to
      -r       Use <dir>/<version>/<port> as the working directory
      -v       Version name (i.e. v40a0)
      -iso9660 Force ISO9660 compliance
      -s       Use symlinks instead of copying (type repos is always copied)
      -fsym    Chase symlinks and replace \$PATHREF with \$SRCROOT.
      -log     Do logging
      -nolog   Do not do logging
      -checksum  Create a checksum.log file checksuming each file (default)
      -nochecksum  Don't create the checksum file
      -proto   Use proto files (like proto_ftexec).
      -port    Use <port> for the platform.
      -include Follow the include commands (default)
      -noinclude  Do not follow the include commands
      -bomloc  Find BOM files in this directory.
      -rtv     Make it an RTV kit.
      -fbc     Make it a FBC kit.
      -dev     Make it a DEV kit (the normal full kit) (default)
      -synerjcl  Make it a synerj client kit
      -q       Run quietly
      -noq     Turn off quiet mode
      -verbose Print lots of info
      -test    Print the commands to execute but don't execute them
      -clearlog Remove the log before creating another.
      -chgrp   Run chgrp on every file and directory.
      -filter  Pass the files and directories thru this filter.
      -filterdebug  Print out potentially debugging info while using filters
      -symlinkUnder  If -s is used, only make symlinks to files located
                         under this directory.  Can be given multiple
                         times for multiple directories.
      -genfailbom <filename>
               generate bom of missing kit components in <filename>
!
}

sub error
{
    local($msg) = @_;

    print STDERR "BUILD_ERROR: $p, " . $msg;
    if ($logOpened) {
        print LOG "BUILD_ERROR: $p, " . $msg;
    }
    ++$totalErrorCount;
}

sub warning
{
    local($msg) = @_;

    print "Warning: $p, $msg";
    if ($logOpened) {
        print LOG "Warning: $p, $msg";
    }
}

########################################################################

sub ReleaseBOMFile
{
    local($file, $toDir) = @_;
    local($errCnt) = 0;
    local($objNum);
    
    print "Parsing $file...\n" unless $QUIET;
    $objNum = &bomparse'ReadBOM($file, $doInclude);
    if ($objNum == $bomparse'invalidObjNum) {
        &error("Failed to parse $file correctly\n");
        return 1;
    }
    if ($bomparse'ParseErrorCount != 0) {
        print "There were parse errors.\n";
        $errCnt += $bomparse'ParseErrorCount;
        $totalErrorCount += $bomparse'ParseErrorCount;
    }
    print "Executing parsed tree...\n" unless $QUIET;
    # This will essentially "execute" the parsed tree; that is,
    # evaluation is done here to determine which branches can be bruned.
    &bomsuprt'ExecuteObjTree($objNum);
    print "Releasing into $toDir...\n" unless $QUIET;
    if (! $TEST) {
        if (&os'createdir($toDir, 0775)) {
            &error("Failed to create '$toDir'\n");
            ++$errCnt;
        }
        if (!chdir($toDir)) {
            &error("Failed to chdir into $toDir: $!\n");
            return 1+$errCnt;
        }
        &OpenChecksum;
    }
    $errCnt += &ReleaseBOMObj($objNum);
    &CloseChecksum;
    
    return $errCnt;
}

sub ReleaseBOMObj
{
    local($objNum) = @_;

    %dirContents = ();
    %dirObjNum = ();
    print "Prepping tree...\n" unless $QUIET;
    # BuildDirObjTree will convert the parsed tree into a file
    # tree.  %dirContents is the file tree where an artificial node of
    # "/" marks the start, while the corresponding entries in
    # %dirObjNum will give you the handles into each entry.
    &bomsuprt'BuildDirObjTree($objNum, *dirContents, *dirObjNum);
    $filesCopied = 0;
    $totalFiles = 0;
    print "Releasing files...\n" unless $QUIET;
    return &ReleaseTree("/", 0);
}

sub ReleaseTree
{
    local($topDir, $level) = @_;
    local($dir, $fullDir, $objNum, $dstFile, $srcFile, $dstDir, $perm);
    local($nerrs) = 0;

    return 0 if (!defined($dirContents{$topDir}));
    print "ReleaseTree: $topDir $level\n" if ($DEBUG);
    foreach $dir (sort split($;, $dirContents{$topDir})) {
        next if ($dir eq "");
        if ($level == 0) {
            $fullDir = $dir;
        } else {
            $fullDir = $topDir . "/" . $dir;
        }
        $objNum = $dirObjNum{$fullDir};
        print "fullDir='$fullDir' objNum='$objNum'\n" if ($DEBUG);
        if (defined($dirContents{$fullDir})) {
            if ($Filter ne "" &&
                ! &filterFiles::KeepFile($Filter, $fullDir . "/")) {
                print "Skipped $fullDir because of filter\n" if ($FILTERDEBUG);
            } else {
                #
                # Create the directory
                #
                $dstFile = &path::mklocalpath($fullDir);
                if ($doISO9660) {
                    $dstFile = &convertDirISO9660($dstFile);
                }
                if ($bomparse::objType[$objNum] eq "filemapping") {
                    $perm = $DEFAULT_DIR_PERM;
                } elsif ($bomparse::objType[$objNum] eq "minstall_dcl") {
                    $perm = $DEFAULT_DIR_PERM;
                } else {
                    # a mkdir_dcl
                    $perm = oct($bomparse::objAttrib1[$objNum]);
                }
                if ($perm == 0) {
                    &error("Permissions on directory '$dstFile' are $perm as referenced " . &bomparse::ObjLocation($objNum) . ", overriding.\n");
                    $perm = $DEFAULT_DIR_PERM;
                }
                if ($TEST) {
                    print "mkdir -p '$dstFile'\n";
                    printf("chmod %o '$dstFile'\n", $perm);
                    if ($chgrp ne "") {
                        print "chgrp $chgrp $dstFile\n";
                    }
                } else {
                    &Log(sprintf("mkdir %o $dstFile\n", $perm));
                    $nerrs += &os::createdir($dstFile, $perm);
                    if ($chgrp ne "") {
                        &os::chgrp($chgrp, $dstFile);
                    }
                }

#printf "\nobjType='%s' a3='%s'\n", $bomparse::objType[$objNum], $bomparse::objAttrib3[$objNum];

                if ($bomparse::objType[$objNum] eq "minstall_dcl" 
                        && $dstFile eq $bomparse::objAttrib2[$objNum]) {
                    $nerrs += &ExplodeBtz($bomparse::objAttrib1[$objNum], 
                                          $bomparse::objAttrib2[$objNum],
                                          $bomparse::objAttrib3[$objNum]);
                }
            }
            $nerrs += &ReleaseTree($fullDir, $level + 1);
        } else {
            my($type) = $bomparse::objAttrib3[$objNum];
            my($isLocalSymlink) = ($type =~ /link/i);

#printf "\nELSE objType='%s' type='%s' isLocalSymlink=%d\n", $bomparse::objType[$objNum], $type, $isLocalSymlink;

            if ($Filter ne "") {
                if (! &filterFiles::KeepFile($Filter, $fullDir)) {
                    print "Skipped $fullDir because of filter\n" if ($FILTERDEBUG);
                    next;
                }
            }
            #
            # Copy the file
            #
            $dstFile = &path::mklocalpath($fullDir);
            if ($doISO9660) {
                local($d, $f);
                $d = &convertDirISO9660(&path::head($dstFile));
                $f = &convertFileISO9660(&path::tail($dstFile));
                $dstFile = &path::mkpathname($d, $f);
            }
            $srcFile =
                &path::mkpathname(&path::mklocalpath($bomparse::objAttrib4[$objNum]),
                                 &path::mklocalpath($bomparse::objAttrib1[$objNum]));
            local($srcIsThere);
            $srcIsThere = (-e $srcFile);
            if (! $isLocalSymlink && ! $useSymlinks && ! $srcIsThere) {
                &error("Source file '$srcFile' does not exist as referenced " . &bomparse::ObjLocation($objNum) . "\n");
                ++$nerrs;
                &ErrorOnObjNum($objNum);
            } elsif ($TEST) {
                if ($useSymlinks) {
                    printf("ln -s '%s' '%s'\n", $srcFile, $dstFile);
                } else {
                    printf("cp '%s' '%s'\n", $srcFile, $dstFile);
                    print "chmod $bomparse::objAttrib2[$objNum] '$dstFile'\n";
                }
            } else {
                if (! $isLocalSymlink && ! $srcIsThere) {
                    # We must be using symlinks; report the error, but
                    # still make the symlink.
                    &error("Source file '$srcFile' does not exist as referenced " . &bomparse::ObjLocation($objNum) . "\n");
                    ++$nerrs;
                    &ErrorOnObjNum($objNum);
                }
                &Log("$srcFile -> $dstFile\n");
                $perm = oct($bomparse::objAttrib2[$objNum]);
                if (&CopyFile($srcFile, $dstFile, $perm, $type)) {
                    ++$nerrs;
                    &ErrorOnObjNum($objNum);
                } else {
                    ++$filesCopied;
                }
            }
            ++$totalFiles;
        }
    }
    return $nerrs;
}

sub CopyFile
{
    local($srcFile, $dstFile, $mode, $type) = @_;
    my($isLocalSymlink) = ($type =~ /link/i);
    
#printf "CopyFile(srcFile=%s,dstFile=%s,mode=%s,type=%s)\n", $srcFile, $dstFile, $mode, $type;

    if ( $isLocalSymlink || ($useSymlinks && ! &sp::IsInList($type, @NoSymlinkTypes)) ) {
        my($doSymlink) = 1;
        if ($FollowSymlinks) {
            my($srcLink);
            $srcLink = &os::ChaseSymlink($srcFile);
            if (defined($srcLink) && $srcLink ne $srcFile) {
                my($localSrcFile);
                $srcFile = $srcLink;
                $localSrcFile = $srcFile;
                $localSrcFile =~ s/$PATHREF/$SRCROOT/;
                if (-e $localSrcFile) {
                    $srcFile = $localSrcFile;
                    print "Linking directly into SRCROOT ($srcFile -> $dstFile)\n" if ($DEBUG);
                }
            }
        }
        if ($symlinkUnder) {
            #print "symlinkUnder: srcFile = $srcFile\n";
            if (grep($srcFile =~ /$_/, @symlinkUnderDirs) == 0) {
                print "Copying $srcFile to $dstFile because of symlinkUnder\n" if ($DEBUG);
                $doSymlink = 0;
            }
        }
        if ($isLocalSymlink || $doSymlink) {
            &os::rmFile($dstFile);
            print "\tln -s $srcFile $dstFile\n" if ($VERBOSE);
            if (!symlink($srcFile, $dstFile)) {
                &os::error("Failed to symlink $srcFile to $dstFile");
                return 1;
            }
            return 0;
        }
    }
    
    $alterFile = 0;
    if ($kitFlagType eq "rtv" && $srcFile =~ /\.VER$/) {
        # It's a version file and we're making a runtime
        # release.  We're suppose to replace the first 3
        # letters of that file with RTV.
        # We do this by reading the fromfile into a temp file
        # and editting it's contents there.  We then switch
        # the fromfile to point at the tempfile, so that it
        # gets copied instead.
        $alterFile = 1;
        $alterExpr = '$buf =~ s/^.../RTV/';
    } elsif ($kitFlagType eq "fbc" && $srcFile =~ /\.VER$/) {
        $alterFile = 1;
        $alterExpr = '$buf =~ s/^.../FBC/';
    } elsif ($kitFlagType eq "synerjcl" && $srcFile =~ /\.VER$/) {
        $alterFile = 1;
        $alterExpr = '$buf =~ s/^.../SJC/';
    }
    if ($alterFile) {
        if (!open(ORIG, $srcFile)) {
            &error("Failed to open $srcFile for read: $!");
        } else {
            local($buf);
            $buf = <ORIG>;
            close(ORIG);
            eval $alterExpr;
            # now switch over to the temp file
            $srcFile = &os'TempFile;
            if (!open(OUT, ">$srcFile")) {
                &error("Failed to open $fromfile for write: $!");
            } else {
                print OUT $buf;
                close(OUT);
            }
        }
    }
    
    local($ret) = 0;
    local($srcCRCValue) = 0;
    local($dstCRCValue) = 0;
    $ret = &os'copy_file($srcFile, $dstFile);
    if ($ret) {
        &error("Failed to copy '$srcFile' to '$dstFile'\n");
        return $ret;
    }
    $srcCRCValue = sprintf("%x", &pcrc'CalculateFileCRC($srcFile));
    $dstCRCValue = sprintf("%x", &pcrc'CalculateFileCRC($dstFile));
    if ($srcCRCValue ne $dstCRCValue) {
        &error("Source and desination CRC's are not the same: src='$srcFile'($srcCRCValue) dst='$dstFile'($dstCRCValue)\n");
        return 1;
    }
    $ret = &os::chmod($dstFile, $mode);
    if ($ret) {
        &error(sprintf("Failed to chmod '$dstFile' to '%o': $!\n", $mode));
        return $ret;
    }
    if ($OS == $UNIX || -B $srcFile ) {
        my($srcFileSize, $dstFileSize);
        $srcFileSize = -s $srcFile;
        $dstFileSize = -s $dstFile;
        if ($srcFileSize != $dstFileSize) {
            &error("the source and destination files are of different length ($srcFile ($srcFileSize) vs. $dstFile ($dstFileSize)).");
            return 1;
        }
    }
    if ($doChecksum) {
        print CHECKSUM "$dstFile CRC=$srcCRCValue\n";
    }
    if ($chgrp ne "") {
        &os::chgrp($chgrp, $dstFile);
    }
    return $ret;
}

sub ErrorOnObjNum
    # Assume it's a filemapping object type.
    # Generate the failed file BOM file.
{
    my($objNum) = @_;
    print "Got error on object num $objNum\n" if ($DEBUG);
    if ($bomparse::objType[$objNum] ne "filemapping") {
        print "It's not a filemapping!\n";
        return 1;
    }
    if ($FailBOM eq "") {
        return 0;
    }
    printf FAILBOMOUT ("%s|%s|%s|%s|%s|%s\n", $bomparse::objAttrib1[$objNum],
           $bomparse::objAttrib2[$objNum], $bomparse::objAttrib3[$objNum],
           $bomparse::objAttrib4[$objNum], $bomparse::objAttrib5[$objNum],
           $bomparse::objAttrib6[$objNum]);
    return 0;
}

sub Log
    # Print to the logfile; also print to stdout if $VERBOSE is set or
    # the printIt flag is on.
{
    local($msg, $printIt) = @_;

    if (!defined($printIt)) {
        $printIt = 0;
    }
    if ($VERBOSE || $printIt) {
        print $msg;
    }
    if ($logIt) {
        print LOG $msg;
    }
}

sub convertDirISO9660
{
    local($dirname) = @_;
    if ($dirname eq ".") {
        # non iso9660 characters, but still okay
        return $dirname;
    }
    local($iso_dirname) = "";
    local(@iso_dirlist);
    $dirname =~ tr/a-z/A-Z/;
    foreach $dir (&path'path_components($dirname)) {
        if ($dir =~ /^$PS_IN/) {
            $dir =~ s/^$PS_IN//;
        }
        if (length($dir) > 8) {
            &warning("$dir is longer than 8 characters.\n");
            $dir = substr("$dir", 0, 8);
        }
        if ($dir =~ /[^0-9A-Z_]/) {
            &error("$dir has an illegal non iso9660 character.\n");
            $dir =~ s/[^0-9A-Z_]/X/g;
            &error("changed to $dir\n");
        }
        push(@iso_dirlist, $dir);
    }
    $iso_dirname = &path'mkpathname(@iso_dirlist);
    # print "$dirname -> '$iso_dirname'\n";
    return $iso_dirname;
}

sub convertFileISO9660
{
    local($filename) = @_;
    local($iso_filename) = "";
    local($first) = 1;
    local(@iso_filelist);
    local($file,$ext);
    $filename =~ tr/a-z/A-Z/;
    # print "filename = '$filename'\n";
    ($file,$ext) = ($filename =~ /(^[^\.]+)(.*)/);
    if (length($file) > 8) {
        &warning("$file is longer than 8 characters.\n");
        $file = substr("$file", 0, 8);
    }
    # an extension is 4 characters when counting the . (dot)
    if (length($ext) > 4) {
        &warning("$ext is an extension with more than 3 characters.\n");
        $ext = substr("$ext", 0, 4);
    }
    if ($file =~ /[^0-9A-Z_]/) {
        &error("$filename has an illegal non iso9660 character in the file.\n");
        $file =~ s/[^0-9A-Z]/X/g;
        &error("changed to $file\n\n");
    }
    if ($ext =~ /\.[^0-9A-Z_]/) {
        &error("$filename has an illegal non iso9660 character in the ext.\n");
        $ext =~ s/[^0-9A-Z]/X/g;
        &error("changed to $ext\n\n");
    }
    $iso_filename = $file . $ext;
    # print "$filename -> '$iso_filename'\n";
    return $iso_filename;
}

sub ExplodeBtz
{
    local($btzFile, $dstDir, $minstallFlag) = @_;
    local($errs, $srcCRCValue, $minstallCmd, $fullDstDir);

    $fullDstDir = &path::mkpathname($releaseDir, $dstDir);
    
    $minstallFlag .= " -untgz" if ($minstallFlag !~ /-untgz/);
    $minstallFlag .= " -f 0755" if ($minstallFlag !~ /-f\s+/);
    $minstallFlag .= " -q" if (! $VERBOSE);

    $minstallCmd = "minstall $minstallFlag $btzFile $fullDstDir";

    print "Exploding btz file...\n" if ($VERBOSE);
    print "$minstallCmd\n" if ($DEBUG);
    $errs = system($minstallCmd);
    if ($errs) {
        &error("$minstallCmd failed.");
    }

    if (-d $fullDstDir) {
        open(MINSTALL, "walkdir -f $fullDstDir |") ||
                die "walkdir -f $fullDstDir failed.";
        foreach (<MINSTALL>) {
            ++$totalFiles; ++$filesCopied;
            if ($doChecksum) {
                chomp($_);
                $srcCRCValue = sprintf("%x", &pcrc'CalculateFileCRC($_));
                $_ =~ s/$releaseDir\///;
                print CHECKSUM "$_ CRC=$srcCRCValue\n";
            }
        }
        close(MINSTALL);
    } else {
        &error("$fullDstDir does not exist.");
    }

    return $errs;
}

1;
