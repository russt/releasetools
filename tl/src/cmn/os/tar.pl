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
# @(#)tar.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# tar.pl
# to deal with tar and tar-gzip files

package tar;

&init;
sub init
{
	&'require_os;

	$DEBUG = 0;
	
	$OS = $'OS;
	$UNIX = $'UNIX;
	$MACINTOSH = $'MACINTOSH;
	$NT = $'NT;

	# We need GNU tar.
	$tar = "tar";
	print "tar = '$tar'\n" if ($DEBUG);
	$gzip = "gzip";
}

sub tar_gzip
{
	local($tgzFile, @fileList) = @_;
	my($cmd, $file);
	$cmd = "$tar czf '$tgzFile'";
	foreach $file (@fileList) {
		$cmd .= " '$file'";
	}

	return &os'run_cmd($cmd, $DEBUG);
}

sub untar_gzip
	# untar & gzip a file (requires gnu tar to be installed on the system)
	# .tgz -> exploded contents
	# The second argument (list of files to extract) is optional.
{
	local($tarFile, @files) = @_;
	my($cmd, $file);
	$cmd = "$tar xzf '$tarFile'";
	foreach $file (@files) {
		$cmd .= " '$file'";
	}
	
	return &os'run_cmd($cmd, $DEBUG);
}

sub tar_update
	# add a file to a preexisting tar file
{
	local($tarFile, @fileList) = @_;
	my($cmd, $file);
	$cmd = "$tar rf '$tarFile'";
	foreach $file (@fileList) {
		$cmd .= " '$file'";
	}

	return &os'run_cmd($cmd, $DEBUG);
}

sub tar_delete
	# remove a file from a preexisting tar archive
{
	local($tarFile, @fileList) = @_;
	my($cmd, $file);
	$cmd = "$tar --delete -f '$tarFile'";
	foreach $file (@fileList) {
		$cmd .= " '$file'";
	}

	return &os'run_cmd($cmd, $DEBUG);
}

sub tar_gzip_contents
	# Return a list which is the contents of a tar & gziped file.
{
	local($tarFile) = @_;

	local($result, @contents);

	print "$tar tzf $tarFile\n" if ($DEBUG);
	system "fwhich $tar" if ($DEBUG);
	system "fwhich gzip" if ($DEBUG);
	# system "pwd" if ($DEBUG);
	
	$result = `$tar tzf $tarFile`;
	@contents = split("\n", $result);
# 	foreach $con (@contents) {
# 		print "con = '$con'\n";
# 	}
	return @contents;
}

sub tar
{
	local($tarFile, @fileList) = @_;
	my($cmd, $file);
	$cmd = "$tar cf '$tarFile'";
	foreach $file (@fileList) {
		$cmd .= " '$file'";
	}

	return &os'run_cmd($cmd, $DEBUG);
}

sub untar
	# untar a file
	# .tar -> exploded contents
	# The second argument (list of files to extract) is optional.
{
	local($tarFile, @files) = @_;
	my($cmd, $file);
	$cmd = "$tar xf '$tarFile'";
	foreach $file (@files) {
		$cmd .= " '$file'";
	}
	
	return &os'run_cmd($cmd, $DEBUG);
}

sub gzip
{
	local($normFile, $outFile) = @_;

	return &os'run_cmd("$gzip --stdout $normFile >$outFile", $DEBUG);
}

sub gunzip
{
	local($gzFile, $outFile) = @_;

	return &os'run_cmd("$gzip -d --stdout $gzFile >$outFile", $DEBUG);
}

sub tar_contents
	# Return a list which is the contents of a tared file.
{
	local($tarFile) = @_;

	local($result, @contents);

	$result = `$tar tf $tarFile`;
	@contents = split("\n", $result);
# 	foreach $con (@contents) {
# 		print "con = '$con'\n";
# 	}
	return @contents;
}

1;
