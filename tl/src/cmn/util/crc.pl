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
# @(#)crc.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# crc.pl
# for calculating CRC's (similar to a checksum)
# 32 bit CRC algorithm taken from Dr. Dobb's Journal.

package pcrc;

$DEBUG = 0;
$done_init = 0;
&init;

sub main
{
    local(*ARGV, *ENV) = @_;
    local($file, $crc, $errorCount);

    $whichCrc = "perl";
    &init;
    $errorCount = 0;

    while ($file = shift @ARGV) {
        if ($file eq "-useSystem") {
            $whichCrc = "system";
            next;
        }
        if (! -r $file) {
            print STDERR "$file is not readable\n";
            ++$errorCount;
            next;
        }
        if (-d $file) {
            print STDERR "$file is a directory, can't get the crc of it.\n";
            ++$errorCount;
            next;
        }
        $crc = &CalculateFileCRC($file);
        printf("%s %x\n", $file, $crc);
    }
    return $errorCount;
}

sub init
{
    $p = $'p;
    $OS = $'OS;
    $NT = $'NT;
    
    $SystemCrcOptions = "";
    
    # Default to using the system crc if it exists, since it's
    # compiled and so will run much faster.
    if (!defined($whichCrc)) {
        require "path.pl";

        if ($'OS != $'MACINTOSH && &path'which("crc") ne "") {
            $whichCrc = "system";
            printf("Using system crc located at '%s'\n", &path'which("crc")) if ($DEBUG);
        } else {
            $whichCrc = "perl";
        }
    }
    $CRC32_POLYNOMIAL = 0xEDB88320;
    $readSize = 131072;

    if (!defined($done_init) || ! $done_init) {
        &BuildCRCTable;
    }
    $buffer = "";
    $crcStarted = 0;
    $done_init = 1;
}

sub cleanup
{
    &::dump_inc if ($DEBUG);
}

sub SetForBinary
{
    $SystemCrcOptions = "-binary";
    if ($crcStarted) {
        print CRCCPOUT "-binary\n";
        my($crc);
        $crc = <CRCCPIN>;
        print "pcrc::SetForBinary: Got a return of '$crc'\n" if ($DEBUG);
    }
}

sub SetForText
{
    $SystemCrcOptions =~ s/-binary//g;
    if ($crcStarted) {
        print CRCCPOUT "-unixascii\n";
        my($crc);
        $crc = <CRCCPIN>;
        print "pcrc::SetForText: Got a return of '$crc'\n" if ($DEBUG);
    }
}

sub BuildCRCTable
{
    local($i, $j);
    local($crc, $t);

    for ($i = 0; $i <= 255; ++$i) {
        $crc = $i;
        for ($j = 8; $j > 0; --$j) {
            if ($crc & 1) {
                $t = $crc >> 1;
                # Since in perl we can't necessarily make a int into
                # an unsigned int, when I shift right I have to make
                # sure that the "signed bit" didn't stay in the
                # "signed position".  One way of doing that is to just
                # and off the MSB.
                $t &= 0x7fffffff;
                $crc = $t ^ $CRC32_POLYNOMIAL;
            } else {
                $crc >>= 1;
                $crc &= 0x7fffffff;
            }
            # printf("perl i=%d j=%d crc=%lx\n", $i, $j, $crc);
        }
        $CRCTable[$i] = $crc;
        # printf("CRCTable[%d] = %x\n", $i, $crc);
    }
}

sub CalculateBufferCRC
{
    local($crc) = @_;
    local($index, $temp1, $temp2);

    foreach $cc (unpack("C*", $buffer)) {
        $temp1 = ($crc >> 8) & 0x00FFFFFF;
        $index = (int($crc ^ $cc)) & 0xff;
        $temp2 = $CRCTable[$index];
        $crc = $temp1 ^ $temp2;
    }
    return $crc;
}

sub CalculateStrCRC
{
    local($buffer) = @_;
    local($crc)=0xFFFFFFFF;

    $crc = &CalculateBufferCRC($crc);
    return ($crc ^= 0xFFFFFFFF);
}

sub CalculateFileCRC
{
    local($filename) = @_;
    local($crc, $count, $i, $buf);

    print "whichCrc = $whichCrc filename = '$filename'\n" if ($DEBUG);
    if ($whichCrc eq "system") {
        # Then we call the system version of crc.
        $goodcrc = &SystemCrc($filename, *crc);
        if ($goodcrc) {
            return $crc;
        }
    }
    
    if (!open(FROM, $filename)) {
        return 0;
    }
    binmode FROM;
    $buf = "";
    
    $crc = 0xFFFFFFFF;
    $i = 0;
    while (1) {
        $count = read(FROM, $buffer, $readSize);
        if ((! defined($count)) || ($count == 0)) {
            last;
        }
        $crc = &CalculateBufferCRC($crc);
    }
    close(FROM);
    return (($crc ^= 0xFFFFFFFF) & 0xFFFFFFFF);
}

sub CalculateFileListCRC
    # Attempt to optimize running crc on a list of files by using the
    # special -f argument to crc which will calculate the crc of every
    # file listed.
{
    local(@fileList) = @_;
    local(@crcOutList) = ();
    local($filename);

    if ($whichCrc eq "system") {
        require "os.pl";
        
        # Do them en masse.
        local($inFileList) = &os::TempFile;
        if (!open(OUT, ">$inFileList")) {
            print STDERR "BUILD_ERROR: $p; failed to open $inFileList for write: $!\n";
        } else {
            # We use a table just in case crc returns them out of
            # order or with some missing.
            local(%crcTable) = ();
            foreach $filename (@fileList) {
                print OUT "$filename\n";
                $crcTable{$filename} = 0;
            }
            close(OUT);
            local($sizeIn)= 0;
            local($outCrcList) = &os'TempFile;
            &os'run_cmd("crc $SystemCrcOptions -f $inFileList > $outCrcList"); 
                local($output);
                if (! &os::read_file2str(*output, $outCrcList)) {
                    local(@crcs, @record, $entry, $crcValue);
                    @crcs= split(/\n/, $output);
                    if($#fileList == $#crcs) {
                        grep((@record= split(/\x20{1}/, $_))
                             && ($crcValue= pop(@record))
                             && ($crcTable{join(" ", @record)} = $crcValue)
                             ,  @crcs);
                        #for every file did we get crc back?
                        foreach $filename (@fileList) {
                            print "$filename $crcTable{$filename}\n" if ($DEBUG);
                            push(@crcOutList, $crcTable{$filename});
                        }
                            return @crcOutList;
                    }
                }
        }
    }
    local($Hexval)= "";
    foreach $filename (@fileList) {
        $HexVal= sprintf "%x", &CalculateFileCRC($filename);
        push(@crcOutList, $HexVal );
    }
    return @crcOutList;
}

sub SystemCrc
{
    local($filename, *Crc) = @_;

    # Not implemented for these guys.
    if ($OS == $NT) {
    } elsif (! $crcStarted) {
        # Do a small test run of crc to make sure it's runable
        if (system("crc >/dev/null 2>&1") != 256) {
            print STDERR "BUILD_ERROR: crc failed to run: $!\n";
            $whichCrc = "perl";
            return &CalculateFileCRC($filename);
        }
        # print "ABOUT to startup server1\n";
        select(STDERR); $errFlush = $|; $| = 1;
        select(STDOUT); $outFlush = $|; $| = 1;
        # print something to stdout to actually get a fflush
        print "";
        
        # CRCSPIN  crc server pipe input
        # CRCCPIN  crc client pipe input
        # CRCSPOUT crc server pipe output
        # CRCCPOUT crc client pipe output
        #   server input connects to client output
        #   client input connects to server output
        if (!pipe(CRCSPIN, CRCCPOUT)) {
            print STDERR "failed to create a pipe\n";
            return 0;
        }
        if (!pipe(CRCCPIN, CRCSPOUT)) {
            print STDERR "failed to create a pipe\n";
            return 0;
        }
        $pid = fork;
        if (!defined($pid)) {
            print STDERR "fork failed: $! ($@)\n";
            return 0;
        } elsif ($pid == 0) {
            close(CRCCPOUT);
            close(CRCCPIN);
            select(CRCSPOUT); $| = 1;
            # print STDOUT "Server started 1\n";
            # select(CRCSPIN); $| = 1;
            # switch stdout to the pipe
            open(REAL_STDOUT, ">&STDOUT") || die "failed to create REAL_STDOUT: $!\n";
            open(REAL_STDERR, ">&STDERR") || die "failed to create REAL_STDERR: $!\n";
            open(STDOUT, ">&CRCSPOUT") || die "failed to create STDOUT: $!\n";
            open(STDERR, ">&STDOUT") || die "failed to create STDERR: $!\n";
            &CrcServer;
            exit;
        }
        # print "Client continues\n";
        close(CRCSPOUT);
        close(CRCSPIN);
        # select(CRCCPIN);  $| =1;
        select(CRCCPOUT);   $| =1;
        select(STDERR); $| = $errFlush;
        select(STDOUT); $| = $outFlush;
        $crcStarted = 1;
    }
    
    local($fullFile);
    $fullFile = &path::GetFullFileName($filename);
    if (! -r $fullFile) {
        print STDERR "$p (pcrc.pl): Unable to read '$fullFile'\n";
        return 0;
    }
    
    if ($OS != $NT) {
        # print "Client about to send a '$fullFile'\n";
        print CRCCPOUT "$fullFile\n";
        $Crc = <CRCCPIN>;
        if (!defined($Crc)) {
            return 0;
        }
    } else {
        $Crc = `crc $SystemCrcOptions "$fullFile"`;
    }
    
    print "crc command returned: $Crc" if ($DEBUG);
    if (!defined($Crc)) {
        print STDERR "crc failed: $! ($@)\n";
        return 0;
    }
    if ($Crc !~ /unable to open/) {
        chop($Crc);
        $Crc =~ s/^(.*\s+)+//;
        $Crc= hex($Crc);
        return 1;
#       return hex($crc);
    }
    return 0;
}

sub CrcServer
{
    # print STDERR "Starting up crc\n";

    if (!open(CRCPROG, "|crc $SystemCrcOptions -cont")) {
        print STDERR "BUILD_ERROR: crc failed to start: $!\n";
        return;
    }
    select(CRCPROG); $| = 1;
    select(STDOUT);
    # print REAL_STDERR "CrcServer: started\n";
    while (<CRCSPIN>) {
        # print REAL_STDERR "CrcServer: '$_'\n";
        print CRCPROG;
    }
    # print REAL_STDERR "CrcServer: done\n";
}

sub CalculateBufferChecksum
    # Not implemented
{
}

&squawk_off;
sub squawk_off
{
    if ( 1 > 2) {
        *REAL_STDOUT = *REAL_STDOUT;
        *REAL_STDERR = *REAL_STDERR;
        *p = *p;
    }
}

1;
