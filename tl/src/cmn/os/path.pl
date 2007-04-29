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
# @(#)path.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# path.pl
# to handle paths (as in a command path)

package path;

require "sp.pl";

&init;
sub init
{
	$PS_IN = $'PS_IN;
	$PS_OUT = $'PS_OUT;
	$CPS = $'CPS;
	$VOLSEP = $'VOLSEP;
	$PATHVAR = $'PATHVAR;
	$DOT = $'DOT;
	$OS = $'OS;
	$UNIX = $'UNIX;
	$MACINTOSH = $'MACINTOSH;
	$NT = $'NT;
	$DOS = $'DOS;

	if ($PS_IN =~ /\[/) {
		# NT, for instance, has a PS_IN with [] in it
		$NOT_PS_IN = $PS_IN;
		$NOT_PS_IN =~ s/^\[/[^/;
	} else {
		$NOT_PS_IN = "[^$PS_IN]";
	}
}

################################ PATH UTILITIES ###############################

sub mkpathname
#convert a list of pathname components to a local path name.
{
	local (@plist) = @_;

	if (!defined(@plist)) {
		my($parentPackage, $parentFile, $parentLine) = caller;
		print(STDERR "BUILD_ERROR: path::mkpathname:",__LINE__,": requires a parameter.  Caller info: parentPackage=$parentPackage parentFile=$parentFile parentLine=$parentLine\n");
		return(undef);
	}

	#strip trailing input path-separators:
	for ($ii=0; $ii<=$#plist; $ii++) {
		if (!defined ($plist[$ii])) {
			print(STDERR "BUILD_ERROR: path::mkpathname:",__LINE__,": passed an undef path component.  Passed:");
	my($elt);
			foreach $elt (@plist) {
				if (!defined ($elt)) {
					print(STDERR "#UNDEF");
				} else {
					print(STDERR "#${elt}");
				}
	}
			my($parentPackage, $parentFile, $parentLine) = caller;
			print(STDERR "  Caller info: parentPackage=$parentPackage parentFile=$parentFile parentLine=$parentLine\n");
			return(undef);
		}			
		$plist[$ii] =~ s=${PS_IN}$==;
	    # Replace repeat separators with just one.
		# Fails on NT: h:[[\\/]]d[[\\/]]bldpath[\\/]
	    # $plist[$ii] =~ s=${PS_IN}+=${PS_IN}=g;
	
	}

	my ($fullpath) = join($PS_OUT, @plist);
	$fullpath =~ s=${PS_OUT}${PS_OUT}*=${PS_OUT}=;
	return($fullpath);
}

sub pickfiles
#pick the plain file entries from a directory listing.
#<lsout> must be in CWD or contain full path refs.
#list returned in <thefiles>.
{
	local (*thefiles, *lsout) = @_;

	@thefiles = grep(!(-d $_), @lsout);
}

sub cached_pwd
{
	if ($os::cachePwd) {
		# print "cached pwd = $os'CachedPwd\n";
		return $os::CachedPwd;
	}
	return &pwd;
}

sub pwd
#return full pathname of current working directory.
{
	local ($tmp);
	if ($OS == $UNIX) {
		$tmp = (`pwd`);
		chop $tmp;
		return($tmp);
	}
	if ($OS == $MACINTOSH) {
		$tmp = (`Directory`);
		chop $tmp;
		$tmp =~ s/:$//;		#make sure no trailing :
		return($tmp);
	}
	if ($OS == $NT || $OS == $DOS) {
		$tmp = (`pwd`);
		chop $tmp;
		return($tmp);
	}

	return("NULL");		#not handled
}

sub ls
#<lsout> <-- `ls <dir>`
{
	local (*lsout, $dir) = @_;
	local ($openfail) = 0;

	if (!opendir(DIR, $dir)) {
		$openfail = 1;
		if ($OS == $NT || $OS == $DOS) {
			#try again, with an appended ".":
			$openfail = 0 if (opendir(DIR, $dir . "."));
		}
	}

	if ($openfail) {
		print STDERR "ERROR opening directory '$dir'\n";
		@lsout = ();
		return;
	}

	#skip drivers on mac, '.' & '..' on unix
	if ($OS == $MACINTOSH) {
		@lsout = readdir(DIR);
	} else {
		@lsout = grep(!/^\.\.?$/,readdir(DIR));
	}

	closedir(DIR);
}

sub ls_all
#<lsout> <-- `ls <dir>`
#include special entries.
{
	local (*lsout, $dir) = @_;

	if (!opendir(DIR, $dir)) {
		@lsout = ();
		return;
	}

	@lsout = readdir(DIR);

	closedir(DIR);
}

sub AnyFilesNewerThan
	# Goes off and tries to find a file which is newer than a particular
	# time.  Returns the name of the file if found; otherwise, "" if
	# no file is found which is newer.
{
	local($dir, $mtime, *pruneTable) = @_;
	local(@listOfFiles) = ();
	local(@dirList) = ();
	local($file, $ret);
	print "AnyFilesNewerThan: dir = '$dir' mtime = '$mtime'\n" if ($DEBUG);
	if ($DEBUG) {
		foreach $file (keys %pruneTable) {
			print "pruneTable{$file} = $pruneTable{$file} ";
		}
		print "\n";
	}
	
	&ls(*listOfFiles, $dir);
	foreach $file (@listOfFiles) {
		if (defined($pruneTable{$file})) {
			print "Skipping $file\n" if ($DEBUG);
			next;
		} elsif ($DEBUG) {
			print "Didn't skip $file: " . &tail($file) . "\n";
		}
		$file = &mkpathname($dir, $file);
		print "Testing $file\n" if ($DEBUG);
		lstat($file);
		if (-d _) {
			push(@dirList, $file);
		} elsif ((lstat(_))[9] > $mtime) {
			return $file;
		}
	}
	foreach $file (@dirList) {
		$ret = &AnyFilesNewerThan($file, $mtime, *pruneTable);
		if ($ret) {
			return $ret;
		}
	}
	return "";
}

sub path_components
#input:  a full path name
#output:  a list of path components
#E.g. (unix):  /foo/x  ==> ("/foo", "/x")
#E.g. (mac):  foo:x  ==> ("foo", ":x")
{
	local($dir) = @_;
	local(@tmp) = ();

#printf ("OS=%d PS_OUT=%s\n", $OS, $PS_OUT);

	if ($OS == $MACINTOSH) {
		#FORM 1:  mac.  starts with volume name
		
		$_ = $dir;

		#dir name contains  "::"
		if (/${PS_OUT}${PS_OUT}/) {
			printf STDERR
			("path_components (path.pl): can't handle relative directory name, '%s'\n", $dir);
			return("");
		}

		#form "dir" --> ":dir"
		if ( /^[^${PS_OUT}]+$/ ) {
#print "CASE I\n";
			return ($PS_OUT . $dir);
		}

		#form "dir:" --> "dir"	(volume name)
		if ( /^[^${PS_OUT}]+${PS_OUT}$/ ) {
#print "CASE II\n";
			s/${PS_OUT}$//;
			return ($_);
		}
		
		#now we have one of:
		#  A.  :dir (:dir)*
		#  B.  dir (:dir)*

		if (s/(^$PS_OUT[^$PS_OUT]+)//) {
#printf ("(form :x) path='%s' 1='%s'\n", $dir, $1);
			@tmp = ($1);
		} elsif (s/(^[^$PS_OUT]+)//) {
#printf ("(form x :?) path='%s' 1='%s'\n", $dir, $1);
			@tmp = ($1);
		} else {
			printf STDERR
			("path_components (path.pl): ERROR: no starting match, '%s'\n", $dir);
			return("");
		}

		while (s/(^$PS_OUT[^$PS_OUT]+)//) {
			@tmp = (@tmp, $1);
		}
		
		return(@tmp);
	} else {
		#FORM 2:  Unix-style path name:
		if ($dir eq $PS_OUT || $dir eq "") {
			return ($dir);
		}

		# print "dir = '$dir'\n" if ($DEBUG);

		local($driveName);
		local(@dirList);
		
		@dirList = split($PS_IN, $dir);
 		if ($#dirList + 1 <= 0) {
 	        @tmp = ($dir);
 			return (@tmp);
 		}
		$driveName = shift @dirList;
		if ($driveName ne "") {
			push(@tmp, $driveName);
		}
		foreach $dd (@dirList) {
			next if ($dd eq "");
			push(@tmp, $PS_OUT . $dd);
		}

        print "path_components: $dir -> (" . join(", ", @tmp) . ")\n" if ($DEBUG);
	    return(@tmp);
    }

	return("");
}

sub isDirPrefixOf
#true if <aa> is a directory prefix of <bb>
#e.g., /tmp/foo is a prefix of /tmp/foo/aa, but not of /tmp/foo2/bb
{
	local($aa, $bb) = @_;
	local(@ap) = &path_components($aa);
	local(@bp) = &path_components($bb);

#printf STDERR "isDirPrefixOf: aa='%s', bb='%s', ap=(%s) bp=(%s)\n", $aa, $bb, join(',',@ap), join(',',@bp);

	return 0 if ($#bp < $#ap);	#bb isn't long enough

	local($astr) = join("", @ap[0..$#ap]);
	local($bstr) = join("", @bp[0..$#ap]);

	if ($OS != $MACINTOSH) {
		return 1 if ($astr eq $PS_OUT && $bstr =~ /^$PS_OUT/);	#root is a prefix of all
	}

	return ($astr eq $bstr);
}


sub mklocalpath
	# convert a pathname with forward slashes in it to the local conventions
{
	local($filename) = @_;
	local($local_ps) = $PS_IN;
	if ($local_ps =~ /\[/) {
		$local_ps =~ s#[\[\]/]##g;
		$local_ps =~ s#\\\\#\\#g;
	}
	$filename =~ s#/#$local_ps#g;
	return $filename;
}

sub mkportablepath
	# Convert from the local format (backslashes on nt, colons on mac) to
	# the "portable" (unix) format with forward slashes.
{
	my($filename) = @_;
	$filename =~ s#$PS_IN#/#g;
	return $filename;
}

sub cmp
	# compare 2 filenames, return 0 for the same
{
	local($p1, $p2) = @_;
	local($i, $top);
	local(@p1_comps, @p2_comps);
	
	if ($p1 eq $p2) {
		return 0;
	}
	@p1_comps = &path_components($p1);
	@p2_comps = &path_components($p2);
	if ($#p1_comps != $#p2_comps) {
		return 1;
	}
	$top = $#p1_comps;
	for ($i = 0; $i <= $top; ++$i) {
		# print "p1_comps[$i] = $p1_comps[$i]  p2_comps[$i] = $p2_comps[$i]\n";
		if ($p1_comps[$i] ne $p2_comps[$i]) {
			return 1;
		}
	}
	return 0;
}

sub isfullpathname
{
	local($filename) = @_;

	local($volStart) = 0;
	if ($OS == $NT) {
		# "/tmp" is a full pathname
		if ($filename =~ /^$PS_IN/) {
			return 1;
		}
		# "h:/tmp" is a full pathname
		$volStart = 1;
	}

	if (substr($filename, $volStart, length($VOLSEP)) eq $VOLSEP) {
		return 1;
	}
	return 0;
}

sub head
# Return the basename of a pathname.
# ie, the dir part minus the file part
{
	local($fullfilename) = @_;

	if ($fullfilename !~ /$PS_IN/) {
		return $DOT;
	}
	$fullfilename =~ s#${PS_IN}${NOT_PS_IN}*$##;
	if ($fullfilename eq "") {
		if ($OS == $NT) {
			return "/";
		} else {
			return $VOLSEP;
		}
	}
	return $fullfilename;
}

sub tail
# Return the rightmost component of a pathname.
# ie, the file part minus the dir part
{
	local($fullfilename) = @_;

	if (!defined($fullfilename)) {
		#my($package, $filename, $line) = caller();  # perl 5 or greater
		print "package = $package filename = $filename line = $line\n";
	}
	$fullfilename =~ s#^.*${PS_IN}##;
	return $fullfilename;
}

sub suffix
#return the suffix portion of a string (delinated by "."), or "" if none.
{
	local ($fn) = @_;
	local (@xx) = split('\.', $fn);
	return (($#xx <= 0)? "" : $xx[$#xx]);
}

sub prefix
#return the prefix portion of a string (delinated by "."), or "" if none.
{
	local ($fn) = @_;
	local (@xx) = split('\.', $fn);
	if ($#xx+1 == 0) {
		return "";
	}
	return $xx[0];
}

sub remove_initial_PS
	#   /foo/bar   -> foo/bar
	#   foo/bar    -> foo/bar
{
	local($file) = @_;
	$file =~ s#^(${PS_IN}|${PS_OUT})##;
	return $file;
}

sub isVolumeName
{
	local($dir) = @_;
	if ($'OS == $'NT && $dir =~ /${VOLSEP}/) {
	    return 1;
    } elsif ($'OS == $'MACINTOSH && ($dir !~ /${VOLSEP}/ || $dir =~ /${VOLSEP}$/)) {
		#of the form 'disk' or 'disk:'
	    return 1;
	}
    return 0;
}

sub ParseRelativePathName
	# Normalize a filename.
	#  dir1/dir2/../file.c -> dir1/file.c
	#  dir1/dir2/dir3/../../file.c -> dir1/file.c
	#  dir1/../foo.cc
	#  dir/./file.c -> dir/file.c
	#  dir//foo.cc -> dir/foo.cc
{
	my($dirfile) = @_;
	#  dir1/dir2/../file.c -> dir1/file.c
	while ($dirfile =~ s#[^/]+\/\.\.\/##) {
	}
	$dirfile =~ s#\.\/##g;    #   dir/./file.c -> dir/file.c
	$dirfile =~ s#\/\/#/#g;
	if ($dirfile eq "") {
		$dirfile = $DOT;
	}
	return $dirfile;
}

sub GetFullFileName
{
	local($fn) = @_;

	if (&isfullpathname($fn)) {
		return $fn;
	}
	if ($fn =~ /^\.$/) {
		return &cached_pwd;
	}

	return &mkpathname(&cached_pwd, $fn);
}

sub which
# Looks for a file in the current path (similar to csh's which
# command).  If found, we return the full filename.  If not found, we
# return "".
{
	local($file) = @_;
	local(@exeSuffix);
	local($location, $ext);

	if ($OS == $NT || $OS == $DOS) {
		@exeSuffix = ("", ".exe", ".ksh", ".bat");
	} else {
		@exeSuffix = ("");
	}
	foreach $ext (@exeSuffix) {
		$location = &which_file($file . $ext, $PATHVAR);
		if ($location ne "") {
			# found it
			return $location;
		}
	}
	return "";
}

sub which_file
# we assume that the env var is separated by $CPS
{
	local($file, $envvar) = @_;
	local($varValue, $fullfilename, $dir);
	
	$varValue = $ENV{$envvar};
	foreach $dir (split($CPS, $varValue)) {
		$fullfilename = $dir . $PS_OUT . $file;
		# print "Is $fullfilename the file that I want?\n";
		if (-r $fullfilename) {
			return $fullfilename;
		}
	}
	return "";
}

1;
