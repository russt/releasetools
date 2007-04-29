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
# @(#)oscmn.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# oscmn.pl
# things common to all os's yet still part of the os class

package os;

&init;
require "path.pl";

sub init
{
	$p = $'p;
# print "unix.pl: p = $p\n";
	$OS = $'OS;
	$UNIX = $'UNIX;
	$NT = $'NT;
	$MACINTOSH = $'MACINTOSH;
	$PS_OUT = $'PS_OUT;

	$DEBUG = 0;
	$cachePwd = 0;
	$CachedPwd = "";

	$BUFFERSIZE = 32768;

	$USER_NAME = "NULL";
}

sub login_name
#see if we can figure out the login name of a user.
{
	return $USER_NAME unless ($USER_NAME eq "NULL");	#already figured it out

    ####
    # $< is $REAL_USER_ID
    # $> is $EFFECTIVE_USER_ID
    ####


	$USER_NAME = getpwuid($>);	#note - using getpwuid in scalar context
	return $USER_NAME unless !defined($USER_NAME);

	$USER_NAME = $ENV{"USER"};
	return $USER_NAME unless !defined($USER_NAME);
	
	$USER_NAME = $ENV{"LOGNAME"};
	return $USER_NAME unless !defined($USER_NAME);

	$USER_NAME = "no_name";
	return $USER_NAME;
}

sub error
{
	local($msg) = @_;
	print "BUILD_ERROR: $p: $msg\n";
}

sub warning
{
	local($msg) = @_;
	print "BUILD_WARNING: $p: $msg\n";
}

sub RunSkel
	# Run a prlskel program as if you ran it thru the system command,
	# but we require it in instead.
	# If given a single argument, it is split on whitespace similar to
	# a normal shell; however, quotes and escape characters are ignored.
	# If given a list, the first element is the package and the rest are
	# the arguments.
	#   eg: &RunSkel("bldmsg -mark hi")
	#   eg: &RunSkel("bldmsg", "-mark", "hi")
	#   eg: @a = (""bldmsg", "-mark", "hi"); &RunSkel(@a)
{
	local(@cmdList) = @_;

	if ($#cmdList+1 <= 0) {
		# we can run nothing very quickly
		return 0;
	} elsif ($#cmdList+1 == 1) {
		my($cmd) = $cmdList[0];
		$cmd =~ s/^\s+//;
		$cmd =~ s/\s+$//;
		@cmdList = split(/\s+/, $cmd);
	}
	my($pkg) = shift @cmdList;
	# It's possible that the perl modules that we call thru run_pkg
	# could change pwd, so we remember what it is and go back to it
	# after running the command.  This needs to be done, since we're
	# suppose to be simulating the system command (which would
	# preserve that).
	my($prevDir) = &path::pwd;

	my($ret);
	$ret = &::run_pkg($pkg, *cmdList, *ENV);
	&chdir($prevDir);
	return $ret;
}

sub AmIOwner
	# Am I the owner of a file/dir?
{
	local($filename) = @_;
	local($fileOwner) = (stat($filename))[4];
	if ($fileOwner == $<) {
		return 1;
	} else {
		return 0;
	}
}

sub MakeMeOwner
	# Make me the the owner of a file.
{
	local($filename) = @_;
	if (&AmIOwner($filename)) {
		return 0;
	}
	if (&rename($filename, "$filename.mmo$$")) {
		return 1;
	}
	if (&copy_file("$filename.mmo$$", $filename)) {
		&rename("$filename.mmo$$", $filename);
		return 1;
	}
	if (&copy_attribs("$filename.mmo$$", $filename)) {
		&rename("$filename.mmo$$", $filename);
		return 1;
	}
	&rmFile("$filename.mmo$$");
	return 0;
}

sub copy_attribs
	# Copy permission bits
	# Copy time/date stamp
	# This command doesn't seem to work under NT (utime fails).
{
	local($infile, $outfile) = @_;
	local($mode, $t);

	$mode = &mode($infile);
	$t = &modTime($infile);
	return 1 if &chmod($outfile, $mode);
	if (!utime($t, $t, $outfile)) {
		&error("Failed to reset time of $outfile to $t");
		return 1;
	}
	return 0;
}

sub copy_file
# Copy infile to outfile
{
	local($infile, $outfile) = @_;
	local($binary) = 0;
	local($ret);

	if (! -r $infile) {
		&error("$infile is not readable, cannot copy.");
		return 1;
	}
	if (-B $infile) {
		$binary = 1;
		print "$infile is a binary file.\n" if ($DEBUG);
	}
	if (&rmFile($outfile)) {
		printf STDERR ("%s (copy_file):  can't remove file '%s'\n", $p, $outfile);
		print STDERR "while trying: cp $infile $outfile\n";
		return 1;
	}
	if ($OS == $MACINTOSH) {
		local($errstr) = &MacPerl::FileCopy($infile, $outfile, 1);
		if ($errstr ne $outfile) {
			printf STDERR ("Copy failed, %s -> %s, error '%s'\n", $infile, $outfile, $errstr);
		}
	} else {
		if (!open(INFILE, $infile)) {
			&error("open failed on $infile for read: $!");
			return 1;
		}
		binmode INFILE if ($binary);
		if (!open(OUTFILE, ">$outfile")) {
			&error("open failed on $outfile for write: $!");
			return 2;
		}
		binmode OUTFILE if ($binary);

		$ret = &copy_filehandles(*OUTFILE, *INFILE);

		close(OUTFILE);
		close(INFILE);
	}

	return $ret;
}

sub copy_filehandles
# copy from IN to OUT
# where IN & OUT are filehandles
{
	local(*OUT, *IN) = @_;
	
    local ($nbytes, $totalbytes, $buf) = (0,0,"");

	# -B is not implemented on the version of perl we have for NT
	# Nor on some flavors of unix (dguxi86), this binmode thing is really
	# only used on nonunix machines.
	if ($OS == $NT) {
		binmode IN;
		binmode OUT;
	}
    while ($nbytes = read(IN, $buf, $BUFFERSIZE)) {
		# print $buf if ($DEBUG);
		print OUT $buf;
		$totalbytes += $nbytes;
    }

	if (!defined($nbytes)) {
		#read returns undef on error
		&error("error reading input file.");
		return(3) 
	}
	return 0;
	
}

sub read_file2str
### note - this routine does EOL translation by default.
{
    return &do_read_file2str(@_, 0);		## binmod == 0
}

sub read_binfile2str
### note - this routine treats input as BINARY file
{
    return &do_read_file2str(@_, 1);		## binmod == 1
}

sub write_str2file
### note - this routine does EOL translation by default.
{
    return &do_write_str2file(@_, 0);		## binmod == 0
}

sub write_binstr2file
### note - this routine treats output as BINARY file
{
    return &do_write_str2file(@_, 1);		## binmod == 1
}

sub do_read_file2str
# read a file into a string
# note that the string is passed via reference
# input: (string_to_write_into, infile name)
# output: 0 = okay, 1 = unable to open infile, 3 = read returned error
{
    local (*buf, $infile, $binmode) = @_;

	if (!open(INFILE, $infile)) {
		&error("open for read failed on '$infile': $!");
		return(1);
	}

	binmode INFILE if ($binmode);

	local(@rec) = stat INFILE;
	local($filesize) = $rec[7];

	$buf = "";
    local ($nbytes, $totalbytes, $mybuf) = (0,0,"");

    $nbytes = read(INFILE, $buf, $filesize);

#printf "read_file2str filesize=%ld nbytes=%d\n", $filesize, $nbytes;

	close INFILE;

	if (!defined($nbytes)) {
		#read returns undef on error
		&error("error reading input file.");
		return(3) 
	}

    return(0);
}

sub do_write_str2file
# write a string out to a file
# note that the string is passed via reference
# input: (string_to_write_out, outfile name)
# output: 0 = okay, 1 = unable to open infile, 3 = read returned error
{
	local(*buf, $outfile, $binmode) = @_;

	if (!defined($buf)) {
		&error("write_str2file: (outfile=$outfile) buf=undef");
		return 1;
	}
	if ($NOP_FLAG) {
		&error("target untouched (TESTING).\n");
		return(0);
	}

	chmod(0777, $outfile);
    unlink ($outfile);
	if (!open(OUTFILE, ">$outfile")) {
		&error("open for write failed on '$outfile': $!\n");
		return(2);
	}

	binmode OUTFILE if ($binmode);
	print OUTFILE $buf;
	
	close(OUTFILE);
	
	return 0;
}

sub append_str2file
# append a string out to a file
# note that the string is passed via reference
# input: (string_to_append_out, outfile name)
# output: 0 = okay, 1 = unable to open infile, 3 = read returned error
{
	local(*buf, $outfile) = @_;

	if (!defined($buf)) {
		&error("append_str2file: (outfile=$outfile) buf=undef");
		return 1;
	}
	if ($NOP_FLAG) {
		&error("target untouched (TESTING).\n");
		return(0);
	}

	if (!open(OUTFILE, ">>$outfile")) {
		&error("open for append failed on '$outfile': $!\n");
		return(2);
	}

	print OUTFILE $buf;
	
	close(OUTFILE);
	
	return 0;
}

sub cat
# similar to the UNIX cat command
# read a file and print it out to STDOUT
{
	local($filename, $quiet_arg) = @_;
	my($quiet) = (defined($quiet_arg) && $quiet_arg);

	if (!open(INFILE, $filename)) {
		if (!$quiet) {
			&error("open failed on $filename for read: $!");
		}
		return 1;
	}
	local($ret);
	$ret = &copy_filehandles(STDOUT, INFILE);
	close(INFILE);
	return $ret;
}

sub touch
{
	local($filename) = @_;
	local($thetime, $ntouched) = (0,0);
	
	if (! -e $filename) {
		if (!open(OUT, ">$filename")) {
			&error("touch: couldn't create $filename: $!");
			return 1;
		}
		close(OUT);
	} else {
		$thetime = time;
		$ntouched = utime($thetime, $thetime, $filename);

		if ($ntouched < 1) {
			&error("touch: couldn't touch $filename: $!");
			return 1;
		}
	}

	return 0;
}

sub chmod
#return 0 on success
{
	my($filename, $mode, $quiet_arg) = @_;
	my($quiet) = (defined($quiet_arg) && $quiet_arg);
	
	#NOTE: perl chmod returns the number of files converted successfully -
	#we reverse this logic to be like the unix system call.

	if (chmod($mode, $filename) != 1) {
		#if not quiet...
		if (!$quiet) {
			local($errMsg);
			$errMsg = sprintf("chmod to mode 0%o failed on file '$filename': %s\n",
							  $mode, $!);
			&error($errMsg);
		}

		return 1;	#FAILURE
	}

	return 0;	#SUCCESS
}

sub SymbolicChmod
	# $mode can be
	#   [ugoa]{+|-|=}[rwx]
	#   eg: a-w
	#   eg: u+w
{
	my($filename, $mode) = @_;
	return &run_cmd("chmod $mode $filename", 0);
}

sub MakeWritableJustMe
	# Basically do
	#    chmod go-w $filename
	#    chmod u+w $filename
{
	my($filename, $quiet_arg) = @_;
	my($quiet) = (defined($quiet_arg) && $quiet_arg);
	my($mode) = &mode($filename);
	if (!defined($mode)) {
		return 1;
	}
	$mode &= 0755;
	$mode |= 0200;
	return &chmod($filename, $mode, $quiet);
}

sub MakeNotWritable
	# Basically do
	#    chmod a-w $filename
{
	my($filename, $quiet_arg) = @_;
	my($quiet) = (defined($quiet_arg) && $quiet_arg);
	my($mode) = &mode($filename);
	if (!defined($mode)) {
		return 1;	#FAILURE
	}
	$mode &= 0555;
	return &chmod($filename, $mode, $quiet);
}

sub IsOwnerWritable
	# Can the owner of $filename write to it?
{
	my($filename) = @_;
	my($mode) = &mode($filename);
	return undef if (!defined($mode));
	if ($mode & 0200) {
		return 1;
	}
	return 0;
}

sub IsGroupWritable
	# true if a file/dir is group writable.
{
	my($filename) = @_;
	my($mode) = &mode($filename);
	return undef if (!defined($mode));
	if ($mode & 0020) {
		return 1;
	}
	return 0;
}

sub IsOtherWritable
	# true if a file/dir is writable by others.
{
	my($filename) = @_;
	my($mode) = &mode($filename);
	return undef if (!defined($mode));
	if ($mode & 0002) {
		return 1;
	}
	return 0;
}

sub IsAnyWritable
	# true if the write bit is set for owner, group, or others.
{
	my($filename) = @_;
	my($mode) = &mode($filename);
	return undef if (!defined($mode));
	if ($mode & 0222) {
		return 1;
	}
	return 0;
}

sub chgrp
{
	local($grp, $file) = @_;

	if ($OS == $UNIX || $OS == $NT) {
		return &run_cmd("chgrp $grp $file", 0);
	}
	return 0;
}

sub rename
{
	local($oldname, $newname) = @_;
	
	if (rename($oldname, $newname) != 1) {
		print "Failed to rename $oldname to $newname failed (will try to use copy): $!\n" if ($DEBUG);
	    # &error("The renaming of $oldname to $newname failed: $!");
	    &os'rmFile($newname);
	    if (&copy_file($oldname, $newname)) {
			&error("Failed to cp $oldname $newname");
			return 1;
		}
	    if (&copy_attribs($oldname, $newname)) {
			&error("Failed to cpmode $oldname $newname");
			return 1;
		}
	    if (-e $newname) {
		    # before getting rid of the old one, make sure the new one exists
		    &os'rmFile($oldname);
		} else {
			&error("Failed to rename $oldname to $newname failed: don't know why");
		}
	}
	return 0;
}

sub chdir
{
	local($dir) = @_;
	
	if ($cachePwd && $CachedPwd eq $dir) {
		return 0;
	}
	if (!chdir($dir)) {
		&error("Failed to chdir into '$dir': $!");
		return 1;
	}
	if ($cachePwd) {
		if (&path'isfullpathname($dir)) {
			$CachedPwd = $dir;
		} else {
			$CachedPwd = &path'pwd;
		}
	}
	return 0;
}

sub CachePwdOn
{
	$CachedPwd = &path::pwd;
	$cachePwd = 1;
}

sub CachePwdOff
{
	$cachePwd = 0;
}

sub rmFile
	# Try our best to remove a file.
{
	local($filename) = @_;
	local($deletedCount);
	
	if (! -e $filename && ! -l $filename) {
		return 0;
	}
	CORE::chmod(0777, $filename);
	$deletedCount = unlink $filename;
	if ($deletedCount < 1) {
		if ($OS == $UNIX) {
			system "ls -l $filename";
		}
		&error("unable to remove $filename");
		return 1;
	}
	return 0;
}

sub rmDir
{
	local($dirName) = @_;

	if (! -e $dirName) {
		return 0;
	}
	if (!rmdir($dirName)) {
		&error("unable to remove directory $dirName: $!");
		return 1;
	}
	return 0;
}

sub mkdir_p
	# Make directories
{
	local($fullDir, $mode) = @_;
	local(@dirList, $curDir, $dir);

	if (!defined($mode)) {
		&error("mkdir_p: dir='$fullDir', but mode is undefined");
		return 1;
	}
	if ($mode == 0) {
		&error("mkdir_p: dir='$fullDir', but mode is bad: '$mode'");
		return 1;
	}
	# Remove extra slashes.
	$fullDir =~ s#//+#/#g;
	# print "DEBUG:oscmn: $fullDir\n";
	@dirList = split('/', $fullDir);
	$curDir = "";
	my($append_slash);
	for ($ii = 0; $ii <= $#dirList; ++$ii) {
		$dir = $dirList[$ii];

		# Distingish between rooted and non-rooted directory paths.
		if ($dir eq "" ) {
			$curDir .= "/";
			next;
		}

		# Perl (5.001) mkdir on Windows 2000 requires a "/" after
		# a drive letter and colon (ie D:/).
		print "DEBUG/oscmn'mkdir_p: ii=$ii dir=$dir\n" if ($DEBUG);
		if ($ii == 0 && $dir =~ m@^[a-zA-Z]:$@ ) {
			$curDir .=  $dir . "/";
			$append_slash=0;
		} else {
			$curDir .=  $dir;
			$append_slash=1;
		}

		if (! -d $curDir) {
			print "DEBUG/oscmn'mkdir_p: $curDir $mode\n" if ($DEBUG);
			if ( -e $curDir ) {
				&error("Cannot create directory in place of file '$curDir'.");
				return 1;
			} elsif (!mkdir($curDir, $mode)) {
				&error("Failed to mkdir $curDir: $!");
				return 1;
			}
		}

		if ($append_slash == 1) {
			$curDir .= "/";
		}
	}
	return 0;
}

sub symlink
{
	local($f1, $f2) = @_;

	if (-e $f2 || -l $f2) {
		# print "Removing $f2\n";
		&rmFile($f2);
	}
	if (!symlink($f1, $f2)) {
		&error("Failed to symlink $f1 $f2: $!");
		return 1;
	}
	return 0;
}

sub ChaseSymlink
	# Chase thru symlinks until we reach a nonsymlink (be it a real file
	# or something else).
	# You should test the result for undef or possible to see if no changes
	# were made.
{
	my($lnk) = @_;
	
	my($prevLnk);
	while (-l $lnk) {
		$prevLnk = $lnk;
		$lnk = readlink($prevLnk);
		if (! &path::isfullpathname($lnk)) {
			$lnk = &path::mkpathname(&path::head($prevLnk), $lnk);
		}
	}
	return &path::ParseRelativePathName($lnk);
}

sub cmpFiles
	# Compare 2 files.  Return 0 if same.  1 if different.  -1 for error.
{
	local($file1, $file2) = @_;

	if (! -e $file1 || ! -e $file2) {
		&error("$file1 or $file2 does not exist.");
		return -1;
	}
	if (-s $file1 != -s $file2) {
		# different sizes mean that they are different.
		return 1;
	}
	if (!open(INFILE1, $file1)) {
		&error("open failed on $file1 for read: $!");
		return -1;
	}
	if (!open(INFILE2, $file2)) {
		&error("open failed on $file2 for read: $!");
		return -1;
	}
	local($ret);
	$ret = &cmpFileHandles(*INFILE1, *INFILE2);
	close(INFILE1);
	close(INFILE2);

	return $ret;
}

sub cmpFileHandles
	# Compare 2 files by reading from their file handles.
	# Return 0 if same.  1 if different.  -1 for error.
{
	local(*INFILE1, *INFILE2) = @_;
	local($nbytes1, $buf1) = (0, "");
	local($nbytes2, $buf2) = (0, "");

	while (1) {
		$nbytes1 = read(INFILE1, $buf1, $BUFFERSIZE);
		$nbytes2 = read(INFILE2, $buf2, $BUFFERSIZE);
		if (!defined($nbytes1) || !defined($nbytes2)) {
			&error("error reading input file.");
			return -1;
		}
		print "nbytes1 = $nbytes1 nbytes2 = $nbytes2\n" if ($DEBUG);
		if ($nbytes1 != $nbytes2) {
			# One of them hit an EOF, while the other didn't
			return 1;
		}
		if ($nbytes1 == 0) {
			# Both hit an EOF, if they're not different by this time,
			# then they're not different at all.
			return 0;
		}
		# Now compare the 2 buffers.
		if ($buf1 ne $buf2) {
			return 1;
		}
	}
}

sub cmp_str2file
	# Return 0 if the same
	# Return 1 if different
	# Return -1 if error
{
	local(*buf1, $file2) = @_;
	local($buf2);

	if (! -e $file2) {
		&error("Unable to cmp_str2file, because $file2 doesn't exist.");
		return -1;
	}
	# NT does EOL conversions on a string so that the file size may be
	# different, so we can't trust that they'll necessarily be the same.
	if ($OS != $NT && length($buf1) != -s $file2) {
		return 1;
	}
	if (&read_file2str(*buf2, $file2)) {
		return -1;
	}
	if ($buf1 ne $buf2) {
		return 1;
	}
	return 0;
}

sub cp_recursive
	# Copy the contents of $srcDir into $dstDir
	# eg: &cp_recursive("$SRCROOT/regress/log", "/tmp/regress/log");
{
	local($srcDir, $dstDir) = @_;
	local($errorCount) = 0;
	
	print "cp_recursive: $srcDir $dstDir\n" if ($DEBUG);
	lstat($srcDir);
	if (-d _) {
		$errorCount += &mkdir_p($dstDir, 0777);

		local($file);
		local(@listing) = ();
		&path'ls(*listing, $srcDir);
		foreach $file (@listing) {
			$errorCount += &cp_recursive("$srcDir/$file", "$dstDir/$file");
		}
	} elsif (-f _) {
		if ($OS == $NT) {
			$errorCount += &run_cmd("cp -fp $srcDir $dstDir");
		} else {
			$errorCount += &cpAndChk($srcDir, $dstDir);
			$errorCount += &copy_attribs($srcDir, $dstDir);
		}
	} elsif (! -e _) {
		&error("cp_recursive: $srcDir does not exist, cannot copy from it.");
		++$errorCount;
	} elsif (-l _) {
		&error("cp_recursive: $srcDir is a symlink, cannot copy.");
		++$errorCount;
	} else {
		&error("cp_recursive: $srcDir is of a nonstandard file type");
		++$errorCount;
	}
	return $errorCount;
}

sub cp_recursive_newer
	# Copy the contents of $srcDir into $dstDir for every file that is
	# newer than a particular time/date stamp.
	# eg: &cp_recursive_newer("$SRCROOT/regress/log", "/tmp/regress/log", &modTime("/tmp/.last"));
{
	local($srcDir, $dstDir, $partitionTime) = @_;
	local($mtime);
	local($errorCount) = 0;
	
	print "cp_recursive_newer: $srcDir $dstDir\n" if ($DEBUG);
	lstat($srcDir);
	if (-d _) {
		$errorCount += &mkdir_p($dstDir, 0777);

		local($file);
		local(@listing) = ();
		&path'ls(*listing, $srcDir);
		foreach $file (@listing) {
			$errorCount += &cp_recursive_newer("$srcDir/$file",
											   "$dstDir/$file", $partitionTime);
		}
	} elsif (-f _) {
		$mtime = (stat(_))[9];
		# print "mtime = $mtime\n" if ($DEBUG);
		if ($mtime > $partitionTime) {
			print "Doing actual copy\n" if ($DEBUG);
			if ($OS == $NT) {
				$errorCount += &run_cmd("cp -fp $srcDir $dstDir");
			} else {
				$errorCount += &cpAndChk($srcDir, $dstDir);
				$errorCount += &copy_attribs($srcDir, $dstDir);
			}
		}
	} elsif (! -e _) {
		&error("cp_recursive_newer: $srcDir does not exist, cannot copy from it.");
		++$errorCount;
	} elsif (-l _) {
		&error("cp_recursive_newer: $srcDir is a symlink, cannot copy.");
		++$errorCount;
	} else {
		&error("cp_recursive_newer: $srcDir is of a nonstandard file type");
		++$errorCount;
	}
	return $errorCount;
}

sub cpAndChk
	# copy and check
{
	local($srcFile, $dstFile) = @_;
	local($ret);

	if (! -r $srcFile) {
		&error("$srcFile is not readable, I cannot copy it.");
		return 1;
	}
	&rmFile($dstFile);
	$ret = &copy_file($srcFile, $dstFile);
	if ($ret) {
		&error("Failed to copy $srcFile to $dstFile");
		return 1;
	}
	if (&compare($srcFile, $dstFile)) {
		&error("cpAndChk postcondition violated: $srcFile is not the same as $dstFile after a copy");
		if ($OS == $UNIX) {
			system("ls -l $srcFile $dstFile");
		}
		return 1;
	}
	return 0;
}

sub modTime
{
	local($filename) = @_;

	local($STAT_MTIME) = $[ + 9;    #correct index if necessary
	local($mt) = (lstat($filename))[$STAT_MTIME];
	return $mt;
}

sub mode
{
	local($filename) = @_;

	local($STAT_MODE) = $[ + 2;
	local($mode) = (stat($filename))[$STAT_MODE];
	return (defined($mode)? $mode : undef);
}

sub LastLine
	# Return the last line of a text file.
{
	my($filename) = @_;

	my($line, @lines, $pos, $lineCount);
	if (!open(FIN, $filename)) {
		&error("Failed to open $filename for read: $!");
		return "";
	}
	if (-s $filename <= 255) {
		# If it's a small file, we might as well read in the whole file
		# at once (plus it makes the next algorithm a little easier).
		@lines = ();
		push(@lines, <FIN>);
		close(FIN);
		$lineCount = $#lines;
		return $lines[$lineCount];
	}
	# Start at a position of 200 bytes from the EOF.  Work backwards from
	# there until we find that we have at least 1 line.
	$pos = -200;
	while ($pos > -10000) {
		seek FIN, $pos, 2;
		@lines = <FIN>;
		$lineCount = $#lines;
		if ($lineCount > 0) {
			last;
		}
		$pos -= 200;
	}
	#print "pos = $pos lines = (" . join(", ", @lines) . ")\n";
	close(FIN);
	return $lines[$lineCount];
}

sub newerFile
# think of the arguments to this function as existing on a time line,
# from old to new.  Then, the function is true only if the files are placed on
# the time line in the correct order.
#
# NOTE:  if the right file is nil, consider it to be infinitely old.
#			==> incorrect order, ==> false.
#        if the left file is nil, consider it to be infinitely old.
#			==> correct order, ==> true
#
{
	local ($old, $new) = @_;

#printf("\nnewerFile:  old=%s, new=%s\n", $old, $new);

	local($STAT_MTIME) = $[ + 9;	#correct index if necessary
	local($otime, $ntime);

	#new file doesn't exist:
	if (!defined($ntime = (stat($new))[$STAT_MTIME])) {
		return (0);
	}

	#older file doesn't exist:
	if (!defined($otime = (stat($old))[$STAT_MTIME])) {
		return (1);
	}

#printf("otime=%d ntime=%d\n", $otime, $ntime);

	return($otime <= $ntime);
}

sub createdir
# This requires that the full path name be given.
# returns 0 if successful (or if directory already exists).
{
    local ($thedir, $mode) = @_;
	local ($vol) = "";
	printf("createdir: Attempting to create the directory $thedir with mode %o\n", $mode) if ($DEBUG);

	if ($mode == 0) {
		print "WARNING: createdir: mode is $mode, thedir='$thedir'\n";
	}
	if (-d $thedir) {
		#already created
		print "already created dir\n" if ($DEBUG);
		return 0;
	}

	#return(1) if (!&isPathname($thedir));

	$path'DEBUG = 1 if ($DEBUG);
	local(@pathparts);
	@pathparts = &path'path_components($thedir);

	#
	#NOTE:  path_components attempts to normalize path components, so it is
	#		not necessarily an invertible operation.  RT 1/17/93
	#
	if ($DEBUG) {
		printf("thedir='%s' components=(%s)\n", $thedir, join(',', @pathparts));
	}

	if ($#pathparts < 0) {
		return 1;
	}

	my ($ii) = 0;
	if (&path'isVolumeName($pathparts[$ii])) {
		local ($pat) = $'VOLSEP . '$';

		#formulate volume name:
		$vol = $pathparts[$ii];
		$vol .= $'VOLSEP if ($pathparts[$ii] !~ /$pat/);

		printf("isVolume TRUE for '%s' vol='%s' ii=%d stat=%d\n",
			$pathparts[$ii], $vol, $ii, (-d $vol)) if ($DEBUG);

		#volume must exist...
		if (! -d ($vol) && ! -d ($vol . $PS_OUT)) {
			printf("WARNING: createdir: volume '%s' does not exist.\n", $vol);
			# return 1 
		}
		++$ii;
	}
	for (; $ii<= $#pathparts; ++$ii) {
		printf("ii=%d, culmuative='%s'\n", $ii,
					   join('', @pathparts[0..$ii])) if ($DEBUG);

		local($dir) = join('', @pathparts[0..$ii]);
		next if (-d $dir || $dir eq "");

		#otherwise, create the component.  Let mkdir set the mode bits, so that
		#we properly inherit setgid & setuid bits from the parent directory.
		if (!mkdir($dir, $mode)) {
			printf("%s:  couldn't make directory component '%s', error %s\n", "oscmn.pl", $dir, $!);
			return(1);
		}
	}

    return(0);
}

sub setenvdef
{
	local($var, $defaultValue, $package) = @_;
	if (!defined($ENV{$var})) {
		$ENV{$var} = $defaultValue;
		print "$var was defaulted to '$defaultValue'\n" unless $QUIET;
	}
	eval "\$$package\'$var = \"$ENV{$var}\"";
}

sub setenv
{
	local($var, $value, $package) = @_;

	$ENV{$var} = $value;
	eval "\$$package\'$var = \"$value\"";
}

sub multisetenv
{
	local(*table, $pkg) = @_;
	my($var);

	foreach $var (keys %table) {
        print "$var = $table{$var}\n" if ($DEBUG);
		&os'setenv($var, $table{$var}, $pkg);
	}
}

sub requireenv
{
	local($var, $package) = @_;

	if (!defined($ENV{$var})) {
		&error("$var must be defined in your environment.");
		return 1;
	}
	print "\$$package\'$var = \"$ENV{$var}\"\n" if ($DEBUG);
	eval "\$$package\'$var = \"$ENV{$var}\"";
	return 0;
}

sub requiremultienv
	# require in multiple env vars.
	# eg: &os'requiremultienv("main", "SRCROOT", "PATHREF", "FORTE_PORT")
{
	local(@varList) = @_;
	local($pkgName);
	local($result) = 0;

	$pkgName = shift @varList;
	foreach $var (@varList) {
		if (&requireenv($var, $pkgName)) {
			++$result;
		}
	}
	return $result;
}

sub LockFile
# generic file locking routine - attempts, repeatedly, to create $filename.lock, success returns 0
#### IMPORTANT ##### make sure cleanup routine calls UnLockFile if exists  $filename.lock
# when program interrupted
{
	local($Locker, $filename, $maxWait, $auto);
	
	$Locker =  shift @_;
	$filename =  shift @_;
	$maxWait =  shift @_;
	$maxWait = 30 if(! defined($maxWait));
	$auto =  shift @_;
	$auto = 0 if(! defined($auto));
	local($IdOnDisk);
	local($FirstOnDiskId);
	local($Wait) = 0;
	local($Wait_sec);
	local($lockVal);
	
	$lockVal = &getLockFile($Locker, *FirstOnDiskId, "$filename.lock");
	$IdOnDisk = $FirstOnDiskId;
	do {
		if($lockVal > 0) { # true, we got the lock!!
			return 0;
		}
		elsif($lockVal < 0) { # false, some file or system error
			return 1;
		}
		else { # $lockVal = 0, means someone else got lock - wait and try again
			if(defined($IdOnDisk)) {
				print "$IdOnDisk got the lock on $filename.lock "
				. "before we did, retrying.\n";
			}
			else {
				print "Someone else is accessing $filename.lock\n"
				. "Undefined id about who has it locked"
				. " (zero length file ... *is the disk full?*)\n"
				. "Retrying\n";
			}
			srand;
			if( $Wait > $maxWait/2 ) {
			# get more agressive
				$Wait_sec = int(rand 2) + 1;
			}
			else {
				$Wait_sec = int(rand 4) + 1;
			}
			$Wait += $Wait_sec + 1; # the one second is sleep btwn 
			                        # write & verify read of fn getLockFile
			sleep($Wait_sec);
		}
		if($auto && $Wait  > $maxWait ) { # give us the option of explicitly removing lock
			if( $FirstOnDiskId eq $IdOnDisk) { # same person, continue by removing lock file
				if(&os::rmFile("$filename.lock")) {
					&error("Failed to remove lock $filename.lock while attempting to lock");
					return 1;
				}
				$Wait = 0;
			}
		}
		$lockVal = &getLockFile($Locker, *IdOnDisk, "$filename.lock");
	} until ( $Wait > $maxWait );

	&error("Giving up on locking '$filename'.lock, perhaps abandoned lock?\n"
	        . "Retry later...\n");
	return 1;
}

sub getLockFile
# fn trys to open file, if !open & $errno == 2 we write to file
# if succeed - return 1
# if file opens then someone has lock or if  verify of write false someone else got lock - return 0
# if error of read or write return -1 
{
	local($LockId, *IdOnDisk, $lockfilename) = @_;
	local($errorNumber);

	if(! open(LOCKFILE, $lockfilename)) {
		$errorNumber = $!;
	##### critical section here!!!  #####
		if($errorNumber == 2 && open(LOCKFILE, ">$lockfilename")) {
			print LOCKFILE $LockId;
			close LOCKFILE;
			sleep(1); # need to wait as the last one to write in a race cond. wins
			if (open(LOCKFILE, $lockfilename)) {
				$IdOnDisk = <LOCKFILE>;
				close LOCKFILE;
			}
			if ($LockId eq $IdOnDisk) {
				return 1;
			}
			else { # someone else got the lock
				return 0;
			}
		}
		else { # error in read or open for write
			&error("Failed to create lock file '$lockfilename': $!\n");
			return -1;
		}
	}
	else { # someone else got the lock
		$IdOnDisk = <LOCKFILE>;
		close(LOCKFILE);
		return 0;
	}
	
}

sub UnLockFile
# return 0 on success
{
	local($LockId, $filename) = @_;
	local($lockFile) = $filename . ".lock";
	local($onDiskId);

	if(open(LOCKFILE, $lockFile)) {
		$onDiskId = <LOCKFILE>;
		close LOCKFILE;
		if ($LockId eq $onDiskId) {
			if(&os::rmFile($lockFile)) {
				&error("Failed to unlock $filename");
				return 1;
			}
			return 0;
		} else {
			&error("Fatal ERROR!!! this should never happen - inform Tools guardian\nOn Disk id is different for '$lockFile'\n('$onDiskId') expected: '$LockId'.");
			return 1;
		}
	}
	else {
		&error("Fatal ERROR!!! this should never happen - inform Tools guardian\nFailed to read '$lockFile' while trying to unlock it, lock file removed?: $!");
		return 1;
	}
}

sub to_jvm_path
#return input pathname in a form suitable for the java vm.
#this means on cygwin, convert to a dos format path
#example:
#  input:  /tmp/a/foo.txt
#  ouput:  c:/cygwin/tmp/a/foo.txt (cygwin)
#  ouput:  /tmp/a/foo.txt          (non-cygwin)
{
    my ($pathname) = @_;

    if (defined($^O) &&  $^O =~ /cygwin/i) {
        my ($jvpath) =  `cygpath -m "$pathname"`;
        return "NULL_CYGPATH" if ($jvpath eq "");

        #success:
        return $jvpath;
    }

    #if non-cygwin, just return the input:
    return $pathname;
}

1;
