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
# @(#)bldres.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


package buildResults;

require "os.pl";
require "codeline.pl";
require "walkdir.pl";

sub main
{
    local(*ARGV, *ENV) = @_;
    local($ret);
    local($errCount) = 0;
    
    &Init;
    $ret = &ParseArgs;
    if ($ret == 2) {
        return 0;
    } elsif ($ret) {
        return $ret;
    }
    &InitPostArgs;

    if ($ScanFiles) {
        local($file);
        foreach $file (keys %ScanFile) {
            &ParseFile($file, $REGRESS_FORTE_PORT, 1, $ScanFile{$file});
        }
    } else {
        $errCount += &ScanLogs(@OPSYS);
    }

    return $errCount;
}

&Init;
sub Init
{
    # variables from other packages
    $p = $'p;
    $OS = $'OS;
    $UNIX = $'UNIX;

    %ScanFile = ();
    $ScanFiles = 0;
    $DEBUG = 0;
    $DEEPDEBUG = 0;
    #$RM_FLAG = "-r";
    $SHOW_HIDDEN = 0;
    $lastLine = "";
    $printTail = 0;
    $IGNORE_MAX = 0;
    $NOFOLD = 0;    #default is to fold
    $NOMARKS = 0;   #default is to print MARK lines

    $DATE_REQUESTED = "";
    $path = "main";
    $path_title = "MAINLINE";
    $REGRESS_FORTE_PORT = $ENV{"REGRESS_FORTE_PORT"};
    $REGRESS_FORTE_PORT = $ENV{"FORTE_PORT"} unless defined($REGRESS_FORTE_PORT);
    $REGRESS_FORTE_PORT = "unknown" unless defined($REGRESS_FORTE_PORT);

    $REMOTE_LOGBASE = $ENV{"REMOTE_LOGBASE"};

    $SRCROOT = $ENV{"SRCROOT"};     #this isn't necessarily defined - check before you use it.
    $TOOLROOT = $ENV{"TOOLROOT"};
    $TOOLROOT = &path::mkpathname($SRCROOT, "tools") if (!defined($TOOLROOT) && defined($SRCROOT));
    $REALPRODUCT = $ENV{"PRODUCT"};
    $REALPRODUCT = "NULL_PRODUCT" if (!defined($REALPRODUCT));

    $HAD_RULES_ARG = 0;     #true if user specifies custom rules
    $RulesFile = &path::mkpathname($TOOLROOT, "lib", "cmn", "buildResults.dat");

    $DefaultScanType = "compile";

    $DefMaxFileSize = 0;   # 0 means no max.
    $DefMaxContext = 8;
    $DefKeepHeader = 0;
    $DefMaxErrors = 150;
    $DefMaxLinesPrinted = 30;
    $DefMaxHeaderLineCount = 5;
}

sub cleanup
{
}

sub ParseArgs
{
    local($arg);

    %ScanFile = ();
    while (defined($arg = shift @ARGV)) {
        if ($arg eq "-prod" || $arg eq "-product") {
            $REALPRODUCT = shift(@ARGV);
        } elsif ($arg eq "-help" || $arg eq "-h") {
            &Usage;
            return 2;
        } elsif ($arg eq "-deepdebug") {
            $DEBUG = 1;
            $DEEPDEBUG = 1;
        } elsif ($arg eq "-debug") {
            $DEBUG = 1;
        } elsif ($arg eq "-nofold") {
            $NOFOLD = 1;
        } elsif ($arg eq "-nomarks") {
            $NOMARKS = 1;
        } elsif ($arg eq "-morerules") {
            local($file) = shift @ARGV;
            if (&LoadRules($file)) {
                print STDERR "BUILD_ERROR: Failed to load $file\n";
                return 1;
            }
        } elsif (lc($arg) eq "-rules") {
            $HAD_RULES_ARG = 1;
            $RulesFile = shift @ARGV;
        } elsif ($arg eq "-tail") {
            $printTail = 1;
        } elsif ($arg eq "-showhidden") {
            $SHOW_HIDDEN = 1;
        } elsif (lc($arg) eq "-ignoremax") {
            $IGNORE_MAX = 1;
        } elsif (lc($arg) eq "-type" || lc($arg) eq "-t") {
            $DefaultScanType = shift @ARGV;
        } elsif ($arg =~ /^-(p|P|h|H|f|d|4|l)(.*)$/) {
            $x = length($2) ? $2 : shift(@ARGV);
            if ($1 eq 'p') {
                $path = $x;
                $path_title = $x;
                &sp::RunUsePath($path, "buildResults");
            } elsif ($1 eq 'f') {
                $ScanFile{$x} = $DefaultScanType;
                $ScanFiles = 1;
            } elsif ($1 eq '4') {
                $ScanFile{$x} = "4gl";
                $ScanFiles = 1;
            } elsif ($1 eq 'l') {
                $ScanFile{$x} = "log";
                $ScanFiles = 1;
            } elsif ($1 eq 'd') {
                $DATE_REQUESTED = $x;
            } else {
                &Usage;
                return 1;
            }
        } elsif ($arg =~ /^-/) {
            print STDERR "unrecognized option, $arg.\n";
            &Usage;
            return 1;
        } else {
            push(@OPSYS, split(':', $arg)) if ($arg ne "");
        }
    }

    return 0;
}

sub InitPostArgs
{
    $PRODUCT = $REALPRODUCT;
    $product_title = $PRODUCT;
    $product_title =~ tr/a-z/A-Z/;

    $PATHNAME = $ENV{'PATHNAME'};
    if  (!defined($PATHNAME)) {
        #assume mainline:
        $PATHNAME="main";
    }

    $CODELINE = $ENV{'CODELINE'};
    if  (!defined($CODELINE)) {
        #assume mainline:
        $CODELINE="main";
    }

    # set up the interim "logpath" location.
    # do not confuse with $path, which is used as an arg to usePathDef.
    if ($PRODUCT eq "forte") {
        #this is the old way, when there was only one product:
        if ($PATHNAME eq "main") {
            $logpath = "";
        } else {
            $logpath = "$PATHNAME";
        }
    } elsif (-d "/regressDirs/$PRODUCT") {
        #this is our first choice for new products.
        if (-d "/regressDirs/$PRODUCT/$PATHNAME") {
            $logpath = "$PRODUCT/$PATHNAME";
        } elsif (-d "/regressDirs/$PRODUCT/$CODELINE") {
            $logpath = "$PRODUCT/$CODELINE";
        } elsif ($PATHNAME eq "main") {
            $logpath = "$PRODUCT";
        } else {
            $logpath = "$PRODUCT/$PATHNAME";
        }
    } else {
        #doesn't exist, but don't go looking in random places:
        $logpath = "$PRODUCT/$PATHNAME";
    }

    printf "logpath=%s\n", $logpath if ($DEBUG);

    if ( ! @OPSYS ) {
        @OPSYS = &cl::forte_ports;
        print "OPSYS=(" . join(",", @OPSYS) . ")\n" if ($DEBUG);
    }

    if ($HAD_RULES_ARG == 0) {
        #load product based rules if present:
        my ($tmp) = &path::mkpathname($TOOLROOT, "lib", "cmn", $PRODUCT . "_buildResults.dat");

        if (-r $tmp) {
            printf("Using product rules in '%s'\n", $tmp) if ($DEBUG);
            $RulesFile = $tmp;    #use PRODUCT RULES
        } else {
            printf("No readable product rules found in '%s'\n", $tmp) if ($DEBUG);
        }
    }

    if (&LoadRules($RulesFile)) {
        print "Failed to LoadRules completely.  Aborting.\n";
        return 1;
    }

    return 0;
}
    
sub Usage
{
        print <<"!";
Usage: $p [-help] [-f log_file] [-p path] [-product name] [-d date]
          [-nofold] [-nomarks] [-type default_scan_type]
          [-rules rule_file] [-showhidden] [-ignoremax]
          [platform ...]
    
 Scan for build progress and errors.

Options:
 -help       Display this usage messages.
 -f log_file Only look in <log_file> for results.
 -p  path    Run usePathDef in <path>.  Defaults to mainline.
 -product name
             Use <name> as the name of the product.
 -d  date    Only look for results on <date>, which must match
             a dated log directory.
 -nofold     Don't fold the results to 80 columns
 -nomarks    Don't print MARK lines. Default prints them first.
 -type default_scan_type
             Change the default scanning rule.
 -rules rule_file
             Use <rule_file> instead of \$TOOLROOT/lib/cmn/buildResults.dat
 -showhidden show errors that are normally supressed.
 -ignoremax  ignore maximum number of errors limit

 platform ...
             Only show results for these platforms.  Default is to
             show results for all platforms.

Examples:
 $p solsparc
 $p -p maint rs6000 dgux88k
 $p -f bad_log
!
}

sub LoadRules
#returns 0 if no errors
{
    local($ruleFile) = @_;
    local($line, $mode, $varName, $value, $buildResultsType, $maxContext,
          $maxErrors, $maxLinesPrinted, $maxHeaderLineCount, $expr,
          $continueLogicalLine);
    local($lineNumber) = 0;
    local(@rules);

    print "Loading rules from $ruleFile\n" if ($DEBUG);
    if (!open(RULES, $ruleFile)) {
        print STDERR "BUILD_ERROR: $p (buildResults.pl): Failed to open '$ruleFile' for read: $!\n";
        return 1;
    }

    $mode = "vars";
    while (defined($line = <RULES>)) {
        chop($line);
        ++$lineNumber;
        if ($mode eq "vars") {
            $line =~ s/#.*//;
            if ($line =~ /([a-zA-Z0-9_]+)\s*=\s*(.*)/) {
                $varName = $1;
                $value = $2;
                $varName =~ tr/A-Z/a-z/;
                print "varName = '$varName' value = '$value'\n" if ($DEEPDEBUG);
                if ($varName eq "buildresults_type") {
                    $buildResultsType = $value;
                    $maxFileSize = $DefMaxFileSize;
                    $maxContext = $DefMaxContext;
                    $keepHeader = $DefKeepHeader;
                    $maxErrors = $DefMaxErrors;
                    $maxLinesPrinted = $DefMaxLinesPrinted;
                    $maxHeaderLineCount = $DefMaxHeaderLineCount;
                } elsif ($varName eq "maxfilesize") {
                    $maxFileSize = $value;
                } elsif ($varName eq "maxcontext") {
                    $maxContext = $value;
                } elsif ($varName eq "keepheader") {
                                        if ($value == 0) {
                                            $keepHeader = 0;
                                        } else {
                                            $keepHeader = 1;
                                        }
                } elsif ($varName eq "maxerrors") {
                    $maxErrors = $value;
                } elsif ($varName eq "maxlinesprinted") {
                    $maxLinesPrinted = $value;
                } elsif ($varName eq "maxheaderlinecount") {
                    $maxHeaderLineCount = $value;
                } else {
                    print STDERR "BUILD_ERROR: $p: unrecognized variable in assignment: '$line' at line \#$lineNumber\n";
                }
            } else {
                $line =~ tr/A-Z/a-z/;
                if ($line eq "begin rules") {
                    $MaxFileSizeTable{$buildResultsType} = $maxFileSize;
                    $MaxContextTable{$buildResultsType} = $maxContext;
                    $KeepHeaderTable{$buildResultsType} = $keepHeader;
                    $MaxErrorsTable{$buildResultsType} = $maxErrors;
                    $MaxLinesPrintedTable{$buildResultsType} = $maxLinesPrinted;
                    $MaxHeaderLineCount{$buildResultsType} = $maxHeaderLineCount;
                    $mode = "rules";
                    $continueLogicalLine = 0;
                    @rules = ();
                } elsif ($line =~ /^\s*$/) {
                    # just a bunch of whitespace
                } else {
                    print STDERR "BUILD_ERROR: $p: parse error: '$line' at line \#$lineNumber\n";
                    return 1;
                }
            }
        } elsif ($mode eq "rules") {
            $line =~ s/^\s+//;
            $line =~ s/^([^:#]*)#.*/$1/;
            if ($continueLogicalLine || $line =~ /:/) {
                if ($line =~ s/\\\s*$//) {
                    # We've got a backslash at the end, keep reading
                    # lines until we no longer have a backslash.
                    if ($continueLogicalLine) {
                        $logicalLine .= " " . $line;
                    } else {
                        $continueLogicalLine = 1;
                        $logicalLine = $line;
                    }
                } else {
                    if ($continueLogicalLine) {
                        $continueLogicalLine = 0;
                        $logicalLine .= " " . $line;
                        push(@rules, $logicalLine);
                    } else {
                        push(@rules, $line);
                    }
                }
            } elsif ($line =~ /^end rules/i) {
                # need to compile all of the rules
                $expr = &CompileErrorTests(*rules);
                if ($expr eq "") {
                    print STDERR "BUILD_ERROR: $p: compiling the rules for $buildResultsType failed at line \#$lineNumber.\n";
                    return 1;
                }
                $ErrorsExprTable{$buildResultsType} = $expr;
                $RulesTable{$buildResultsType} = join($;, @rules);
                $mode = "vars";
            } elsif ($line =~ /include (.*)/i) {
                $rulesToInclude = $1;
                if (!defined($RulesTable{$rulesToInclude})) {
                    print STDERR "BUILD_ERROR: $p: $rulesToInclude isn't defined at line \#$lineNumber\n";
                    return 1;
                }
                push(@rules, split($;, $RulesTable{$rulesToInclude}));
            } elsif ($line =~ /^\s*$/) {
                # just a bunch of whitespace
            } else {
                print STDERR "BUILD_ERROR: $p: Invalid rule '$line' at line \#$lineNumber\n";
                return 1;
            }
        } else {
            print STDERR "BUILD_ERROR: $p: program error mode = '$mode' at line \#$lineNumber\n";
            $mode = "vars";
        }
    }

    close(RULES);
    return 0;
}

sub CompileErrorTests
{
    local(*errorList) = @_;
    local($test, $res, $expr, $exprNumber);
    local($result) = "";

    $exprNumber = 0;
    $result = "RESULT: { ";
    if ($OS == $UNIX) {
        $result .= "study;";
    }
    $result .= "\n";
    foreach $test (@errorList) {
        ($res, $expr) = split(":", $test, 2);
        if (!defined($expr)) {
            print STDERR "Invalid rule syntax in '$test'\n";
            return "";
        }
        if ($SHOW_HIDDEN && $res eq "hide") {
            $res = "error";
        }
        if ($DEBUG) {
            if ($res eq "error") {
                local($quotedExpr) = $expr;
                if (length($quotedExpr) > 42) {
                    $quotedExpr = substr($quotedExpr, 0, 62) . "...";
                }
                $quotedExpr = "\"" . $quotedExpr . "\"";
                $quotedExpr = eval "quotemeta(\$quotedExpr)";
                $result .= "if ($expr) {print \"\'\$_\' matched expression number $exprNumber ($quotedExpr) (BUILDRESULTS_TYPE=\$BuildResultsType)\\n\"; \$result = \"$res\"; last RESULT;}\n";
            } else {
                if ($DEEPDEBUG) {
                    $result .= "if ($expr) {print \"$exprNumber \"; \$result = \"$res\"; last RESULT;}\n";
                } else {
                    $result .= "if ($expr) {\$result = \"$res\"; last RESULT;}\n";
                }
            }
        } else {
            $result .= "if ($expr) {\$result = \"$res\"; last RESULT;}\n";
        }
        ++$exprNumber;
    }
    if ($DEEPDEBUG) {
        $result .= "print \"e \"; ";
    }
    $result .= "\$result = \"good\"; };\n";
    if ($DEEPDEBUG) {
        print $result;
    }
    return $result;
}

sub ScanLogs
{
    local(@OPSYS) = @_;
    local($logFoundCount, $os);
    $logFoundCount = 0;

    foreach $os (sort @OPSYS) {
        next if ($os =~ /^[ \t\n]*$/);
        # Set log file name.


        if ($logpath eq "") {
            $log_dir = "/regressDirs/$os/regress/log";
        } else {
            $log_dir = "/regressDirs/$logpath/$os/regress/log";
        }

        if (! -d $log_dir) {
            if (defined($REMOTE_LOGBASE) && -d "$REMOTE_LOGBASE/regress/log") {
                $log_dir = "$REMOTE_LOGBASE/regress/log";
            } elsif (defined($SRCROOT) && -d "$SRCROOT/regress/log") {
                $log_dir = "$SRCROOT/regress/log";
            } elsif (&cl::which_machine($os) eq "NULL") {
                print "Skipping os $os - no build machine and no \$SRCROOT/regress/log dir.\n" if ($DEBUG);
                next;
            }
        }

        if ($DATE_REQUESTED eq "") {
            if (-e "$log_dir/../.date") {
                $dateStr = `cat $log_dir/../.date`;
                ($date) = ($dateStr =~ /^([a-zA-Z0-9_]*)/);
            } else {
                $date = "";
            }
        } else {
            $date = $DATE_REQUESTED;
        }

        $log_file = &cl::nightbuild_log($os, $date);
        # If the log file is found in the dated directory, then that one should
        # take precedence.
        if (-e "$log_dir/$date/$log_file" && ! -B "$log_dir/$date/$log_file") {
            $log_file = "$date/$log_file";
            print "Using $log_file as primary log file.\n";
        }
        print "$os: $log_dir/$log_file\n" if ($DEBUG);
        if (-e "$log_dir/$log_file") {
            ++$logFoundCount;
            &ParseFile("$log_dir/$log_file", $os, 1, "compile");
            if ($date ne "" && -d "$log_dir/$date") {
                @otherLogFiles = &walkdir'FindFiles("$log_dir/$date", '\.log$');
                #print "otherLogFiles: @otherLogFiles\n";
                foreach $log (@otherLogFiles) {
                    next if ($log eq "$log_dir/$log_file");
                    if ($log =~ /\/forte\//) {
                        &ParseFile($log, $os, 0, "regress");
                    } else {
                        &ParseFile($log, $os, 0, "log");
                    }
                }
            }
        } else {
            print "$log_dir/$log_file is not readable\n" if ($DEBUG);
            print "\nUnable to find any valid logs for $os\n";
        }
    }
    
    if ($logFoundCount == 0) {
        print "Unable to find any log files in this path ($path) to look at.\n";
        print "You might try running with debugging on (-debug) to get an idea\n";
        print "of where it's looking and why it's not finding anything.\n";
    }

    return 0;
}

sub ParseFile
{
    local($log_file, $os, $is_primary_log, $BuildResultsType) = @_;
    if (!defined($date)) {
        $date = "";
    }
    if (!defined($ErrorsExprTable{$BuildResultsType})) {
        print "warning: BUILDRESULTS_TYPE $BuildResultsType has not been defined\n";
        if (defined($ErrorsExprTable{"compile"})) {
            $BuildResultsType = "compile";
        } else {
            return 1;
        }
    }
    $errorsExpr = $ErrorsExprTable{$BuildResultsType};
    $maxFileSize = $MaxFileSizeTable{$BuildResultsType};
    $maxContext = $MaxContextTable{$BuildResultsType};
    $keepHeader = $KeepHeaderTable{$BuildResultsType};
    $maxErrors = $MaxErrorsTable{$BuildResultsType};
    $maxLinesPrinted = $MaxLinesPrintedTable{$BuildResultsType};
    $maxHeaderLineCount = $MaxHeaderLineCount{$BuildResultsType};
    &PrintLine("BUILDRESULTS_TYPE $BuildResultsType (maxFileSize = $maxFileSize maxContext=$maxContext keepHeader=$keepHeader maxErrors=$maxErrors maxLinesprinted=$maxLinesPrinted maxHeaderLineCount=$maxHeaderLineCount)") if ($DEBUG);
    local($LOGFILE);
    local(@logArray);
    print "parse_file: $log_file $os $is_primary_log\n" if ($DEBUG);

    if ($log_file ne "-" && ! -e $log_file) {
        &PrintLine("$log_file doesn't exist.");
        return;
    }

    if ($is_primary_log) {
        print "\n$product_title $path_title BUILD RESULTS on $os from $date ";
        # Print the $machine part (and the newline) later after we
        # have scanned for the log telling us what machine it was.
    }
    
    my($size) = (-s $log_file);
    if ($size == 0) {
        # no errors in a zero length file.
        print "\n" if ($is_primary_log);
        return 0;
    }
    if ($maxFileSize > 0 && $size > $maxFileSize) {
        print "\n" if ($is_primary_log);
        &PrintLine("BUILD_WARNING: $log_file is too big to scan ($size > $maxFileSize).");
        return 0;
    }
    if (-B $log_file) {
        print "\n" if ($is_primary_log);
        &PrintLine("BUILD_WARNING: $log_file is binary.  Not scanning.");
        return 0;
    }
    open(LOGFILE, "$log_file") || warn "$log_file not found";
    @logArray = <LOGFILE>;
    close(LOGFILE);
    local($logArraySize) = $#logArray+1;
    if ($is_primary_log) {
        my($line, $ii, $machine);
        $machine = "";
        # Scan the first 32 lines looking for our special token that says
        # who built this log.
        for ($ii = 0; $ii < 32 && $ii < $logArraySize; ++$ii) {
            $line = $logArray[$ii];
            if ($line =~ /^BUILDRESULTS_HOSTNAME\s*=(.*)/) {
                $machine = $1;
                $machine =~ s/\s+//g;
            }
        }
        if ($machine eq "") {
            $machine = &cl::which_machine($os);
        }
        print "($machine)\n";
        
                if ($NOMARKS == 0) {
                    my(@marks);
                    @marks = grep(/MARK/, @logArray);
                    foreach (@marks) {
                            &PrintLine("    $_");
                    }
                    undef(@marks);
                }
    }
    local($first_of_file) = 1;
    local($printUntilBlank) = 0;
    local($ignoreUntilBlank) = 0;
    local($header) = "";
    local($prevHeader) = "";
    local($headerLineNumber) = -1;
    local($headerLineCount) = 0;
    local($errorCount) = 0;
    local($lineNumber) = 0;
    local($majorHeader) = "";
    local($linesPrinted) = 0;
    local($hidden) = 0;
    local($cmd, $origCmd);
    # Build up the command so that we may put $CompileErrorsExpr right
    # in the middle of it.  That way, we eval the whole thing once.
    # Make sure you don't use any single quotes "'" inside of $origCmd
    # as that will end $origCmd.
    $origCmd = '
        for (; $lineNumber < $logArraySize; ++$lineNumber) {
            $logArray[$lineNumber] =~ s/\n//;
            $logArray[$lineNumber] =~ s///;
            $_ = $logArray[$lineNumber];
            #print "lineNumber = $lineNumber _ = $_\n";
            if ($ignoreUntilBlank) {
                if (/^\s*$/ || /^=+/ || /MARK/ || /BUILD_ERROR/) {
                    --$ignoreUntilBlank;
                    $header = $_;
                    $headerLineNumber = $lineNumber;
                    $headerLineCount = 1;
                }
            } elsif (/BUILDRESULTS_TYPE\s*=(.*)/) {
                $type = $1;
                $type =~ s/\s+//g;
                if ($type ne $BuildResultsType) {
                    if (defined($ErrorsExprTable{$type})) {
                        $BuildResultsType = $type;
                        $errorsExpr = $ErrorsExprTable{$BuildResultsType};
                        $maxFileSize = $MaxFileSizeTable{$BuildResultsType};
                        $maxContext = $MaxContextTable{$BuildResultsType};
                        $keepHeader = $KeepHeaderTable{$BuildResultsType};
                        $maxErrors = $MaxErrorsTable{$BuildResultsType};
                        $maxLinesPrinted = $MaxLinesPrintedTable{$BuildResultsType};
                        $maxHeaderLineCount = $MaxHeaderLineCount{$BuildResultsType};
                        print "BUILDRESULTS_TYPE $BuildResultsType (maxContext=$maxContext keepHeader=$keepHeader maxErrors=$maxErrors maxLinesprinted=$maxLinesPrinted maxHeaderLineCount=$maxHeaderLineCount)\n" if ($DEBUG);
                        $repeatCmd = 1;
                        # Abort this eval, so that we can come back in
                    # with another set of rules.
                        ++$lineNumber;
                        last;
                    } else {
                        print "warning: BUILDRESULTS_TYPE $type has not been defined\n";
                    }
                }
            } else {
                CheckForError;
                print "$_ ->($lineNumber) $result\n" if ($DEEPDEBUG);
                print "headerLineNumber = $headerLineNumber\n"if ($DEEPDEBUG);
                if ($result eq "good") {
                    if ($printUntilBlank) {
                        if ($linesPrinted == $maxLinesPrinted) {
                            &PrintLine("... (maximum lines reached for this error)\n");
                            ++$linesPrinted;
                            $printUntilBlank = 0;
                        } elsif ($linesPrinted > $maxLinesPrinted) {
                        } else {
                            &PrintLine("    $_");
                            ++$linesPrinted;
                            if ($header eq "") {
                                # Since we are printing things out and
                                # there is no header, we do not want to
                                # repeat the same lines in context
                                # ($headerLineNumber is how context is
                                # figured out).
                                $headerLineNumber = $lineNumber;
                            }
                        }
                    }
                } elsif ($result eq "hide") {
                    ++$hidden;
                } elsif ($result eq "header") {
                    $header = $_;
                    $headerLineNumber = $lineNumber;
                    $headerLineCount = 1;
                    $printUntilBlank = 0;
                } elsif ($result eq "contheader") {
                                        #print "contheader:\n";
                                        #print "  headerLineCount = $headerLineCount\n";
                                        #print "  maxHeaderLineCount = $maxHeaderLineCount\n";
                                        #print "  header = \"$header\"\n";
                                        #print "  prevHeader = \"$prevHeader\"\n";
                    if ($headerLineCount == $maxHeaderLineCount) {
                        $header .= "\n    $_";
                        ++$headerLineCount;
                        $prevHeader = $header . "\n    ...";;
                    } elsif ($headerLineCount > $maxHeaderLineCount) {
                        $header = $prevHeader . "\n    $_";
                    } else {
                        $header .= "\n    $_";
                        ++$headerLineCount;
                    }
                    # print "header = x${header}x\n" if ($DEEPDEBUG);
                    $printUntilBlank = 0;
                } elsif ($result eq "start major header") {
                    $majorHeader = $_;
                    $printUntilBlank = 0;
                } elsif ($result eq "finish major header") {
                    $majorHeader = "";
                    $printUntilBlank = 0;
                } elsif ($result eq "ignoreUntilBlank") {
                    $ignoreUntilBlank = 1;
                } elsif ($result eq "error") {
                    # its an error
                    ++$errorCount;
                    if (! $IGNORE_MAX && $errorCount == $maxErrors) {
                        &PrintLine("Maximum error limit reached.");
                    } elsif ($IGNORE_MAX || $errorCount < $maxErrors) {
                        if ($first_of_file) {
                            $first_of_file = 0;
                            if (! $is_primary_log) {
                                print "\n";
                                &PrintLine("*** LOG $log_file\n");
                            }
                        }
                        print "\n";
                        if ($majorHeader ne "") {
                            &PrintLine("... $majorHeader ...");
                        }
                        &PrintLine("$header\n");
                        print "headerLineNumber = $headerLineNumber\n"if ($DEEPDEBUG);
                        local($highLineNumber) = $lineNumber;
                        local($lowLineNumber) = $headerLineNumber + 1;
                        if ($highLineNumber - $lowLineNumber >= $maxContext) {
                            $lowLineNumber = $lineNumber - $maxContext;
                            &PrintLine(".....\n");
                        }
                        local($i);
                        print "context from $lowLineNumber to $highLineNumber\n" if ($DEEPDEBUG);
                        for ($i = $lowLineNumber; $i <= $highLineNumber; ++$i) 
                        {
                            &PrintLine("    $logArray[$i]\n");
                        }
                        &PrintLine("^^^^^^^\n");
                                                if ($keepHeader == 0) {
                                                    # print "reset header\n";
                                                    $header = "";
                                                }
                        $headerLineNumber = $lineNumber;
                        print "headerLineNumber = $headerLineNumber\n"if ($DEEPDEBUG);
                        $printUntilBlank = 1;
                        $linesPrinted = 0;
                    }
                } else {
                    print STDERR "Unknown result $result\n";
                }
            }
        }
    ';
    do {
        $cmd = $origCmd;
        $cmd =~ s/CheckForError/$errorsExpr/;
        print "cmd = '$cmd'\n" if ($DEEPDEBUG);
        print "lineNumber = $lineNumber \$\#logArray = $logArraySize\n" if ($DEBUG);
        $repeatCmd = 0;
        #print "before repeatCmd = $repeatCmd\n";
        eval $cmd;
        if ($@ ne "") {
            print "ERROR: $@\n";
        }
        print "after eval: repeatCmd = $repeatCmd\n" if ($DEBUG);
    } while ($repeatCmd);

    if ($hidden != 0) {
        print "$hidden hidden errors in log.\n";
    }

    if ($printTail) {
        local($ii);
        print "\n";
        &PrintLine("------------ tail of $log_file\n");
        $ii = $logArraySize-10;
        if ($ii < 0) {
            $ii = 0;
        }
        for (; $ii < $logArraySize; ++$ii) {
            &PrintLine($logArray[$ii] . "\n");
        }
    }
    undef(@logArray);
    return 0;
}

sub isError
{
    local($line, $os, $is_primary_log) = @_;
    local($result);

    $_ = $line;
    $header = "";
    eval $ErrorsExprTable{"compile"};
    return $result;
}

sub isLogError
{
    local($line, $os, $is_primary_log) = @_;
    local($result);

    $_ = $line;
    $header = "";
    eval $ErrorsExprTable{"log"};
    return $result;
}

sub PrintLine
    # If this line is a dup of the previous line, don't print it.
    # Fold the line down to 80 chars or less.
    # <=> open(FOLD, "|fold | uniq | grep -v '^\\.\$'")
{
    local($line) = @_;

    if ($line eq $lastLine) {
        print "PrintLine: skipping duplicate line\n" if ($DEEPDEBUG);
        return;
    }
    $lastLine = $line;

    # print "PrintLine: line = '$line'\n" if ($DEEPDEBUG);
    if ($NOFOLD) {
        print $line;
    } else {
        $line =~ s/\n$//;
        local($ll);
        while ($line ne "") {
            ($ll, $line) = ($line =~ /^[\n]*(.{0,80})((.|\n)*)/);
            next if ($ll eq ".");
            print $ll . "\n";
        }
    }
}

sub squawk
{
    if (1 > 2) {
        *OS = *OS;
        *UNIX = *UNIX;
        *printUntilBlank = *printUntilBlank;
        *RM_FLAG = *RM_FLAG;
        *linesPrinted = *linesPrinted;
        *errorCount = *errorCount;
        *ignoreUntilBlank = *ignoreUntilBlank;
        *headerLineCount = *headerLineCount;
        *first_of_file = *first_of_file;
        *headerLineNumber = *headerLineNumber;
        *majorHeader = *majorHeader;
        *header = *header;
    }
}

1;
