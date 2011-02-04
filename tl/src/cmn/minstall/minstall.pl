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
# @(#)minstall.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# Copyright 2010 Russ Tremain.  All Rights Reserved.
#
# END_HEADER - DO NOT EDIT
#

# minstall - portable installation utility for makefiles.
# "Mighty Install"!!!! 
 
package minstall;

$DEBUG = 0;
$TEST = 0;
$QUIET = 0;
$TRANSACTION_LOGNAME = "transact.log";
$bTRANSACTION_LOGNAME = "btransact.log";
$PRLSKEL = "prlskel";

$OPTION_NOPERLIO = 0;   #add workaround for PERLIO bug for scope of current "skel" op
#this string must prepend the sh call:
$OPTION_NOPERLIO_FIX = 'export PERLIO && PERLIO=stdio && ';

#################################### MAIN #####################################

require "os.pl";
require "path.pl";
require "vars.pl";
require "pcrc.pl";
require "url.pl";
require "instgram.pl";
require "suffix.pl";
require "transact.pl";

require "localtxt.pl";

&init();

sub main
{
	local (*ARGV, *ENV) = @_;
	local ($status) = 0;
	
	$status = &parse_args();
	if ($status != 0) {
		return (0) if ($status == 2);	#not an error to ask for help.
		return $status;
	}
	&init_env;
	if (&check_args() != 0) {
		return 1;
	}

	if ($HAVE_MAP) {
		if (&ig::init($MAPFILE)) {
			printf STDERR ("%s: can't initialize parse for file %s\n", $p, $MAPFILE);
			return(1);
		}
		# Parse the grammar.
		# When it's finished parsing a declaration in the install map, it
		# will call &install on files which are in both the install map and
		# @FILES.  The files installed through here are removed from @FILES.
		if (&ig'G) {
			printf STDERR ("\n%s: failed to complete parse of %s\n", $p, $MAPFILE);
			return(1);
		}
	}

	###########
	#check/init CVSROOT if -cvsdest:
	###########
	if ($CVSDEST) {
		#check that CVS distribution repository exists, and if not, create it:
		#TODO:  allow user to pass in config file, module defs.
		if (!&cvsrepos_okay($BASE)) {
			print "\nBUILD_ERROR: $p: CVS repository is not correctly configured in $BASE\n";
			return(1);
		}
	}

	# install any files not handled by the install map
	print "\n______ Now installing after the map _______\n" if ($DEBUG);
	foreach $ff (@FILES) {
		# If a file was installed through the install map, then it's
		# entry in FILE_IN_INSTALLMAP is > 0
		next if ($FILE_IN_INSTALLMAP{$ff});
		
		if ((! $IGNORE_MAP_ERRORS && $HAVE_MAP)) {
			print "Installing $ff NOT through the install map.\n";
			print "You might have a typo in your install map.\n";
		}
		if ($OPERATION eq "untgz" || $OPERATION eq "untar" ||
			$OPERATION eq "tgz") {
			# In an untar or untgz, the destination "file" is really
			# the directory to explode into (miuns $DEST).
			&install($ff, $MODE, $DEST, "&", "", ("."));
		} else {
			## NOTE - if we're not installing thru a map, then @FILES contains full pathnames,
			## including DEST.  So extract the tail so we can don't duplicate DEST.
			## this fix allows relative pathnames for DEST on the command line.  RT 11/2/99
			&install($ff, $MODE, $DEST, "&", "", (&path'tail($ff)));
		}
	}

	local($errorCount) = 0;
	print "______ Now Performing OPERATION = '$OPERATION' opNum = $opNum _____\n" if $DEBUG;
	if ($OPERATION eq "install") {
		$errorCount += &doInstall;
	} elsif ($OPERATION eq "uninstall") {
		$errorCount += &doUninstall;
	} elsif ($OPERATION eq "diff") {
		$errorCount += &doDiff;
	} elsif ($OPERATION eq "untar" || $OPERATION eq "untgz") {
		$errorCount += &doUntarUntgz;
	} elsif ($OPERATION eq "tgz") {
		$errorCount += &doTgz;
	} elsif ($OPERATION eq "rmtgz") {
		$errorCount += &doRmtgz;
	} else {
		print STDERR "ERROR: unknown operation: $OPERATION.\n";
		return 1;
	}

	### check for case in which we are installing the destination dir only:
	if ($#FILES < 0) {
		&installDirOnly($DEST);
	}


	if (! $TEST) {
		if ($TRANSACTION_LOG && (keys %TRANSACTION_LIST) > 0) {
			#$errorCount += &write_transactions($TRANSLOG_DIR, "minstall",
			#								   @TRANSACTION_LIST);
			#$transact::DEBUG = 1;
			my($dir);
			foreach $dir (sort keys %TRANSACTION_LIST) {
				my($transLog) = &path::mkpathname($dir, $TRANSACTION_LOGNAME);
				print "\nUpdating transaction log $transLog\n" unless ($QUIET);
				if ($bTRANSACTION_LOG) {
					my($btransLog) = &path::mkpathname($dir, $bTRANSACTION_LOGNAME);
					print "bTRANSACTION_LOG is on, btransLog=$btransLog\n" if ($DEBUG);
					if (! -e $btransLog) {
						$errorCount += &transact::CreateTransactLog($btransLog);
					}
				}
			}
			$errorCount +=
				&transact::AppendPullTransaction($TRANSACTION_LOGNAME,
												 $p, $SERVER_TARGET != $KSHARE,
												 0, *TRANSACTION_LIST);
			%TRANSACTION_LIST = ();
		}
	}
	return $errorCount;
}

sub init
{
	# bring over variables from main
	$DOT = $'DOT;
	$UPDIR = $'UPDIR;
	$PS_OUT = $'PS_OUT;
	$CPS = $'CPS;
	$OS = $'OS;
	$UNIX = $'UNIX;
	$MACINTOSH = $'MACINTOSH;
	$NT = $'NT;
	$p = $'p;

    # What operation should we perform on all of these files; currently,
    # install or uninstall.
	$OPERATION = "install";
    # Whether or not to do any validity checking on the source file.  For
    # instance, perl programs will have their syntax checked.
	$CHECK = 0;
	# If the "check" option is enabled, allow for perl syntax checking
	# files with perl extentions.
	$DO_PERL_CHECK = 0;
	# The depreciated "-perl4check" option uses the below variable.
	# Keep for backward compatibility,
	$PERL4CHECK = 0;
    # Whether or not to print out a map of where things got installed.
	$PRINTMAP = 0;
    # Whether or not to verify that the install map is consistent with the
    # command line arguments.
	$CONSISTENT = 1;

	# init some variables
	%TRANSACTION_LIST = ();
	$opNum = 0;
	$UPDATE = 0;
	$UPDATEDIFF = 0;
	$BATROOT = "%TOOLROOT%\\bin\\cmn";
	%VARDEFS = %ENV;

	&localtxt'init;

	%CMD_ALIAS_LIST = (
		"cp", 'cp $1 $2 ; chmod $3 $2',
	);
}

sub init_env
# This should be run AFTER running ParseArgs, as the argument might
# change the environment variables.
{
	$TRANSLOG_DIR = $ENV{'TRANSLOG_DIR'};
	if (defined($TRANSLOG_DIR)) {
		$TRANSLOG_DIR = &path::mkportablepath($TRANSLOG_DIR) 
	} else {
		$TRANSLOG_DIR = "";
	}

	$TARGET_OS = $ENV{"TARGET_OS"};
}

sub cleanup
{
	# This is our chance to clean up system resources.
	if ($DEBUG) {
		&'dump_inc;

		local($depth) = 0;
		do {
			my($package, $filename, $line) = caller($depth);
			if (!defined($package)) {
				return;
			}
			print(STDERR "$0 ".__LINE__.": FYI: This subroutine was called by $package, $filename, $line.\n");
			++$depth;
		} while (1);
	}
}

################################# SUBROUTNES ##################################

# when the input file was modified
$srcFileModTime = -1;
$dstFileModTime = -1;

sub install
# Prepare to install <filename> into each directory named in the
# <dir_list> with permissions <mode>.  We actually stuff it away into
# an array and then process everything later.
# <dir_list> is a list of directories which will be offset by <base>.
# <mode> is an octal string.
# <procedures> is an "&" separated string of little procedures to run
# (like skel).
# <cmdString> is the command to run instead of just copying (doesn't
# work too well with the <procedures>).
# Create the destination directory if $FORCE_DIR is set.
{
	local($filename, $mode, $base, $procedures, $cmdString, @dir_list) = @_;
	
	print "$filename $mode base = $base (" . join(", ", @dir_list) . ")\n" if ($DEBUG);
	print "DEST = $DEST\n" if ($DEBUG);

	if ($cmdString ne "") {
		if (substr($cmdString, 0, 1) eq "[") {
			$cmdString =~ s/^\[//;
		} else {
			# it's an alias of some sort
			$cmdString = &cmd_alias($cmdString);
		}
	}
#&install($ff, $MODE, $DEST, "&", "", ($ff));
	foreach $mapped_file (@dir_list) {
		$instBase{$opNum} = &path::mkportablepath($base);
		$instSrc{$opNum}  = &path::mkportablepath($filename);
		$instDst{$opNum}  = &path::mkportablepath($mapped_file);
		$instMode{$opNum} = $mode;
		$instProcedures{$opNum} = $procedures;
		$instCmdString{$opNum}  = $cmdString;
		$instDone{$opNum} = 0;
		++$opNum;
		# print "opNum = $opNum\n";
	}	
}

sub parse_proc_spec
#parse the filter proc specification into a procedure name and an argument list
#   example INPUT:	'fooproc#!#"a","b","c"'
#          OUTPUT:  ('fooproc', '"a","b","c"')
#
{
	local ($txt, *procname, *argstr) = @_;

	$procname = $argstr = "";	#result parameters.

	if ($txt =~ /#!#/) {
		@rec = split('#!#', $txt);
		$procname = $rec[0];
		$argstr = $rec[1] if ($#rec > 0);
	} else {
		$procname = $txt;
		$argstr = "";
	}
}

sub installDirOnly
#we've been asked to create a destination directory with nothing in it.
{
	local ($dstDir) = @_;
	local ($errorCount) = 0;

	$os'DEBUG = 1 if ($DEBUG);
	if (&os'createdir($dstDir, $DIR_MODE)) {
		print STDERR "BUILD_ERROR: $p: failed to create $dstDir\n";
		++$errorCount;
	}

	#if transaction loggin, add transaction for the dir itself:
	if ($TRANSACTION_LOG) {
		&AddChangeTransaction($dstDir, "d");
	}

	return $errorCount;
}


sub doInstall
# Copy a file from the source directory to the destination
# directory, perform any munges as specified by procedures.
#
# returns non-zero if error.
#
# Added url name decoding.  Error messages must use printable names. RT 11/7/96
{
	local($i, $srcFile, $dstFile, $cvsdstFile, $pdstFile, $dstDir, $pdstDir, $procedures,
		  $mode, $crcValue,
		  $cmdString, $base, $wproc, $when);
	local($pre_result, $procname, @procargs, $argstr, $tmp, $cmd);
	local(@preProcedures, @postProcedures, @duringProcedures);
	local($errorCount) = 0;

	file: for ($i = 0; $i < $opNum; ++$i) {
		next if $instDone{$i};
		$srcFile = &getSrcFile($i);
		$pdstFile = &getDstFile($i);	#printable form
		$pdstDir  = &getDstDir($i);		#printable form
		$dstFile = &url'name_decode($pdstFile);
		$cvsdstFile = $dstFile . ",v";
		$dstDir  = &url'name_decode($pdstDir);
		$procedures = $instProcedures{$i};
		$mode = oct($instMode{$i});
		$cmdString = $instCmdString{$i};
		$base = $instBase{$i};

		print "$srcFile - $dstFile mode = oct($mode) cmdString = '$cmdString' base = '$base'\n" if ($DEBUG);
#printf "\tQUIET=%d\tVERBOSE=%d\nsrcFile=%s\n\tdstFile=%s\n\tcvsdstFile=%s\n\tmode=%o\n\tcmdString=%s\n\tbase=%s\n", $QUIET, $VERBOSE, $srcFile, $dstFile, $cvsdstFile, $mode, $cmdString, $base;

		$GMODE = $mode;		#save mode for option processors

		# Compare the destination directory to the global destination
		# directory, but only if there's a map.
		if ($CONSISTENT && $HAVE_MAP && ! $IGNORE_MAP_ERRORS) {
			# print "dstdir = $dstdir\n" if ($DEBUG);
			if (&path'cmp($DEST, $dstDir)) {  #'
				print STDERR "\nWARNING: the destination directory from the command line\n";
				print STDERR "does not match the install map's destination directory\n";
				print STDERR "from command line: $DEST\n";
				print STDERR " from install map: $dstDir\n";
				print STDERR "         filename: $srcFile\n";
			}
		}


		if ($PRINTMAP) {
			printf("%s\t%s\t%s\t%s\t%o\n", $TARGET_OS || "-",
				   $srcFile, &path'tail($pdstFile), &path'head($pdstFile),
				   $mode);
			next;
		}

		lstat($dstFile);
		if (-e _ && (-d _)) {
			print "Warning: The destination file, $pdstFile, is not a file.\n" unless $QUIET;
		}

		#
		# if dst file has an .hqx suffix, and we are installing to
		# a kshare server, and we aren't installing thru a map,
		# then remove the suffix in the dst file.
		# do this before we check the mod times.
		#
		# We only care about this if there is no map entry specifying
		# the destination file name.
		#
		local ($HQXSUFFIX) = 0;
		local ($MACBINSUFFIX) = 0;
		local ($DO_READ) = 1;
		if ($SERVER_TARGET == $KSHARE) {
			$HQXSUFFIX = ($srcFile =~ /\.hqx$/i);
			$MACBINSUFFIX = ($srcFile =~ /\.mb2$/i);

			if ($HQXSUFFIX || $MACBINSUFFIX) {
				$DO_READ = 0;
				if ( !$HAVE_MAP && $dstFile =~ /\.(hqx|mb2)$/i) {
					$dstFile = $1 if ($dstFile =~ /^(.+)\./);
				}
			}
		}
#printf STDERR ("HQXSUFFIX=%d MACBINSUFFIX=%d srcFile='%s' pdstFile='%s'\n", $HQXSUFFIX, $MACBINSUFFIX, $srcFile, $pdstFile);
		
		$srcFileModTime = &os'modTime($srcFile);
		if ($CVSDEST) {
			$dstFileModTime = &os'modTime($cvsdstFile);
		} else {
			$dstFileModTime = &os'modTime($dstFile);
		}
		if (!defined($srcFileModTime)) {
			$srcFileModTime = -1;
		}
		if (!defined($dstFileModTime)) {
			$dstFileModTime = -1;
		}
		if (! $TEST && ! -e $dstDir) {
			if ($FORCE_DIR) {
				$os'DEBUG = 1 if ($DEBUG);
				if (&os'createdir($dstDir, $DIR_MODE)) {
					print STDERR "BUILD_ERROR: $p: failed to create $dstDir\n";
					++$errorCount;
					next;
				}
			}
			if (! -e $dstDir) {
				print STDERR "BUILD_ERROR: $p: $dstDir does not exist (try -f <DIRMODE>).\n";
				++$errorCount;
				next;
			}
		}

		@preProcedures = ();
		@duringProcedures = ();
		@postProcedures = ();
		$OPTION_NOPERLIO = 0;
		
		# break up the procedure into appropriate lists
		foreach $wproc (split('&', $procedures)) {
			next if ($wproc eq "");
			($when, $proc) = ($wproc =~ /^([^:]+):(.*)$/);
			if ($when eq "pre") {
				push(@preProcedures, $proc);
			} elsif ($when eq "post") {
				push(@postProcedures, $proc);
			} else {
				push(@duringProcedures, $proc);
			}
			# See if it's also on the preoption list.
			# print "pre_option_list = $pre_option_list proc = $proc wproc = $wproc\n";
			if ($pre_option_list =~ /:$proc:/) {
				push(@preProcedures, $proc);
				# print "Adding $proc onto the preProcedures list as well\n";
			}
		}
		
		# Check to see if there are any pre operations that we need to
		# do.  Right now, there can be only one operation that uses
		# $pre_result.
		$pre_result = $argstr = $tmp = "";
		foreach $proc (@preProcedures) {
			&parse_proc_spec($proc, *procname, *argstr);
			#pre-pend a comma if args:
			$argstr = ($argstr eq "") ? "" : ", $argstr";
			$tmp = sprintf("&pre_option_%s('%s', '%s'%s)", $procname, $srcFile, $dstFile, $argstr);

			print "about to run eval $tmp\n" if ($DEBUG);
			$pre_result = eval $tmp;
			# print "pre_result = $pre_result\n";
		}

		# Should we execute their special command instead.
		if ($cmdString ne "") {
			$cmd = &vars'expand_args($cmdString, ($srcFile, $dstFile,
														 $mode, $base,
														 $dstDir));  #'
			print "install: cmd = '$cmd'\n" if ($DEBUG);
			local($ret);
					
			if (!$TEST) {
				if ($cmd eq "symlink" || $cmd eq "copylink") {
					# We need to read the source file and create a
					# symlink to the destination file.
					
					# print "srcFile = '$srcFile' dstFile = '$dstFile'" .
					#	" base = '$base' dstDir = '$dstDir'\n" if ($DEBUG);
					local($srcLink) = "";
					if (&os'read_binfile2str(*srcLink, $srcFile)) {
						++$errorCount;
						next;
					}
                    local($expandErrors);
					$srcLink = &vars'expand_vars($srcLink, *ENV, *expandErrors);
					# Removed any comments
					$srcLink =~ s/#.*\n//g;
					# Remove everything after & including the first
					# return; this will get rid of multiple lines.
					$srcLink =~ s/\n.*//;
					# Remove leading and trailing whitespace
					$srcLink =~ s/^\s+//;
					$srcLink =~ s/\s+$//;
                    $crcValue = 0;
                    if ($cmd eq "symlink") {
						# If source is newer than destination and -u
						# is set, then skip this file. 
						if ($dstFileModTime >= 0) {
							if ($UPDATE && $srcFileModTime <= $dstFileModTime) {
								print "target $pdstFile is up to date.\n" if ($VERBOSE);
								next;
							}
						}
					    print "   ln -s $srcLink $dstFile\n" unless $QUIET;
					    if (&os::symlink($srcLink, $dstFile)) {
						    ++$errorCount;
						    next;
					    }
						# finally, add this file onto the transaction list
						&AddChangeTransaction($dstFile, "l");
						$instDone{$i} = 1;
						next;
                    } else {
						# A copylink is really just copying a file, if
						# we change the source file to be the one we
						# read from the link file, we can just use the
						# rest of this install routine to install it.
						$srcFile = $srcLink;
						$srcFileModTime = &os'modTime($srcFile); #'
                    }
				} elsif ($cmd eq "execute") {
					local($tempFile);
					$tempFileProg = &os'TempFile;
                    $tempFileOutput = &os'TempFile;
					print "  $srcFile -> $tempFileProg\n" unless $QUIET;
					if (&os'copy_file($srcFile, $tempFileProg) ||
                        &os'chmod($tempFileProg, 0777)) {
						++$errorCount;
						next;
					}
					if (&os'run_cmd("sh -c $tempFileProg > $tempFileOutput", ! $QUIET)) { #'
						++$errorCount;
						next;
					}
					$srcFile = $tempFileOutput;
					$srcFileModTime = &os'modTime($srcFile); #'
				} else {
					if (&os'run_cmd($cmd, ! $QUIET)) { #'
						print "Run of '$cmd' returned a nonzero exit status\n";
						++$errorCount;
					}
                    next;
				}
			}
		}
		
		if ($IGNORE_NONEXISTANT_FILES && $srcFileModTime < 0 &&
			$dstFileModTime < 0) {
			# file doesn't exist at the source or the destination
			# and we're suppose to ignore nonexistant files, so do.
			print "ignoring nonexistant file\n" if ($DEBUG);
			next;
		}
			
	    # If source is newer than destination and -u is set, then skip
		# this file. 
		if ($dstFileModTime >= 0) {
			print "times: $srcFileModTime <= $dstFileModTime \n" if ($DEBUG);
			if ($UPDATE && $srcFileModTime <= $dstFileModTime) {
				printf "target %s is up to date.\n", $CVSDEST? $cvsdstFile: $pdstFile if ($VERBOSE);
				next;
			}
		}

	    # Do some syntax checking
		if ($CHECK) {
			if ($srcFile =~ /\.prl$/ || $srcFile =~ /\.pl$/) {
				if (&perl_syntax_check($srcFile)) {
					++$errorCount;
					next;
				}
			} elsif ($srcFile =~ /\.ksh$/ || $srcFile =~ /\.sh$/) {
				if (&sh_syntax_check($srcFile)) {
					++$errorCount;
					next;
				}
			}
		}

		local($buf) = "";
		print "   $srcFile -> " unless $QUIET;

		if ($IGNORE_NONEXISTANT_FILES && $srcFileModTime < 0 &&
			$dstFileModTime >= 0) {
			# The file is not in the source directory, but is in the
			# destination directory, this means that we should remove
			# it, from the destionation directory.
			print "Removing dest file because source file isn't there\n" if ($DEBUG);
			&os::rmFile($dstFile) unless ($CVSDEST);
			&os::rmFile($cvsdstFile) if ($CVSDEST);
			&AddDeleteTransaction($dstFile, "f");
			print "gone\n" unless $QUIET;
			$instDone{$i} = 1;
			next;
		}

		#avoid reading .hqx files:
		if ($DO_READ) {
			# Read the entire file into memory.
			if (&os'read_binfile2str(*buf, $srcFile) != 0) {
				printf STDERR ("%s:  READ FAILED, file %s - skipping.\n", $p, $srcFile);
				++$errorCount;
				next;
			}
		}

		# Perform the munges.
		$argstr = $tmp = "";
		foreach $proc (@duringProcedures) {
			&parse_proc_spec($proc, *procname, *argstr);
			print "$procname -> " unless $QUIET;

			#pre-pend a comma if args:
			$argstr = ($argstr eq "") ? "" : ", $argstr";
			$tmp = sprintf("&option_%s(*buf, '%s', '%s', '%s'%s)",
						   $procname, $srcFile, $dstFile, $pre_result,
						   $argstr);

			print "eval $tmp\n" if ($DEBUG);
            #print "eval $tmp\n";
			local($proc_result);
			$proc_result = eval $tmp;

			if ($@ ne "") {
				print "\nBUILD_ERROR: $p: Received an error while evaling &option_$proc\n$@\n";
				print "BUILD_ERROR: $p: Aborting installation.  Leaving destination file alone.\n";
				++$errorCount;
				next file;
			}
			if ($proc_result) {
				print "\nBUILD_ERROR: $p: Received error while running &option_$proc, aborting install.\n";
				++$errorCount;
				next file;
			}
		}

		if ($TEXT_TARGET >= 0) {
			if (&suffix'IsText(&path'suffix($srcFile))) {
				&do_localtxt(*buf, $srcFile, $TEXT_TARGET) unless $TEST;
			}
		}
		if ($dstFileModTime >= 0 && $UPDATEDIFF) {
			my ($ret) = 0;
			if ($CVSDEST && ! -e $dstFile) {
				$cmd = "co -f -q $cvsdstFile $dstFile";
				if (&os'run_cmd($cmd, $VERBOSE)) {
					print "\nBUILD_ERROR: $p: error while checking out file for -udiff\n";
					$ret = -1;	#force loop to continue below...
				}
			}
			
			$ret = &os'cmp_str2file(*buf, $dstFile) if ($ret == 0);	#don't continue if error.
			if ($ret < 0) {
				++$errorCount;
				next;
			} elsif ($ret == 0) {
				print "dest same as source.\n" unless $QUIET;
				unlink($dstFile) if ($CVSDEST && !$LEAVE_CLEAR_TEXT);	#delete clear-text if we checked out.
				next;
			}
		}

		printf "%s", $CVSDEST? $cvsdstFile: $pdstFile unless $QUIET;
		print " (" . length($buf) . " bytes)" if ($VERBOSE);
		print "\n" unless $QUIET;

		$doCalcCrc = 1;
		$crcValue = 0;

		if ($SERVER_TARGET == $KSHARE) {
			local ($creator) = 'MPS ';	#default text creator is MPW.

			if ($HQXSUFFIX || $MACBINSUFFIX) {
				#use kunarc to convert the BinHexed file to kshare format:
				$cmd = sprintf("\trm -f '%s'; \n\tkunarc -f '%s' %s > /dev/null", $dstFile, $dstFile, $srcFile);
				&os'run_cmd($cmd, ! $QUIET) unless $TEST;
			} else {
				&os'write_binstr2file(*buf, $dstFile) unless $TEST;
				#don't set filetype if already specified:
				unless (grep(/macftype/, @postProcedures)) {
					$cmd = sprintf("\tkats -C '%s' -T TEXT '%s'", $creator, $dstFile);
					&os'run_cmd($cmd, ! $QUIET) unless $TEST;
				}
			}
			$doCalcCrc = 0;
		} else {
			if (! $TEST) {
				if (&os'write_binstr2file(*buf, $dstFile)) {
					++$errorCount;
					next;
				} else {
					#CONTINUE - WE WROTE THE FILE SUCCESSFULLY...
				}
			}
		}

		# Do post-install munges.
		$argstr = $tmp = "";
		foreach $proc (@postProcedures) {
			&parse_proc_spec($proc, *procname, *argstr);
			#pre-pend a comma if args:
			$argstr = ($argstr eq "") ? "" : ", $argstr";
			$tmp = sprintf("&post_option_%s(*buf, '%s', '%s'%s)", $procname, $srcFile, $dstFile, $argstr);

			print "eval $tmp\n" if ($DEBUG);
#print "eval $tmp\n";
			eval $tmp;
		}

		if ($doCalcCrc && ! $PRINTMAP) {
			#$crcValue = sprintf("%x", &pcrc'CalculateFileCRC($dstFile));
		}

		if (! $TEST) {
			if (&os'chmod($dstFile, $mode)) {
				++$errorCount;
				next;
			}
		}

		#make sure OUTFILE is newer than INFILE (NFS problem).
		utime($srcFileModTime+1, $srcFileModTime+1, $dstFile) unless $TEST;

		if ($CVSDEST) {
			if (&cvs_checkin($dstFile, $cvsdstFile, $LEAVE_CLEAR_TEXT) != 0) {
				unlink($dstFile);
				++$errorCount;
				next;
			}
		}
		
		#note:  -cvsdest & -transact are mutually exclusive; checked for earlier.
		if ($TRANSACTION_LOG) {
			&AddChangeTransaction($dstFile, "f");
		}

		$instDone{$i} = 1;
	}

	return $errorCount;
}

sub doUninstall
	# Remove the file from the distribution area.
{
	local($i, $srcFile, $dstFile, $pdstFile);

	for ($i = 0; $i < $opNum; ++$i) {
		next if $instDone{$i};
		$srcFile = &getSrcFile($i);
		$pdstFile = &getDstFile($i);	#printable form
		$dstFile = &url'name_decode($pdstFile);
		
		print "   $srcFile -> " unless $QUIET;
		if (-e $dstFile || -l $dstFile) {
			print "$pdstFile -> " unless $QUIET;
			if (! $TEST && &os'rmFile($dstFile)) {
				print "unable to remove\n" unless $QUIET;
			} else {
				print "gone\n" unless $QUIET;
			}
			
			# finally, add this file onto the transaction list
			&AddDeleteTransaction($dstFile, "gone");
		} else {
			print "$pdstFile -> not there\n" unless $QUIET;
		}
		
		$instDone{$i} = 1;
	}
	return 0;
}

sub doDiff
	# Do a diff with the source file and the file from the
	# distribution area.
{
	local($i, $srcFile, $dstFile);

	if ($OS != $UNIX) {
		print STDERR "ERROR: diff can only be performed on unix\n";
		return 1;
	}
	for ($i = 0; $i < $opNum; ++$i) {
		next if $instDone{$i};
		$srcFile = &getSrcFile($i);
		$pdstFile = &getDstFile($i);	#printable form
		$dstFile = &url'name_decode($pdstFile);
		
		print "\ndiff $srcFile $pdstFile\n" unless $QUIET;
		if (!&os'diff($srcFile, $dstFile)) {
			print "There is no diff between $srcFile and $pdstFile\n" unless $QUIET;
		}
		$instDone{$i} = 1;
	}
	return 0;
}

sub doUntarUntgz
# Explode a tar or tgz (tar.gz - gzip'ed tar archive) into a directory.
# We don't support -u at this point.
# url name decoding not supported either.  RT 11/7/96
#
# returns non-zero if errors.
#
{
	local($i, $srcFile, $dstDir, $crcValue, $tarFileModTime);
	local($errorCount) = 0;

	if ($OS != $UNIX) {
		print STDERR "ERROR: tar can only be performed on unix\n";
		return 1;
	}
	require "tar.pl";

	if ($DEBUG) {
		$tar'DEBUG = $DEBUG;
	}

	# foreach uncompleted install operation...
	for ($i = 0; $i < $opNum; ++$i) {
		next if $instDone{$i};
		$srcFile = &getSrcFile($i);
		# In the case of an untarring, the full name is really
		# a directory.
		$dstDir  = &getDstFile($i);
		
		# print "untgz: $srcFile $dstfile $dstDir\n";
		local($ret);
		local($pwd) = &path'cached_pwd;
		local($tarFile);
		if (&path'isfullpathname($srcFile)) {
			$tarFile = $srcFile;
		} else {
			$tarFile = &path'mkpathname($pwd, $srcFile);
		}

		# create dest directory
		if ($FORCE_DIR) {
			&os'createdir($dstDir, $DIR_MODE) unless $TEST;
		}
		
		###################
		# CHANGE DIR to DST
		###################

		if (! $TEST && &os'chdir($dstDir)) {
			print STDERR "ERROR: unable to cd into $dstDir: $!\n";
			++$errorCount;
			next;
		}

		if (! -e $tarFile) {
			print STDERR "ERROR: $tarFile does not exist, skipping.\n";
			++$errorCount;
			next;
		}
		$tarFileModTime = &os::modTime($tarFile);

		# get a listing of the tar contents
		local(@contents, $file);
		if ($OPERATION eq "untar") {
			@contents = &tar::tar_contents($tarFile);
		} else {
			@contents = &tar::tar_gzip_contents($tarFile);
		}
		print "$tarFile = (" . join(", ", @contents) . ")\n" if ($DEBUG);
		local($count) = 0;
		local(@tarFileContents);
		@tarFileContents = @contents;
		@contents = ();
		my($isDir, $isLink, $doesExist, $mt);

		#####
		# for each file in tar archive...
		#####
		foreach $file (@tarFileContents) {
			my ($fullName) = &path::mkpathname($dstDir, $file);
			my ($cvsfullName) = $fullName . ',v';
			my ($cvsfile) = $file . ',v';

			if ($CVSDEST) {
				lstat($cvsfile);
			} else {
				lstat($file);
			}

			#NOTE:  we set these vars explicitly to 0 or 1, so we can print them.
			#  if we say $isDir = (-d _), perl says it is not defined, which may
			#  be a side effect of how perl evaluates boolean expressions.  RT 9/21/00.

			$isDir = (-d _)?1:0;
			$isLink = (-l _)?1:0;
			$doesExist = (-e _)?1:0;

#printf "file is '%s' isDir=%d isLink=%d doesExist=%d\n", $file, $isDir, $isLink, $doesExist;

			next if ($isDir);
			# It's a directory in the tar file if it's got a '/' at the end.
			if ($file =~ /\/$/) {
				# Make sure the directory exists and go on to the next file.
				&os::createdir($file, $DIR_MODE) unless $TEST;
				next;
			}
			print "check for $file\n" if ($DEBUG);
			
			if ($doesExist || $isLink) {
				if ($CVSDEST) {
					$mt = &os::modTime($cvsfile);
				} else {
					$mt = &os::modTime($file);
				}
				if ($UPDATE && $tarFileModTime <= $mt) {
					print "   is later than tar file: $tarFileModTime <= $mt\n" if ($DEBUG);
					if ($CVSDEST) {
						printf "target %s is up to date.\n", $cvsfullName if ($VERBOSE);
					} else {
						printf "target %s is up to date.\n", $fullName if ($VERBOSE);
					}
					next;
				}
				print "Removing $file\n" if ($DEBUG);
				if (! $TEST) {
					if (&os::rmFile($file)) {
						print STDERR "ERROR: Unable to remove $file.\n";
						++$errorCount;
						next;
					}
				}
			}
			++$count;
			push(@contents, $file);
		}
		if ($count == 0) {
			print "File count is 0, installing nothing.\n" if ($DEBUG);
			next;
		}

		# untar from src
		if (! $TEST) {
			if ($OPERATION eq "untar") {
				if (&tar'untar($tarFile, @contents)) {
					print STDERR "ERROR: Unable to completly untar $tarFile\n";
					++$errorCount;
					next;
				}
			} else {
				if (&tar'untar_gzip($tarFile, @contents)) {
					print STDERR "ERROR: Unable to completly untgz $tarFile\n";
					++$errorCount;
					next;
				}
			}
		}

		#################
		# CHANGE DIR BACK
		#################
		# bring ourselves back
		&os::chdir($pwd);
		
		######
		# loop thru installed files, and perform:  printmap, transaction logging, cvs checkins,
		# etc., depending on which options are active.
		######

		local($len) = length($srcFile);

		printf("   %${len}s\n", $srcFile) unless $QUIET;

		foreach $file (@contents) {
			my ($fullName) = &path::mkpathname($dstDir, $file);
			my ($cvsfullName) = $fullName . ',v';

			utime($tarFileModTime+1, $tarFileModTime+1, $fullName) unless $TEST;

			next if (-d $fullName);		# ignore directories.

			printf("%${len}s-> %s\n", " ", $fullName) unless $QUIET;

			if ($PRINTMAP) {
				printf("%s\t%s\t%s\t%s\t%o\n",
					$TARGET_OS || "-", $srcFile, &path'tail($fullName), &path'head($fullName), 0);
				next;	#DONE - NEXT FILE.
			}

			if ($TRANSACTION_LOG) {
				&AddChangeTransaction($fullName, "f");
			}

			if ($CVSDEST) {
				if (&cvs_checkin($fullName, $cvsfullName, $LEAVE_CLEAR_TEXT) != 0) {
					printf STDERR "BUILD_ERROR: %s [doUntarUntgz]: error on CVS commit for $fullName\n", $p;
					unlink($fullName);
					++$errorCount;
				}
			}
		}

		$instDone{$i} = 1;
	}
	return $errorCount;
}

sub doTgz
# Put files into a tgz archive.  This routine is used to support
# collecting source files from a development env. created from tarballs.
# typically, this is used to do local mods to an open-source package
# and to save the state of a compilation & configuration env. for same.
#
# not used for core minstall functionality.  see doUntarUntgz.
#
# Url name decoding not supported.  RT 11/7/96
# -cvsdest not needed or supported for this operation.  RT 9/21/00
{
	local($i, $j, $tgzFile, $srcFile, $tgzModTime);
	local(@srcFileList);
	local($errorCount) = 0;

	if ($OS != $UNIX) {
		print STDERR "ERROR: tar can only be performed on unix\n";
		return 1;
	}
	require "tar.pl";

	@srcFileList = ();
	
	for ($i = 0; $i < $opNum; ++$i) {
		next if $instDone{$i};
		
		$tgzFile = &getDstFile($i);
		$srcFile = &getSrcFile($i);

		if (! -r $srcFile) {
			print STDERR "ERROR: $srcFile is not readable, skipping.\n";
			++$errorCount;
			next;
		}

		$tgzModTime = &os'modTime($tgzFile);
		if (!defined($tgzModTime)) {
			$tgzModTime = -1;
		}

		$modTime{$srcFile} = &os'modTime($srcFile);
		if ($UPDATE && $modTime{$srcFile} <= $tgzModTime) {
			$instDone{$i} = 1;
			printf("target $tgzFile is up to date versus $srcFile.\n") if ($VERBOSE);
			next;
		}
					
		push(@srcFileList, $srcFile);
		# Look ahead for more files that go into this same archive.
		for ($j = $i + 1; $j < $opNum; ++$j) {
			if ($tgzFile eq &getDstFile($j)) {
				$instDone{$j} = 1;
				$srcFile = &getSrcFile($j);
				$modTime{$srcFile} = &os'modTime($srcFile);
				if (!defined($modTime{$srcFile})) {
					$modTime{$srcFile} = -1;
				}
				push(@srcFileList, $srcFile);
			}
		}

		# $tar'DEBUG = 1;
		print "tgzFile = $tgzFile filename = $srcFile\n" if ($DEBUG);
		if (! $TEST) {
			if (! -e $tgzFile) {
				&tar'tar_gzip($tgzFile, @srcFileList);
				foreach $srcFile (@srcFileList) {
					print "   $srcFile -> $tgzFile\n";
				}
			} else {
				local($pwd) = &path'cached_pwd;
				local($tmpDir) = &os'TempDir;
				local($fullTgzFile);

				# Figure out how to reference the original tgz file.
				if (&path'isfullpathname($tgzFile)) {
					$fullTgzFile = $tgzFile;
				} else {
					$fullTgzFile = &path'mkpathname($pwd, $tgzFile);
				}

				# Create a temp directory and go inside of it.
				mkdir($tmpDir, 0777);
				if (&os'chdir($tmpDir)) {
					print STDERR "ERROR: Failed to cd into $tmpDir\n";
					++$errorCount;
					next;
				}

				print "tmpDir = $tmpDir\n" if ($DEBUG);
				print "fullTgzFile = $fullTgzFile\n" if ($DEBUG);

				# Explode the original archive into the temp directory.
				if (&tar'untar_gzip($fullTgzFile)) {
					print STDERR "ERROR: Failed to untar $fullTgzFile\n";
					++$errorCount;
					next;
				}

				# Put the new files into the temp directory.
				local($fullSrcFile);
				local($updateFileCount) = 0;
				foreach $srcFile (@srcFileList) {
					if ($UPDATE && -e $srcFile &&
						$modTime{$srcFile} <= &os'modTime($srcFile)) {
						printf("target $tgzFile is up to date versus $srcFile.\n") if ($VERBOSE);
						next;
					}
					# srcFile should be a relative filename
					# fullSrcFile should be an absolute filename
					if (&path'isfullpathname($srcFile)) {
						$fullSrcFile = $srcFile;
						$srcFile = &path'tail($fullSrcFile);
					} else {
						$fullSrcFile = &path'mkpathname($pwd, $srcFile);
					}
					print "srcFile = $srcFile fullSrcFile = $fullSrcFile\n" if ($DEBUG);
					# We want to remove the file from the temp
					# directory, so that we copy in the real source file.
					&os'rmFile($srcFile);
					if (&os'copy_file($fullSrcFile, $srcFile) ||
						&os'copy_attribs($fullSrcFile, $srcFile)) {
						++$errorCount;
						next;
					}
					print "   $srcFile -> $tgzFile\n";
					++$updateFileCount;
				}

				if ($updateFileCount > 0) {
					# Then, package the temp directory all back together
					# and replace the original archive.
					&tar'tar_gzip("$fullTgzFile", <*>);
				}

				if (&os'chdir($pwd)) {
					print STDERR "ERROR: Failed to cd into $pwd\n";
					++$errorCount;
					next;
				}
				&os'rm_recursive($tmpDir);
			}
		}

		$instDone{$i} = 1;
	}
	return $errorCount;
}

sub doRmtgz
	# Uninstall what once got installed thru doUntarUntgz.
{
	local($i, $srcFile, $dstDir);
	local($errorCount) = 0;

	if ($OS != $UNIX) {
		print STDERR "ERROR: tar can only be performed on unix\n";
		return 1;
	}
	require "tar.pl";

	if ($DEBUG) {
		$tar'DEBUG = $DEBUG;
	}
	for ($i = 0; $i < $opNum; ++$i) {
		next if $instDone{$i};
		$srcFile = &getSrcFile($i);
		# In the case of an untarring, the full name is really
		# a directory.
		$dstDir  = &getDstDir($i);
		
		local($ret);
		local($tarFile) = $srcFile;

		if (! -e $tarFile) {
			print STDERR "ERROR: $tarFile does not exist, skipping.\n";
			++$errorCount;
			next;
		}

		# get a listing of the tar contents
		local($file);
		local(@tarFileContents);
		if ($OPERATION eq "rmtar") {
			@tarFileContents = &tar'tar_contents($tarFile);
		} else {
			@tarFileContents = &tar'tar_gzip_contents($tarFile);
		}
		local($count) = 0;
		local($len) = length($srcFile);
		printf("   %${len}s\n", $tarFile) unless $QUIET;

		# Do 2 passes, one for files, and one for dirs.
		foreach $file (@tarFileContents) {
			$dstFile = &path'mkpathname($dstDir, $file);
			next if (-d $dstFile);
			printf("%${len}s-> %s -> ", " ", $dstFile) unless $QUIET;

			print "check for $dstFile\n" if ($DEBUG);
			
			if (-e $dstFile) {
				print "Removing $dstFile\n" if ($DEBUG);
				if (! $TEST && &os'rmFile($dstFile)) {
					print "unable to remove\n";
					++$errorCount;
					next;
				} else {
					print "gone\n" unless $QUIET;
				}
				&AddDeleteTransaction($dstFile, "gone");
			}
			++$count;
		}
		foreach $file (@tarFileContents) {
			$dstFile = &path'mkpathname($dstDir, $file);
			next if (! -d $dstFile);

			printf("%${len}s-> %s -> ", " ", $dstFile) unless $QUIET;
			if (! $TEST && &os'rmDir($dstFile)) {
				print "unable to remove\n";
				++$errorCount;
				next;
			} else {
				print "gone\n" unless $QUIET;
			}
			&AddDeleteTransaction($dstFile, "gone");
			++$count;
		}
		if ($count == 0) {
			print "File count is 0, uninstalled nothing.\n" if ($DEBUG);
			next;
		}

		$instDone{$i} = 1;
	}
	return $errorCount;
}

# A couple handy shorthand functions for the above installing routines.
sub getSrcFile
{
	local($i) = @_;

	return $instSrc{$i};
}

sub getDstFile
{
	local($i) = @_;

	if ($instDst{$i} eq $DOT) {
		return $instBase{$i};
	} else {
		return &path'mkpathname($instBase{$i}, $instDst{$i});
	}
}

sub getDstDir
{
	local($i) = @_;
	
	if ($instDst{$i} eq $DOT) {
		return $instBase{$i};
	} else {
		local(@dstFile) = split($PS_IN, $instDst{$i});
		
		return &path'mkpathname($instBase{$i}, @dstFile[0..($#dstFile-1)]);
	}
}

sub do_localtxt
#carry out the local-text conversion for <os>
{
	local (*buf, $srcFile, $os) = @_;
	local(@obuf) = ();
	local($nchanged) = 0;
	local($nbytes) = length($buf);
	local($osname) = "unknown!!";

	if ($os == $MACINTOSH) {
		$osname = "MACINTOSH";
	} elsif ($os == $NT) {
		$osname = "DOS";
	} elsif ($os == $UNIX) {
		$osname = "UNIX";
	}

	if ($nbytes > 0) {
		$nchanged = &localtxt'localtxt(*obuf, $buf, $nbytes, $os);
		if ($nchanged > 0) {
			$buf = pack("C*", @obuf);
			print "$osname local text <$nchanged conversions> -> " unless $QUIET;
		} else {
			print "$osname local text <unchanged> -> " unless $QUIET;
		}
	} else {
		print "$osname local text <zero size file> -> " unless $QUIET;
	}
}

sub kshare_installed
#check that kshare commands are available on this host.
#otherwise, installs not allowed.
#return true if all commands available.
{
	local($cmd);
	local($nerrs) = 0;
	#check that commands are in the path:
	for $cmd ('kats', 'kunarc') {
		if (&path'which($cmd) eq "") {
			printf STDERR
			("%s: '%s' command not found, required for '-server kshare' option.\n",
				$'p, $cmd);
			++$nerrs;
		}
	}
	if ($nerrs > 0) {
		printf STDERR
		("%s:  kshare commands are normally found in /usr/etc/appletalk.\n", $'p);
	}
	return ($nerrs == 0);
}

#############################################################################
# The short munge functions.  You specify these in the install map.
#############################################################################

$pre_option_list = ":skel:";

# return true if there is a syntax error, false otherwise.
sub perl_syntax_check {
    # print("DEBUG: Entering perl_syntax_check, \$DO_PERL_CHECK=$DO_PERL_CHECK\n");
    local($srcFile) = @_;
    local($output);
    if ($DO_PERL_CHECK) {
	$perlPath = &path'which($PERL_CHECKER);
	if ($perlPath eq "") {
		$DO_PERL_CHECK = 0;
		print "Warning: I tried to run the perl syntax checker \"$PERL_CHECK\", but I couldn't find it. I am skipping the perl syntax check.\n";
	} else {
		chop($output = `$perlPath -c $srcFile 2>&1`);
		$perlVersion = `$perlPath -e 'print(\$]);'`;
		if ($output !~ /syntax OK/) {
			print "Warning: The perl $perlVersion syntax check of $srcFile failed:\n'$output'\n\n";
			return(1);
		} else {
			if ($VERBOSE) { print("$srcFile passed perl $perlVersion syntax check.\n");}
		 # print("$srcFile passed perl $perlVersion syntax check.\n");
			return(0);
		}
	}
    }
	# This section kept for backward compatibility.
	if ($PERL4CHECK) {
		if ($VERBOSE) {
			print("Notice: I'm now doing a depreciated perl4 syntax check. \n");
			print("        \"-perlCheck perl4\" replaces \"-perl4check\"\n");
		}
	    $perl4 = &path'which("perl4");
			if ($perl4 eq "") {
				$PERL4CHECK = 0;
				print "perl4 not found, perl4 syntax check not performed.\n";
				return(0);
			} else {
				chop($output = `$perl4 -c $srcFile 2>&1`);
				if ($output !~ /syntax OK/) {
					print "Warning: perl4 syntax check of $srcFile failed:\n'$output'\n\n";
					return(1);
				 } else {
					return(0);
				 }
			}
	}
	# print("DEBUG: Exiting perl_syntax_check\n");
    return 0;
}

sub sh_syntax_check
{
    local($srcFile) = @_;
    local($output);
    if ($OS == $UNIX) {
	require "shsyntax.pl";
	
	if (&shsyntax'Check($srcFile)) {  #'
			print "ERROR: ksh syntax check of   $srcFile   failed\n\n";
			return 1;
		}
	}
	return 0;
}

sub option_ungzip
{
	local(*buf, $srcFile, $dstFile) = @_;
	local($tmpfn) = "/tmp/minstall_ungzip$$";
	local($err);

	print "ungzip $srcFile\n" if ($DEBUG);
	if ($OS != $UNIX) {
		print "ERROR: ungzip option only available on unix\n";
		return 1;
	}

	#open a pipe to the gzip command:
	if (!open(GZIP, "|gzip -d -c >$tmpfn")) {
		print "ERROR (ungzip): can't open pipe to gzip, $!\n";
		return 1;
	}

	$! = 0;		#set errno to 0
	$err = print GZIP $buf;
	if ($err != 1) {
		print "ERROR (ungzip): write to tmp file failed, $!\n";
		return 1;
	}

	close GZIP;

	#now re-read from tmp file:
	if (!open(TMPF, $tmpfn)) {
		print "ERROR (ungzip): can't open ungzip tmp file, $!\n";
		return 1;
	}

	$buf = $ibuf  = "";
	$! = 0;		#set errno to 0
	while (($err = read(TMPF, $ibuf, 16384))) {
		$buf .= $ibuf;
	}

	if (!defined($err) || $err != 0) {
		print "ERROR (ungzip): read from tmp file failed, $!\n";
		return 1;
	}

	close TMPF;
	unlink $tmpfn;
	return 0;
}

sub option_bdb
	# Do bdb parsing; this includes removing comments, doing includes,
	# and checking for merge conflicts.
{
	local(*buf, $srcFile, $dstFile) = @_;

	local($inbuf) = $buf;
	$buf = "";
	local(@lines);
	local($line);
	@lines = split(/\n/, $inbuf);
	while (defined($line = shift @lines)) {
		$line =~ s/#.*//;
		if ($line =~ /^include/i) {
			local($includeFile, $includeBuf);
			$includeFile = (split(/ +/, $line))[1];
			if (&os'read_binfile2str(*includeBuf, $includeFile)) { #'
				print "ERROR: failed to read include file '$includeFile' for $srcFile: $!\n";
				return 1;
			}
			unshift(@lines, split(/\n/, $includeBuf));
			next;
		}
		$line =~ s/ //g;
		if ($line eq "") {
			next;
		}
		if ($line =~ /^<<<</) {
			print "ERROR: $srcFile has a merge conflict in it\n";
			return 1;
		}

		#if we find variables to expand...
		while ($line =~ '\$([a-zA-z0-9]+)') {
			my($varname) = $1;
#printf "match=%s\n", $varname;
			if (defined($ENV{$varname})) {
				$line =~ s/\$$varname/$ENV{$varname}/;
			} else {
				$line =~ s/\$$varname/NULL/;
			}
		}

		$buf .= $line . "\n";
	}
	return 0;
}

sub option_include
	# only do includes
{
	local(*buf, $srcFile, $dstFile) = @_;

	local($inbuf) = $buf;
	$buf = "";
	local(@lines);
	local($line);
	@lines = split(/\n/, $inbuf);
	while (defined($line = shift @lines)) {
		if ($line =~ /^include/i) {
			local($includeFile, $includeBuf);
			$includeFile = (split(/ +/, $line))[1];
			if (&os'read_binfile2str(*includeBuf, $includeFile)) { #'
				print "ERROR: failed to read include file '$includeFile' for $srcFile: $!\n";
				return 1;
			}
			unshift(@lines, split(/\n/, $includeBuf));
			next;
		}

		$buf .= $line . "\n";
	}
	return 0;
}

sub option_bdb_unique
	# Run option_bdb and remove duplicate entries.
{
	local(*buf, $srcFile, $dstFile) = @_;

	&option_bdb(*buf, $srcFile, $dstFile);

	local($inbuf) = $buf;
	$buf = "";

	local(@lines);
	local($line);
	local(%mark);

	@lines = split(/\n/, $inbuf);
	while (defined($line = shift @lines)) {
		if ($mark{$line}) {
			next;
		} else {
			$mark{$line}++;
			$buf .= $line . "\n";
		}
	}
	return 0;
}
 		
sub option_convert_to_mac_path
	# Convert the unix style directories into mac style directories.
	# eg:   3g/src/cmn/cparse -> 3g:src:cmn:cparse
{
	local(*buf, $srcFile, $dstFile) = @_;

	$buf =~ s#/#:#g;
	return 0;
}

sub option_mpw
{
	local(*buf, $srcFile, $dstFile) = @_;
	print "mpw $srcFile\n" if ($DEBUG);
	return if ($buf !~ /^.*perl.*/);
	# If the file had a .prl or .pl extension, then it was already
	# perl syntax checked; otherwise, it should be perl syntax checked.
	if ($CHECK && ($srcFile !~ /\.prl$/ && $srcFile !~ /\.pl$/)) {
		if (&perl_syntax_check($srcFile)) {
			return 1;
		}
	}

	&RemoveOtherPerlStartups(*buf);

	$buf = 'Perl -Sx "{0}" {"Parameters"}; Exit' . "\n" . $buf;
	return 0;
}

sub option_kshcg
#add a startup line to run a cado script on mks
{
	local(*buf, $srcFile, $dstFile) = @_;
	print "kshcg $srcFile\n" if ($DEBUG);
	if ($buf !~ /^.*(codegen|cado).*/) {
		print "$srcFile does not have a codegen or cado startup line, so I'm not adding mine either.\n" if ($DEBUG);
		return 0;
	}

	&RemoveOtherCodegenStartups(*buf);

	$buf = 'cado -u -x `whence $0` "$@"; exit' . "\n" . $buf;
	return 0;
}

sub option_shcg
#add a startup line to run a codegen script on unix or cygwin
{
	local(*buf, $srcFile, $dstFile) = @_;
	print "shcg $srcFile\n" if ($DEBUG);
	if ($buf !~ /^.*(codegen|cado).*/) {
		print "$srcFile does not have a codegen or cado startup line, so I'm not adding mine either.\n" if ($DEBUG);
		return 0;
	}

	&RemoveOtherCodegenStartups(*buf);

	$buf = 'if [ $# -eq 0 ]; then exec cado -u -x -S $0; exit $? ; else exec cado -u -x -S $0 "$@"; exit $? ; fi' . "\n" . $buf;
	return 0;
}

sub option_ksh
#add a startup line to run a perl script on mks
{
	local(*buf, $srcFile, $dstFile) = @_;
	print "ksh $srcFile\n" if ($DEBUG);
	return if ($buf !~ /^.*perl.*/);
	# If the file had a .prl or .pl extension, then it was already
	# perl syntax checked; otherwise, it should be perl syntax checked.
	if ($CHECK && ($srcFile !~ /\.prl$/ && $srcFile !~ /\.pl$/)) {
		if (&perl_syntax_check($srcFile)) {
			return 1;
		}
	}

	&RemoveOtherPerlStartups(*buf);

	$buf = 'perl -x `whence $0` "$@"; exit' . "\n" . $buf;
	return 0;
}

sub option_sh
#add a startup line to run a perl script on unix or cygwin
{
	local(*buf, $srcFile, $dstFile) = @_;
	print "sh $srcFile\n" if ($DEBUG);
	if ($buf !~ /^.*perl.*/) {
		print "$srcFile does not have a perl startup line, so I'm not adding mine either.\n" if ($DEBUG);
		return 0;
	}
	# If the file had a .prl or .pl extension, then it was already
	# perl syntax checked; otherwise, it should be perl syntax checked.
	if ($CHECK && ($srcFile !~ /\.prl$/ && $srcFile !~ /\.pl$/)) {
		if (&perl_syntax_check($srcFile)) {
			return 1;
		}
	}

	&RemoveOtherPerlStartups(*buf);

	# perl -x -S $0 "$@"; exit $?
	# $buf = "#!/bin/sh\n" . 'perl -x -S $0 "$@"; exit $?' . "\n" . $buf;
	#$buf = 'perl -x -S $0 "$@"; exit $?' . "\n" . $buf;
	# On some machines (alphaosf, hp9000) "$@" will get translated
	# to "" (1 argument) for no arguments, while on other machines (solsparc),
	# it will be no arguments.

	local ($execprefix) = "";
	if ($OPTION_NOPERLIO) {
		$execprefix .= $OPTION_NOPERLIO_FIX;
	}

	$buf = $execprefix
			. 'if [ $# -eq 0 ]; then exec perl -x -S $0; exit $? ; else exec perl -x -S $0 "$@"; exit $? ; fi'
			. "\n"
			. $buf;

	return 0;
}

sub option_noperlio
{
#printf STDERR "PROCESSING option noperlio...\n";
	$OPTION_NOPERLIO = 1;
	return 0;
}

sub option_bat
{
	local(*buf, $srcFile, $dstFile) = @_;
	return if ($buf !~ /^.*perl.*/);
	# If the file had a .prl or .pl extension, then it was already
	# perl syntax checked; otherwise, it should be perl syntax checked.
	if ($CHECK && ($srcFile !~ /\.prl$/ && $srcFile !~ /\.pl$/)) {
		if (&perl_syntax_check($srcFile)) {
			return 1;
		}
	}

	&RemoveOtherPerlStartups(*buf);

	$buf = <<"EOF";
\@REM = '
    \@echo off
    perl -S %0 %1 %2 %3 %4 %5 %6 %7 %8 %9
    \@goto END_OF_PERL_WRAPPER
';
undef \@REM;
# End of "#! /usr/bin/perl" emulation for MS-DOS perl.
# =============================================================================

$buf

__END__
:END_OF_PERL_WRAPPER
EOF
	return 0;
}

sub option_noprlheader
{
	local(*buf, $srcFile, $dstFile) = @_;
	return if ($buf !~ /^.*perl.*/);
	# If the file had a .prl or .pl extension, then it was already
	# perl syntax checked; otherwise, it should be perl syntax checked.
	if ($CHECK && ($srcFile !~ /\.prl$/ && $srcFile !~ /\.pl$/)) {
		if (&perl_syntax_check($srcFile)) {
			return 1;
		}
	}

	&RemoveOtherPerlStartups(*buf);
	return 0;
}

sub option_localtxt
{
	local(*buf, $srcFile, $dstFile, $pre_result, $argstr) = @_;
	local($target);

	# print "localtxt($argstr)\n";
	if ($argstr =~ /^mac$/i) {
		$target = $MACINTOSH;
	} elsif ($argstr =~ /^dos$/i) {
		$target = $NT;
	} elsif ($argstr =~ /^unix$/i) {
		$target = $UNIX;
	} else {
		print "BUILD_ERROR: $p: Unknown argument to option_localtxt: $argstr\n";
		return 1;
	}
	
	&do_localtxt(*buf, $srcFile, $target) unless $TEST;
	return 0;
}

sub pre_option_skel
{
	local($srcFile, $dstFile) = @_;
	local($prlskel) = "";

	$prlskel = &path'which($PRLSKEL);
	print "prlskel = '$prlskel'\n" if ($DEBUG);

	if (! -r $prlskel) {
		print STDERR "ERROR: failed to find $PRLSKEL in your path:\n";
		return "";
	}
	# prlskel is the real source file.  Use the modTime of which of
	# source file or prlskel, which ever is more recent.
	$prlskelModTime = &os'modTime($prlskel);
	if ($srcFileModTime < $prlskelModTime) {
		# prlskel is more recent.
		$srcFileModTime = $prlskelModTime;
	}
	return $prlskel;
}

sub option_skel
{
	local(*buf, $srcFile, $dstFile, $prlskel) = @_;

	print "option_skel here, prlskel = $prlskel\n" if ($DEBUG);
	if (-r $prlskel) {
		print "$prlskel -> " unless $QUIET;
        $inFileModTime = &os'modTime($prlskel);
		&os'read_binfile2str(*buf, $prlskel);
	}
	return 0;
}

sub post_option_AppleDouble
#convert kshare format files to apple-double once they are installed.
{
	local(*buf, $srcFile, $dstFile) = @_;
	local($resfile);

	if ($dstFile =~ /^(.+\/)([^\/]+)$/) {
		$resfile = "$1%$2"
	}
#printf("post_option_macftype:  resfile='%s' srcf=%s dstf=%s\n", $resfile, $srcFile, $dstFile);

	if ($SERVER_TARGET == $KSHARE) {
		$cmd = sprintf("\trm -f '%s'; \n\tkarc -D -r '%s'", $resfile, $dstFile, $dstFile);
		&os'run_cmd($cmd, ! $QUIET) unless $TEST;
		&os'chmod($resfile, $GMODE) unless $TEST;
	} else {
		print STDERR "BUILD_ERROR: $p: 'AppleDouble' filter only supported with '-server kshare' option.\n";
		return(0);
	}

	return(1);
}

sub post_option_macftype
{
	local(*buf, $srcFile, $dstFile, $creator, $type) = @_;
#printf("post_option_macftype:  srcf=%s dstf=%s creat=%s type=%s\n", $srcFile, $dstFile, $creator, $type);

	if ($SERVER_TARGET == $KSHARE) {
		$cmd = sprintf("\tkats -C '%s' -T '%s' '%s'", $creator, $type, $dstFile);
		&os::run_cmd($cmd, ! $QUIET) unless $TEST;
	} else {
		print STDERR "BUILD_ERROR: $p: 'macftype' filter only supported with '-server kshare' option.\n";
		return(0);
	}

	return(1);
}

sub option_substvar
{
	local(*buf, $srcFile) = @_;
	local($eval_name, $evar_val);
	
	while ($buf =~ /{=(\w+)=}/) {
		$evar_name = $1;
		$evar_val = $ENV{$evar_name};
		if (defined($evar_val)) {
			$buf =~ s/{=$evar_name=}/$evar_val/g;
		} else {
			printf STDERR ("BUILD_ERROR:  %s not defined\n", $evar_name);
			# So as to not get caught in an infinite loop we
			# remove the thing we were searching for.  (An
			# exception would be better.)
			$buf =~ s/{=$evar_name=}/$evar_name/g;
		}
	}
	return 0;
}

sub option_perlprof
{
	local(*buf, $srcFile) = @_;
	local($count) = 0;

	while ($buf =~ s/\nsub\s+(\S+)([^{]*{)/\nprofsub $1 $2 \$main::profCount{\"$1\"} = (\$main::profCount{\"$1\"} || 0) + 1;/) {
		++$count;
	}
	while ($buf =~ s/\nprofsub/\nsub/) {
	}
    print "$count functions profable -> ";
	return 0;
}

sub RemoveOtherCodegenStartups
	# This file may already have a cado startup line in it.  Remove it
	# from the buffer.
{
	local(*buf) = @_;

	# Remove head lines until we find a "#!.*perl"
	while ($buf !~ /^\#\!.*(codegen|cado).*/) {
		# print "This line is not a #!/perl line\n";

		# Remove top line.
		$buf =~ s/^.*\n//;
		if ($buf eq "") {
			print STDERR "ERROR: This was not a cado program, no #!/bin/codegen or #!/bin/cado found.\n";
			return;
		}
	}
}

sub RemoveOtherPerlStartups
	# This file may already have a perl startup line in it.  Remove it
	# from the buffer.
{
	local(*buf) = @_;

	# Remove head lines until we find a "#!.*perl"
	while ($buf !~ /^\#\!.*perl.*/) {
		# print "This line is not a #!/perl line\n";

		# Remove top line.
		$buf =~ s/^.*\n//;
		if ($buf eq "") {
			print STDERR "ERROR: This was not a perl program, no #!/bin/perl found.\n";
			return;
		}
	}
}

sub AddChangeTransaction
{
	&AddTransaction("add", @_);
}

sub AddDeleteTransaction
{
	&AddTransaction("del", @_);
}

sub AddTransaction
{
	if (! $TRANSACTION_LOG) {
		return;
	}
	my($op, $filename, $fileType);
	$op = shift @_;
	$filename = shift @_;
	$fileType = shift @_;
	if (!defined($fileType)) {
        lstat($fullFilename);
		if (-f _) {
			$fileType = "f";
		} elsif (-d _) {
			$fileType = "d";
		} elsif (-l _) {
			$fileType = "l";
		} else {
			$fileType = "u";  # unknown
		}
	}

	print "incoming op = '$op' filename = '$filename' fileType = '$fileType'\n" if ($DEBUG);
	my($baseDir);
	if ($TRANSLOG_DIR eq "") {
		# We're suppose to put the transaction in the directory
		# where we installed the file.
		$baseDir = &path::head($filename);
		$filename = &path::tail($filename);
	} else {
		#if filename is prefixed by TRANSLOG_DIR...
		if (&path::isDirPrefixOf($TRANSLOG_DIR, $filename)) {
			$baseDir = $TRANSLOG_DIR;

			#remove the TRANSLOG_DIR prefix:
			$filename = substr($filename, length($TRANSLOG_DIR));
			$filename = &path::remove_initial_PS($filename);

			#if the directory we are installing IS the TRANSLOG_DIR...
			if ($fileType eq "d" && $filename eq ""){
				$filename = $DOT;
			}
		} else {
			if ($fileType eq "d"){
				#create transaction log in destination dir:
				$baseDir = $filename;
				$filename = $DOT;
			} else {
				$baseDir = &path::head($filename);
				$filename = &path::tail($filename);
			}
			#print "poke 20\n" if ($DEBUG);
			printf STDERR ("%s: BUILD_WARNING: TRANSLOG_DIR (%s) is not a prefix of the destination - using destination.\n", $p, $TRANSLOG_DIR, $baseDir) unless($QUIET);
		}
		print "filename = $filename\n" if ($DEBUG);
	}
	
	my($trans) = "$op:$fileType:$filename";
	print "baseDir='$baseDir' trans='$trans'\n" if ($DEBUG);
	if (!defined($TRANSACTION_LIST{$baseDir})) {
		$TRANSACTION_LIST{$baseDir} = $trans;
	} else {
		$TRANSACTION_LIST{$baseDir} .= $; . $trans;
	}
}

#############################################################################
# The routine which takes all of the recorded transactions and puts
# them in the correct transact.log files.
#   trlist has 1 element per file to put into the transact.log
#       <op>:<crc>:<filename>
#   eg: add:acb45c:/vanish/dist/bin/bld/cmn/foo
#   translogDir is the prefix of every filename (eg: /vanish/dist)
#############################################################################
sub write_transactions
	# This routine has been depricated in favor of transact.pl
{
	return;
	local($translogDir, $comment, @trlist) = @_;
	local($op, $file, $dir, $i, $trfn, $fileList, $found, $uid,
		  $curTime, $crcValue);
	local(%dirToTransLog);
	local($errorCount) = 0;

	$uid = $ENV{'USER'} || $ENV{'LOGNAME'} || "unknown";
	$crcValue = 0;
	@trlist = sort @trlist;
	
	# For every file, we want to find it's transact.log and put it
	# in there as a new transaction.

	# Go through our list of new transactions and figure out which
	# transact.log is going to get that transaction.  Build up a list
	# of all directories where we're going to touch a transact.log
	foreach $opfile (@trlist) {
		($op, $crcValue, $file) = split(":", $opfile, 3);
		print "opfile = $opfile op = $op crcValue = $crcValue file = $file\n" if ($DEBUG);

		# For every file, figure out where it's transact.log is, then
		# build up a list of which files go into which transact.log.
		local($trfn, $theRest);
		if ($translogDir eq "") {
			# We're suppose to put the transaction in the directory
			# where we installed the file.
			local($i);
			@splitFile = &path'path_components($file);
			$theRest = $splitFile[$#splitFile];
			$theRest = &path'remove_initial_PS($theRest);
			$i = $#splitFile-1;
			$trfn = &path'mkpathname(join("", @splitFile[0..$i]), $TRANSACTION_LOGNAME);
		} else {
			if (substr($file, 0, length($translogDir)) eq $translogDir) {
				$theRest = substr($file, length($translogDir));
			} else {
				@splitFile = &path'path_components($file);
				$theRest = $splitFile[$#splitFile];
			}
			$theRest = &path'remove_initial_PS($theRest);
			# print "theRest = $theRest\n" if ($DEBUG);
			$trfn = &path'mkpathname($translogDir, $TRANSACTION_LOGNAME);
		}
		if (defined($dirToTransLog{$trfn})) {
			$dirToTransLog{$trfn} .= $; . $theRest;
		} else {
			$dirToTransLog{$trfn} = $theRest;
		}
		$fileOperation{$theRest} = $op;
		$fileCrc{$theRest} = $crcValue;
	}

	# Now go through each directory where there's a transact.log and
	# append the transaction that we just did.
	foreach $dir (keys %dirToTransLog) {
		print "\nUpdating transaction log $dir\n" unless $QUIET;

		# The following do loop is here just in case someone else is
		# installing at the same time.  We repeat the reading of the
		# file, until no one else is around.
		# This undef needs to be outside of this do loop, because if
		# it were inside, then we might be forgetting some
		# transactions that we read the first time and were not put
		# back in by the other guy.
		undef @transactionList;
		local($circleCount) = 0;
		do {
			# Now load in the transaction log, add to it, and then write
			# it back out.
			if (-e $dir) {
				if (open(TRANSACT, $dir)) {
					push(@transactionList, <TRANSACT>);
					close(TRANSACT);
					local($rmFileCount);
					$rmFileCount = unlink $dir;
					if ($rmFileCount != 1) {
						print STDERR "ERROR: unable to remove '$dir'\n";
						++$errorCount;
						last;
					}
				} else {
					print "ERROR: $p: unable to open $dir for read.\n";
				}
			}
			
			# Get rid of invalid lines.  Valid lines must begin with a
			# number.
			@transactionList = grep(/^[0-9]/, @transactionList);
			
			# If we were better about this, we would do more
			# than get rid of duplicate entries.  If we have multiple
			# transactions on the same file, then we can ignore
			# previous operations and only write out the last one.
			# ... But we would lose history that way, so we don't
			# really want to do that.
			@transactionList = sort numerically @transactionList;
			
			local($lastTransNum);
			$lastTransNum = $transactionList[$#transactionList];
			if (defined($lastTransNum)) {
				$lastTransNum =~ s/\s.*//;
				if ($lastTransNum eq "") {
					$lastTransNum = 0;
				}
			} else {
				$lastTransNum = 0;
			}
			++$lastTransNum;
			# print "lastTransNum = '$lastTransNum'\n";
			$fileList = $dirToTransLog{$dir};
			foreach $file (split($;, $fileList)) {
				# The addition/modification of a file is recorded as
				# <transact#> <operation> <filename>  in transact.log
				print "$op $file\n" if ($DEBUG);
				$op = $fileOperation{$file};
				$crcValue = $fileCrc{$file};
				$fileType = "u";
				if (!defined($op)) {
					print STDERR "ERROR: the operation for $file is not defined.\n";
					++$errorCount;
				} elsif ($op eq "") {
					print STDERR "ERROR: the operation for $file is $op\n";
					++$errorCount;
				} else {
					$curTime = time;
					push(@transactionList, $lastTransNum . " $op $file $uid $curTime $crcValue $fileType # $comment\n");
				}
			}

			if (!grep(/^\s*[0-9]+\s+create/, @transactionList)) {
				$curTime = time;
				print "Create time not found in log, inserting a time of $curTime\n"  if ($DEBUG);
				unshift(@transactionList, "1 create $curTime $uid $curTime 0 c # $comment\n");
			}

			if (-e $dir) {
				# What is it doing back here?  We just deleted it.
				# Someone else must be installing at the exact same time.
				print "There appears to be someone else installing at this\n" unless $QUIET;
				print "time into $dir.  I will try again.\n" unless $QUIET;
				if ($circleCount > 9) {
					print STDERR "ERROR: Unable to install '$dir', giving up.\n";
					++$errorCount;
					last;
				}
				sleep 5;
			}
		} while (-e $dir);
		
		# write it back out....
		# print  @transactionList;
		if (!open(TRANSACT, ">$dir")) {
			print STDERR "BUILD_ERROR: $p: unable to open $dir for write: $!\n";
			++$errorCount;
			return 1;
		}
		print TRANSACT @transactionList;
		close(TRANSACT);

		if ($bTRANSACTION_LOG) {
			my($btransLog) = &path::mkpathname(&path::head($dir), $bTRANSACTION_LOGNAME);
			print "bTRANSACTION_LOG is on, btransLog=$btransLog\n" if ($DEBUG);
			if (! -e $btransLog) {
				require "transact.pl";
				$errorCount += &transact::CreateTransactLog($btransLog);
			}
		}
	}
	return $errorCount;
}

sub usage
{
	local($status) = @_;

    print <<"!";
Usage:  $p [-n] [-v] [-q] [-d] [-u] [-udiff] [-m mode] [-f dir_mode]
           [-uninstall|-diff|-tgz|-untgz|-rmtgz] 
           [-check {-perlCheck perlExecutable | -noPerlCheck}]
           [-map map_file] [-base install_base] [-ime] [-inef] [-p[rintmap]]
           [-cvsdest]
           [-transact] [-btransact] [-trans transact_log] [-batroot dir]
           [-text {mac|dos|unix}] [-server {kshare}]
           variable=value... files... dest_directory

Options:
 -d     debug - display potentially useful internal information.
 -n     do nothing except echo install commands (implies -v flag).
 -q     quiet - display errors only.
 -u     update only if target is older or doesn't exist.
 -udiff update only if target is different.
 -v     verbose - display install commands.
 -check perform various static checks where possible (for .prl and .pl files,
        run perl -c to check syntax).
 -diff  Instead of installing files, produce a diff between the local
        and installed files.
 -uninstall
        Instead of installing files, remove them from the installation
        area.  Update the transaction log if transaction logging enabled.
 -tgz   Instead of installing files into a directory, we put them into
        a tared and gziped archive file instead.
 -untgz Explode a tared and gziped archive under a directory.
 -rmtgz Uninstall a tared and gzip archive.
 -inef  Ignore nonexistant files; ie, print no error messages about files
        which were requested to be installed, but we can't read.
 -f dir_mode
        force the creation of <dest_directory>, mode <dir_mode>.
 -m mode
        set files to <mode> in <dest_directory>.  Must be octal, e.g., 0775.
 -base install_base
        install all files as specified in install map relative to <install_base>.
        REQUIRED if -map argument specified.
 -ime   ignore map-file errors:  use entry in <map_file> if it exists,
        otherwise install in <dest_directory>.
 -map map_file
        install files as specified in <map_file>, relative to <install_base>,
        which must be specified.  If a file has no entry in <map_file>, then
        it is installed in <dest_directory>.
 -printmap, -p
        print a mapping between the local files and the installed files:
        FORMAT:  (destdir_basename, local_filename, dest_filename, dest_dir, mode).
        NOTE:  the destdir_basename is by convention the install platform.
        Example:  /local/tools/bin/solaris --> solaris.
        HINT:  this is an excellent option for verifying install actions
        prior to execution.
 -batroot
        Files with the bat munge can have the root directory changed with
        this option.  The batroot is the eventual directory from where the
        bat file will be run.  Default is $BATROOT
 -cvsdest
        Create or update CVS repository to use as a distribution technology.
        NOTE:  cannot select -cvsdest and -transact.
 -leaveClearText
        If -cvsdest, then don't remove clear text files upon commit.
        Useful for installing configuration files in the CVSROOT directory.
 -transact
        Update the transaction log with the new files.  (See also pullDist).
        NOTE:  cannot select -cvsdest and -transact.
 -btransact
        Create a btransact.log file (see also pullSource).
 -trans transact_log
        use transact_log as the transaction log name instead of transact.log
 -text os
        translate each installed file to the local text conventions of <os>,
        which must be one of: {mac, dos, unix}.
 -server server_product
        configure destination file for a format compatible with <server_product>.
        If server_product is 'kshare', .hqx source files are translated to kshare
        format, and text file (type,creator) values are set to MPW defaults.
variable=value...
        Set <variable> to <value> in the context of the install map.

Environment:
  \$TRANSLOG_DIR     Defines base directory for transaction logging.  Required
                    if -transact option is specified.  Can be passed on command
                    line or defined in the environment.

Notes:
  Install map destinations should agree with command line destinations.
  A warning is displayed if the calculated destinations do not agree.

Example:
  $p -f 0775  -m 0555 toolmap.dat cmd1.prl cmd2.prl /tmp/testing

  $p -f 0775 -m 0555 -transact -map install.map -base \$DISTROOT
         TRANSLOG_DIR="" TARGET_OS=cmn cmd1.prl cmd2.prl \$DISTROOT/tools/bin/cmn

  $p -f 0775 -m 0555 -cvsdest -map install.map -base \$CVS_DISTROOT
         TARGET_OS=cmn lib1.pl lib2.pl \$CVS_DISTROOT/tools/lib/cmn

!

    return($status);
}

sub parse_args
#	Process command line arguments.
{
	local($arg);

	return (&usage(1)) if ($#ARGV +1 < 2);

	$MAPFILE = ""; $HAVE_MAP = 0;
	$MODE = "0664";
	$DIR_MODE = "0775";
	$IGNORE_MAP_ERRORS = 0;
	$IGNORE_NONEXISTANT_FILES = 0;
	$FORCE_DIR = 0;
	$VERBOSE = 0;
	$TRANSACTION_LOG = 0;
	$BASE = "";
	$DEST = "";
	@FILES = ();
	$TEXT_TARGET = -1;
	$SUFFIX_MAP = "";
	$CVSDEST = 0;		#true if we are to create CVS root for distribution.
	$LEAVE_CLEAR_TEXT = 0;

	#constants for "-server" arg.
	$SERVER_TARGET = -1;
	$KSHARE = 100;

    while ($arg = shift @ARGV) {
		if ($arg eq "-map") {
			return &usage(1) if ($#ARGV < 0);
			$MAPFILE = shift(@ARGV);
			$HAVE_MAP = 1;
		} elsif ($arg eq "-cvsdest") {
			$CVSDEST = 1;
		} elsif ($arg eq "-leaveClearText") {
			#leave clear text when we ci files, useful for creating files in CVSROOT
			$LEAVE_CLEAR_TEXT = 1;
		} elsif ($arg eq "-server") {
			return &usage(1) if ($#ARGV < 0);
			$arg = shift(@ARGV);
			if ($arg =~ /^kshare/i) {
				$SERVER_TARGET = $KSHARE;
				if (!&kshare_installed) {
					#error message handled by subroutine.
					return 1;
				}
				&url'set_kshare_server();	#set url encoding conventions for kshare
			} else {
				printf STDERR ("%s: -server: bad arg, %s\n", $p, $arg);
				return &usage(1);
			}
		} elsif ($arg eq "-text") {
			return &usage(1) if ($#ARGV < 0);
			$arg = shift(@ARGV);
			if ($arg =~ /^mac/i) {
				$TEXT_TARGET = $MACINTOSH;
			} elsif ($arg =~ /^dos/i) {
				$TEXT_TARGET = $NT;
			} elsif ($arg =~ /^unix/i) {
				$TEXT_TARGET = $UNIX;
			} else {
				printf STDERR ("%s:  -text: bad arg, %s\n", $p, $arg);
				return &usage(1);
			}
		} elsif ($arg eq "-suffix_map") {
			$SUFFIX_MAP = shift @ARGV;
		} elsif ($arg eq "-m") {
			return &usage(1) if ($#ARGV < 0);
			if ($ARGV[0] !~ /^[0-7]+$/) {
				print STDERR "$p: invalid octal number to -m: '$ARGV[0]'\n";
				return &usage(1);
			}
			$MODE = shift(@ARGV);
		} elsif ($arg eq "-base") {
			return &usage(1) if ($#ARGV < 0);
			$BASE = shift(@ARGV);
		} elsif ($arg eq "-ime") {
			$IGNORE_MAP_ERRORS = 1;
		} elsif ($arg eq "-inef") {
			$IGNORE_NONEXISTANT_FILES = 1;
		} elsif ($arg eq "-v" || $arg eq "-verbose") {
			$VERBOSE = 1;
			$ig'VERBOSE = 1;
		} elsif ($arg eq "-gate") {
			
		} elsif ($arg eq "-u") {
			$UPDATE = 1;
		} elsif ($arg eq "-udiff") {
			$UPDATEDIFF = 1;
		} elsif ($arg eq "-n" || $arg eq "-t" || $arg eq "-test") {
			$TEST = 1;
			$VERBOSE = 1;	#-n implies -v
			$ig'VERBOSE = 1;
		} elsif ($arg eq "-p" || $arg eq "-printmap") {
			$PRINTMAP = 1;
			$QUIET = 1;
			$UPDATE = 0;
			$UPDATEDIFF = 0;
			$TEST = 1;   # -p implies -n & -q & -nocheck
			$CHECK = 0;
			$TRANSACTION_LOG = 0;
		} elsif ($arg eq "-batroot") {
			$BATROOT = shift @ARGV;
		} elsif ($arg eq "-f") {
			return &usage(1) if ($#ARGV < 0);
			if ($ARGV[0] !~ /^[0-7]+$/) {
				print STDERR "$p: invalid octal number to -f: '$ARGV[0]'\n";
				return &usage(1);
			}
			$DIR_MODE = oct($ARGV[0]); shift(@ARGV);
			$FORCE_DIR = 1;
		} elsif ($arg eq "-transact") {
			$TRANSACTION_LOG = 1;
		} elsif ($arg eq "-btransact") {
			$bTRANSACTION_LOG = 1;
		} elsif ($arg eq "-trans") {
			$TRANSACTION_LOGNAME = shift @ARGV;
		} elsif ($arg eq "-uninstall") {
			$OPERATION = "uninstall";
		} elsif ($arg eq "-diff") {
			$OPERATION = "diff";
		} elsif ($arg eq "-untar") {
			$OPERATION = "untar";
		} elsif ($arg eq "-untgz") {
			$OPERATION = "untgz";
		} elsif ($arg eq "-tgz") {
			$OPERATION = "tgz";
		} elsif ($arg eq "-rmtgz") {
			$OPERATION = "rmtgz";
		} elsif ($arg eq "-check") {
			$CHECK = 1;
		} elsif ($arg eq "-nocheck") {
			$CHECK = 0;
		} elsif ($arg eq "-perlCheck") {
			return &usage(1) if ($#ARGV < 0);
			$PERL_CHECKER = shift(@ARGV);
			$DO_PERL_CHECK = 1;
			# print("The -perlCheck flag processed\n");
		} elsif ($arg eq "-noPerlCheck") {
			$DO_PERL_CHECK = 0;
		} elsif ($arg eq "-perl4check") {
			$PERL4CHECK = 1;
		} elsif ($arg eq "-noperl4check") {
			$PERL4CHECK = 0;
		} elsif ($arg eq "-q") {
			$QUIET = 1;
		} elsif ($arg eq "-d" || $arg eq "-debug") {
			$DEBUG = 1;
			$ig'DEBUG = 1;
		} elsif ($arg eq "-h" || $arg eq "-help") {
			return &usage(2);
		} elsif ($arg =~ /=/) {
			# It's a variable declaration.  Example:
			#  VAR = nt,rs6000,solsparc,alphaosf
			local($varName, $value) = ($arg =~ /(\S+)\s*=\s*(.*)/);
			$VARDEFS{$varName} = $value;
			$ENV{$varName} = $value;
			print "From $arg, setting VARDEFS{$varName} to be '$VARDEFS{$varName}'\n" if ($DEBUG);
		} elsif ($arg =~ /^-/) {
			printf STDERR ("%s: unknown argument: '%s'\n", $p, $arg);
			return &usage(1);
		} else {
			if ($#ARGV+1 == 0) {
				$DEST = $arg;
			} else {
				push(@FILES, $arg);
				$FILE_IN_INSTALLMAP{$arg} = 0;
			}
		} 
    }

	@FILES = &sp::uniq(@FILES);  # uniq will sort as well
	if ($OS != $UNIX) {
		local(@tmp) = split('\/', $DEST);
		$DEST = &path'mkpathname(@tmp);
	}

#printf STDERR ("MODE=%o DIR_MODE=%o DEST=%s\n", $MODE, $DIR_MODE, $DEST);

	if ($TEXT_TARGET >= 0) {
		if ($SUFFIX_MAP eq "") {
			printf STDERR "BUILD_ERROR: $p: With the -text option, you need to specify the -suffix_map option.\n";
			return 1;
		}
		return 1 if &suffix'ReadSuffixDat($SUFFIX_MAP);
	}
	
	return 0;
}

sub check_args
#check validity of arguments.  returns 0 if no errors.
{
	my ($nerrs) = 0;

	if ($HAVE_MAP && !-r $MAPFILE) {
		if ($IGNORE_MAP_ERRORS) {
			#pretend the arg wasn't there - for support of makefile-based installs:
			$HAVE_MAP = 0; $MAPFILE = "";
		} else {
			printf STDERR ("%s: can't access map file, '%s'\n", $p, $MAPFILE);
			++$nerrs
		}
	}

	if ($HAVE_MAP) {
		#if map file okay, and no BASE, then show error:
		if ($BASE eq "") {
			printf STDERR (
				"%s: can't use map file, '-base <install_base>' not specified.\n", $p);
			++$nerrs;
		}
		printf STDERR ("%s: Installing files relative to $BASE\n", $p) if ($VERBOSE);
	}


	if (!$IGNORE_NONEXISTANT_FILES) {
		# Verify that all files which are suppose to be there really are there.
		for $ff (@FILES) {
			next if (-r $ff);
			
			# the file is not readable:
			printf STDERR ("BUILD_ERROR: %s: file '%s' isn't readable.\n", $p, $ff);
			print STDERR "option -inef might help.\n";
			++$nerrs;
		}
	}

	if ($CVSDEST) {
		if ($TRANSACTION_LOG) {
			printf STDERR "%s:  cannot select both -cvsdest and -transact options.\n", $p;
			++$nerrs;
		}

		if ($TEXT_TARGET >= 0) {
			printf STDERR "%s:  -cvsdest and -text <OS> options are incompatible.\n", $p;
			++$nerrs;
		}
		if ($SERVER_TARGET >= 0) {
			printf STDERR "%s:  -cvsdest and -server <SERVER_PRODUCT> options are incompatible.\n", $p;
			++$nerrs;
		}

		if ($BASE eq "") {
			printf STDERR "%s:  -cvsdest requires -base \$CVS_DISTROOT arg.\n", $p;
			++$nerrs;
		}

		#check to see that we have the correct version of RCS co/ci commands:
		my ($rcsvers, $cc);
		for $cc ("co", "ci", "rcs") {
			$rcsvers = `2>&1 $cc -V`;
			$rcsvers = (split("\n", $rcsvers))[0];
			if ($rcsvers ne "RCS version 5.7") {
				printf STDERR "%s:  -cvsdest requires rcs version 5.7.  %s -V returned: '%s'\n", $p, $cc, $rcsvers;
				++$nerrs;
			}
		}
	} else {	#!CVSDEST
		if ($TRANSACTION_LOG && !defined($TRANSLOG_DIR)) {
			printf STDERR "%s:  -transact option requires environment variable TRANSLOG_DIR\n", $p;
			++$nerrs;
		}

		if ($LEAVE_CLEAR_TEXT) {
			printf STDERR "%s: WARNING: -leaveClearText ignored since -cvsdest not selected\n", $p;
		}
	}


	return ($nerrs);
}

sub cmd_alias
{
	local($alias) = @_;

	if (defined($CMD_ALIAS_LIST{$alias})) {
		return $CMD_ALIAS_LIST{$alias};
	}

	#return unmodified command:
	return $alias;
}

sub numerically
	#compare two strings numerically, assuming each starts with a
	#string of digits.  will not work for decimal numbers or if
	#strings start with whitespace.
{
	($c = $a) =~ s/\D.*//;
	($d = $b) =~ s/\D.*//;
	if ($c eq "") {
		$c = 0;
	}
	if ($d eq "") {
		$d = 0;
	}
	# print "numerically: c = '$c' d = '$d'\n" if ($DEBUG);
	$c <=> $d;
}

sub cvsrepos_okay
#return true if cvs repository is correctly configured.
#create the repository via cvs init if it does not yet exist.
{
	local ($BASE) = @_;
	my ($cvsdist_repos) = &path'mkpathname($BASE,"CVSROOT");
	my ($historyfn) = &path'mkpathname($cvsdist_repos,"history");
	my ($cmd);

	if (-d $cvsdist_repos && -w $historyfn ) {
		return 1;	#declare the cvs repository healthy.
	}

#printf "expr=%d\n", (-d $cvsdist_repos && -w $historyfn )?1:0;
#printf "-d $cvsdist_repos=%d\n", (-d $cvsdist_repos)?1:0;
#printf "-w $historyfn=%d\n", (-w $historyfn )?1:0;

	######
	#check permissions on CVSROOT/history. the above tests only spot checks for 
	#a proper CVSROOT.  We could have a proper CVSROOT, but not have proper permissions.
	######

	# if history file exists, but we can't write it...
	if (-d $cvsdist_repos && -f $historyfn && ! -w $historyfn ) {
		#... then we may have a proper CVSROOT, but no write permission:
		printf "\nBUILD_ERROR: %s: '%s' is not writable - check process permissions.\n", $p, $historyfn;
		return 0;
	}

	### if we get here, we know:
	### 1.  the CVSROOT directory may or may not exist.
	### 3.  CVSROOT/history file may be missing or have wrong permissions
	### based on this, we either have a fouled up CVSROOT, or we need to do cvs init.
	### if it is fouled up, then the cvs init will fail.

	if (!-d $BASE) {
		if (&os'createdir($BASE, $DIR_MODE)) {
			print "\nBUILD_ERROR: $p: cannot create base directory, $BASE\n";
			return 0;
		}
	}

	print "\nInitializing CVSROOT in $BASE\n" unless ($QUIET);
	$cmd = "cvs -d $BASE init";
	if (&os'run_cmd($cmd, $VERBOSE)) {
		print "BUILD_ERROR: $p: error creating CVS repository in $BASE\n";
		return 0;
	}

	return 1;		#cvs init worked okay.
}

sub cvs_checkin
# deposit a revision in the named rcs file. initialize the rcs
# file if it doesn't exist.
#
# returns non-zero and removes rcs file if errors.
# note that this is only used for distrubutions, so the ,v file is
# not precious.
{
	my ($dstFile, $cvsdstFile, $leave_cleartxt) = @_;
	my ($kwarg) = "-ko";	#cvs default for text files

	if (!defined($dstFile) || !defined($cvsdstFile) || !defined($leave_cleartxt) ) {
		printf "Usage: cvs_checkin(file, cvs_archive, leave_cleartext {1=yes, 0=no})\n";
		return 1;
	}

	my ($cioptions) = "";
	$cioptions = "-u" if ($leave_cleartxt);

	$kwarg = "-kb" if (-B $dstFile);

	#initialize the ,v if it doesn't exist:
	if (!(-e $cvsdstFile)) {
		$cmd = "rcs -q -i -L -t-$p $kwarg $cvsdstFile";
		if (&os'run_cmd($cmd, $VERBOSE)) {
			print "\nBUILD_ERROR: $p: error creating rcs file, $cvsdstFile\n";
			unlink($cvsdstFile);
			return 1;
		}
	}

	#lock the file in preparation to checkin:
	$cmd = "rcs -q -l $cvsdstFile";
	if (&os'run_cmd($cmd, $VERBOSE)) {
		print "\nBUILD_ERROR: $p: error locking rcs file, $cvsdstFile\n";
		unlink($cvsdstFile);	#might work next time...
		return 1;
	}

	#TODO:  beef up log message.
	#check it in:
	$cmd = "ci -f -q $cioptions -m$p $dstFile $cvsdstFile";
	if (&os'run_cmd($cmd, $VERBOSE)) {
		print "\nBUILD_ERROR: $p: error checking in rcs file, $cvsdstFile\n";
		unlink($cvsdstFile);	#might work next time...
		return 1;
	}

	return 0;
}

1;
