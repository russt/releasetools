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
# @(#)transact.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# transact.pl
# deal with the pull transaction logs
#

package transact;

require "os.pl";
require "sp.pl";
require "pcrc.pl";
require "url.pl";

&init;
sub init
{
	$p = $'p;
	$USER = $ENV{"USER"} || $ENV{"LOGNAME"} || "nouser";
	$HOST_NAME = $ENV{"HOST_NAME"} || "nohost";
	$PATHNAME = $ENV{"PATHNAME"} || "nopath";

	$LOCKTRANS = 1; # for NT we will set to 0, FALSE

	$MaxTransactLogSize = (2**20) / 2;   # 1/2Meg
}

sub ReadTransactLog
	# Open up a transact.log file and return it's contents as a list
{
	local($transLog) = @_;

	my(@transList) = ();
	if (!open(IN, $transLog)) {
		&error("Failed to open $transLog for read: $!");
		return undef;
	}
	push(@transList, <IN>);
	close(IN);
	return @transList;
}

sub CompressTransactLog
	# Compress a transact.log file down so that it has no duplicates.
{
	my($transLog) = @_;
	my($origModTime) = &os::modTime($transLog);

	my(@transList);
	&LockDownFile($fullTransact);
	@transList = &ReadTransactLog($transLog);
	@transList = &CompressTransactions(@transList);
	if (!defined($transList[0])) {
		&UnLockDownFile($fullTransact);
		return 1;
	}
	chomp(@transList);
	if (&sp::List2File("$transLog.$$", @transList)) {
		&UnLockDownFile($fullTransact);
		return 1;
	}
	if (&os::rename($transLog, "$transLog.b$$")) {
		&UnLockDownFile($fullTransact);
		return 1;
	}
	if ($origModTime != &os::modTime("$transLog.b$$")) {
		# someone modified it while we were computing
		&os::rename("$transLog.b$$", $transLog);
		&UnLockDownFile($fullTransact);
		return &CompressTransactLog($transLog);
	}
	if (&os::rename("$transLog.$$", $transLog)) {
		&os::rename("$transLog.b$$", $transLog);
		&UnLockDownFile($fullTransact);
		return 1;
	}
	&UnLockDownFile($fullTransact);
	&os::rmFile("$transLog.b$$");
	return 0;
}

sub CompressTransactions
	# Take a list of transactions and compress them so that there is only
	# 1 per file.
{
	my(@transList) = @_;
	my(%fileTrans, %isDuplicate);
	%fileTrans = ();

	my($ii);
	my($trans);
	for ($ii = 0; $ii < $#transList+1; ++$ii) {
		$trans = $transList[$ii];
		$isDuplicate{$ii} = 0;
		if (&ExamineTrans($trans)) {
			return undef;
		}
		if (defined($fileTrans{$TransFile})) {
			#print "$ii supersedes\n";
			$isDuplicate{$fileTrans{$TransFile}} = $ii;
			$fileTrans{$TransFile} = $ii;
		} else {
			$fileTrans{$TransFile} = $ii;
		}
	}
	my(@result);
	@result = ();
	for ($ii = 0; $ii < $#transList+1; ++$ii) {
		if ($isDuplicate{$ii}) {
			next;
		}
		push(@result, $transList[$ii]);
	}
	return @result;
}

sub ExamineTrans
    # Take a transaction line and split it up into the components.
    #  -> $TransNum, $TransOp, $TransFile, $TransUid, $TransTime,
    #       $TransCrcValue, $TransFileType, $TransComment
{
    my($trans) = @_;
    my $trans_without_comment;
    my $pos;
    if (($pos = index($trans, "#")) > -1) {
        $trans_without_comment = substr($trans, 0, $pos);
        $TransComment = substr($trans, $pos);
    } else {
        $trans_without_comment = $trans;
        $TransComment = "";
    }
    ($TransNum, $TransOp, $TransFile, $TransUid, $TransTime, $TransCrcValue, $TransFileType) = split(/\s+/, $trans_without_comment);
    if (!defined($TransCrcValue)) {
        &error("transaction line ('$trans') is invalid.");
        return 1;
    }
    $TransFile = &url::name_decode($TransFile);
    return 0;
}

sub AppendPullTransaction
	# Append a bunch of transaction to a transact.log file.
	#   $transact_log is the name of the transact.log file (typically
	#   just "transact.log", but might be "btransact.log").
	#   $comment is a string which is put into the comment column in the
	#   transact.log file.
	#   %TRANSACTIONS is a reference to an associative array.  The keys
	#   of that array are the base directories, while the data inside
	#   contains a filename relative to the base directory.  The actual
	#   data element is a list hiding in a string separated by $;.  Each
	#   element in that list is a ":" separated pair of operation and
	#   filename: operation, file type, and relative filename.
	#   example:
	#     $TRANSACTIONS{"/forte1/d/tl"}
	#        = "add:f:src/cmn/util/transact.pl$;add:f:src/cmn/util/make.mmf$;del:gone:src/cmn/foo"
	# If all is successful, we reset %TRANSACIONS to ().
{
	local($transact_log, $comment, $doCalcCrc, $isBinary, *TRANSACTIONS) = @_;
	
	local($baseDir, $op, $filename, $crcValue, $transNum, $curTime, $fullTransact, $fileType);
	local(@transactionList, @fileList, @crcList, %filename2op, %filename2type);
	
	foreach $baseDir (sort keys %TRANSACTIONS) {
		$curTime = time;
		@transactionList = ();
		@fileList = ();
		@crcList = ();
		%filename2op = ();
		%filename2type = ();
		# Uniquify our list of pull transactions so that every file
		# has only one operation.
		foreach $trans (split($;, $TRANSACTIONS{$baseDir})) {
			($op, $fileType, $filename) = split(/:/, $trans, 3);
			$filename2op{$filename} = $op;
			$filename2type{$filename} = $fileType;
		}
		if ($doCalcCrc) {
			# Build up the fileList which we're going to get all of the
			# crc's of (only want to do this for files that are changed).
			foreach $filename (sort keys %filename2op) {
				if ($filename2op{$filename} eq "add" &&
					$filename2type{$filename} ne "l" && $filename2type{$filename} ne "d") {
					push(@fileList, &path::mkpathname($baseDir, $filename));
				}
			}
			if ($isBinary) {
				&pcrc::SetForBinary;
			}
			@crcList = &pcrc::CalculateFileListCRC(@fileList);
			if ($isBinary) {
				&pcrc::SetForText;
			}
		}
		
		$fullTransact = &path::mkpathname($baseDir, $transact_log);
		lstat($fullTransact);
		if (-e _) {
			if (-s _ > $MaxTransactLogSize) {
				print "Compressing $fullTransact\n";
				&CompressTransactLog($fullTransact);
			}
			if( $LOCKTRANS ) {
				if(&LockDownFile($fullTransact)) { #failed to lock file
					return 1;
				}
			}
			$transNum = &LastTransNum($fullTransact) + 1;
			if (!open(TRANS, ">>$fullTransact")) {
				&error("Failed to append to $fullTransact: $!");
				if( $LOCKTRANS ) {
					&UnLockDownFile($fullTransact);
				}
				return 1;
			}
		} else {
			$transNum = 1;
			if(&LockDownFile($fullTransact)) { #failed to lock file
				return 1;
			}
			if (!open(TRANS, ">$fullTransact")) {
				&error("Failed to write to $fullTransact: $!");
				if( $LOCKTRANS ) {
					&UnLockDownFile($fullTransact);
				}
				return 1;
			}
			print TRANS "$transNum create $curTime $USER $curTime 0 c # $comment\n";
		}
		
		print "\nWriting transactions for $baseDir\n" if ($DEBUG);
		$crcValue = 0;
		foreach $filename (sort keys %filename2op) {
			$op = $filename2op{$filename};
			$fileType = $filename2type{$filename};
			if ($doCalcCrc) {
				if ($op eq "add" && $fileType ne "l" && $fileType ne "d") {
					$crcValue = shift @crcList;
				} else {
					$crcValue = 0;
				}
			}
	        $filename = &url::name_encode($filename);
			print TRANS "$transNum $op $filename $USER $curTime $crcValue $fileType # $comment\n";
			++$transNum;
		}
		close(TRANS);
		if( $LOCKTRANS ) {
			&UnLockDownFile($fullTransact);
		}
	}
	%TRANSACTIONS = ();
	return 0;
}

sub LastTransNum
	# Given a transact.log file, what is the last transaction number.
{
	my($filename) = @_;

	my($lastLine) = &os::LastLine($filename);
	return (split(/ /, $lastLine, 2))[0];
}

sub CreateTransactLog
{
	my($transLog) = @_;

	if (!open(OUT, ">$transLog")) {
		&error("Failed to open $transLog for write: $!");
		return 1;
	}
	my($curTime) = time;
	print OUT "1 create $curTime $USER $curTime 0 # created\n";
	close(OUT);
	return 0;
}

sub MakeSureTransactLog
	# make sure that the transaction log exists
{
	my($transLog) = @_;

	if (-e $transLog) {
		return 0;
	}
	return &CreateTransactLog($transLog);
}

sub squawk
{
	if (1 > 2) {
		*TransUid = *TransUid;
		*TransNum = *TransNum;
		*DEBUG = *DEBUG;
		*TransOp = *TransOp;
		*TransTime = *TransTime;
	}
}

sub error
{
	local($msg) = @_;

	print "BUILD_ERROR: $p: $msg\n";
}

sub LockDownFile
#### IMPORTANT ##### make sure cleanup routine calls UnLockDownFile if $GotLockOnTran ne ""
# when program interrupted
{
	local($filename) = @_;
	local($myId);
	local($auto) = 1;

	$myId = "user=$USER program=$p host_name=$HOST_NAME pathname=$PATHNAME pid=$$\n";
	if(! &os::LockFile($myId, $filename, 30, $auto)) {
		$GotLockOnTran = $filename;
		return 0;
	}
	return 1;
}

sub UnLockDownFile
{
	local($filename) = @_;
	local($myId);
	$myId = "user=$USER program=$p host_name=$HOST_NAME pathname=$PATHNAME pid=$$\n";

	my($retval) = &os::UnLockFile($myId, $filename);;
	$GotLockOnTran = "";
	return ($retval);
}

sub option_locktrans
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $LOCKTRANS = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_locktrans requires boolean value (0=false, 1=true).\n", $p
;
        return(0);
    }
    return(1);
}

1;
