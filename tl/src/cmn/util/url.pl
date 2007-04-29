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
# @(#)url.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


#TEST PROGRAM:
#for $ff ('foo%20bar', '%xyz', '%%2for1', 'UserStartup%a5russt') {
#	printf("'%s' --> '%s'\n", $ff, &url'name_decode($ff));
#}

package url;

sub main
{
    local(*ARGV, *ENV) = @_;
    local($stat) = 0;
    
    return 1 if &init;
    if (&ParseArgs) {
        return 1;
    }

    my($thing);
    my(@ProcessedThings) = ();
    if($ReadStdin == 0) {
        foreach $thing (@Things) {
            if ($operation eq "encode") {
                push(@ProcessedThings, &name_encode($thing));
            } else {
                push(@ProcessedThings, &name_decode($thing));
            }
        }
        if ($DEBUG) {
            my($count) = 0;
            foreach $thing (@ProcessedThings) {
                print "$count '$thing'\n";
                ++$count;
            }
        }
        if ($ExecuteIt) {
            $stat = system(@ProcessedThings);
            $stat >>= 8;
        } else {
            if ($#Things+1 > 0) {
                print join(" ", @ProcessedThings) . "\n";
            }
        }
    } else {
        while ($thing = <>) {
            chomp($thing);
            if ($operation eq "encode") {
                printf "%s\n", &name_encode($thing);
            } else {
                printf "%s\n", &name_decode($thing);
            }
        }
    }
    return $stat;
}

&init;
sub init
{
	$DEBUG = 0;
	
	$operation = "encode";
	$ExecuteIt = 0;
        $ReadStdin = 0;
	@Things = ();
	
	#list server types here:
	$NULL_SERVER = -1;
	$KSHARE_SERVER = 100;

	$SERVER_TYPE = $NULL_SERVER;

	$FORTE_PORT = $ENV{"FORTE_PORT"} || "unknown";
	@ascii2ebcdic=
		(
		 0, 1, 2, 3, 55, 45, 46, 47, 22, 5, 21, 11, 12, 13, 14, 15, 16, 17, 18, 19, 
		 60, 61, 50, 38, 24, 25, 63, 39, 28, 29, 30, 31, 64, 90, 127, 123, 91, 108, 
		 80, 125, 77, 93, 92, 78, 107, 96, 75, 97, 240, 241, 242, 243, 244, 245, 246, 
		 247, 248, 249, 122, 94, 76, 126, 110, 111, 124, 193, 194, 195, 196, 197, 
		 198, 199, 200, 201, 209, 210, 211, 212, 213, 214, 215, 216, 217, 226, 227, 
		 228, 229, 230, 231, 232, 233, 173, 224, 189, 95, 109, 121, 129, 130, 131, 
		 132, 133, 134, 135, 136, 137, 145, 146, 147, 148, 149, 150, 151, 152, 153, 
		 162, 163, 164, 165, 166, 167, 168, 169, 192, 79, 208, 161, 7, 32, 33, 34, 
		 35, 36, 37, 6, 23, 40, 41, 42, 43, 44, 9, 10, 27, 48, 49, 26, 51, 52, 53, 
		 54, 8, 56, 57, 58, 59, 4, 20, 62, 255, 65, 170, 74, 177, 159, 178, 106, 181, 
		 187, 180, 154, 138, 176, 202, 175, 188, 144, 143, 234, 250, 190, 160, 182, 
		 179, 157, 218, 155, 139, 183, 184, 185, 171, 100, 101, 98, 102, 99, 103, 
		 158, 104, 116, 113, 114, 115, 120, 117, 118, 119, 172, 105, 237, 238, 235, 
		 239, 236, 191, 128, 253, 254, 251, 252, 186, 174, 89, 68, 69, 66, 70, 67, 
		 71, 156, 72, 84, 81, 82, 83, 88, 85, 86, 87, 140, 73, 205, 206, 203, 207, 
		 204, 225, 112, 221, 222, 219, 220, 141, 142, 223
		 );
	if ($FORTE_PORT eq "mvs390") {
		$ebcdic = 1;
	} else {
		$ebcdic = 0;
	}
}

sub Usage
{
	print <<"!"
Usage: $p [-debug] [-help] [-verbose] [-run] [-norun] [-stdin] {-decode|-encode} strings...
!
}

sub ParseArgs
{
	my($arg, $lcarg);
	my($argState) = 0;
	
	while (defined($arg = shift @ARGV)) {
		if ($argState == 0) {
			$lcarg = lc($arg);
			if ($lcarg eq "-help") {
				&Usage;
				return 2;
			} elsif ($lcarg eq "-debug") {
				$DEBUG = 1;
			} elsif ($lcarg eq "-verbose") {
				$VERBOSE = 1;
			} elsif ($lcarg eq "-run") {
				$ExecuteIt = 1;
			} elsif ($lcarg eq "-norun") {
				$ExecuteIt = 0;
			} elsif ($lcarg eq "-stdin") {
				$ReadStdin = 1;
			} elsif ($lcarg eq "-decode") {
				$operation = "decode";
			} elsif ($lcarg eq "-encode") {
				$operation = "encode";
			} else {
				$argState = 1;
				push(@Things, $arg);
			}
		} else {
			push(@Things, $arg);
		}
	}
	return 0;
}

############################################################################

sub set_kshare_server
#call this routine to set output file name conventions
#to the xinet kashare product.
{
	$SERVER_TYPE = $KSHARE_SERVER;
}

sub name_decode
#decode a name with hex specifications.
#E.g., 'foo%20bar'  --> 'foo bar'
#      '%xyz'       --> '%xyz'
#      '%%2for1'    --> '%2for1'
# if FORTE_PORT is "mvs390" we need to do an ASCII conversion
{
	local ($obuf) = @_;
	return ($obuf) if ($obuf !~ /%/);

	local ($cc,$nn);
	local (@ibuf) = ();

	@ibuf = split(//, $obuf);
	$obuf = "";
	local ($ii) = 0;
	local ($len) = $#ibuf;

	while ($ii <= $len) {
		if (($cc = $ibuf[$ii++]) ne '%') {
			$obuf .= $cc;
			next;
		}

		if ($ii > $len) {
			$obuf .= $cc;
			next;
		}

		$cc = $ibuf[$ii++];
		if  ($ii > $len || $cc eq "%" || $cc !~ /[0-9a-fA-F]/) {
			$obuf .= "%";
			$obuf .= $cc unless ($cc eq "%");
			next;
		}

		$nn = $cc;
		$cc = $ibuf[$ii++];

		if  ($cc !~ /[0-9a-fA-F]/) {
			$obuf = "%" . $cc . $nn;
			next;
		}

		$nn .= $cc;		#now $nn has the hex digit string.

		#we have a %<hex> specification - convert to hex:
		$nn =hex($nn);

		if ($SERVER_TYPE == $KSHARE_SERVER) {
			if ($nn == 0x20) {
				#exceptions to :xx rule:
				$cc = pack("C", $nn);
			} else {
				#kshare servers:  %A5 --> :A5
				$cc = sprintf(":%02X", $nn);
			}
		} else {
			#convert to raw char:
			if ($ebcdic) {
				#print "Before nn=$nn ";
				$nn = $ascii2ebcdic[$nn];
				#print "After nn=$nn\n";
			}
			$cc = pack("C", $nn);
			#print "cc = '$cc'\n";
		}

		$obuf .= $cc;
	}

	return($obuf);
}

sub name_encode
#encode a name with hex specifications.
#E.g., 'foo bar'  --> 'foo%20bar'
#      '%xyz'       --> '%%xyz'
{
	local($buf) = @_;

	local($obuf) = "";
	local($nn);
	local(@crec) = split(//, $buf);

	$cnt = 0;
	foreach $nn (unpack("C*", $buf)) {
		$cc = $crec[$cnt++];
#printf("%s='%d'\n", $cc, $nn);
		if ( $SERVER_TYPE = $KSHARE_SERVER && $cc eq ":") {
			$obuf .= "%";
		} elsif ($cc eq "%") {
			$obuf .= "%%";
		} else {
			# warning ASCIIism ahead
			if ($nn < 32 || $nn > 127 || ($cc =~ /[ \t\"\'\$\\]/)) {
				$obuf .= sprintf("%%%02x", $nn);
			} else {
				$obuf .= $cc;
			}
		}
		
	}

	return $obuf;
}

1;
