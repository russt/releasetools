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
# @(#)vars.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# vars.pl
# for doing variable manipulation in strings

package vars;

$DEBUG = 0;

sub expand_vars
	# Given a string and an associative array, replace any variables
	# denoted by a '$' with what's in the associative array.  If the
	# variable is not in the array, then it gets replaced by "".
{
	local($cmd, *arr, *errcnt) = @_;
	local($s, $o, $varName, $theRest);
	local($outCmd) = "";
	
	$errcnt = 0;

	while ($cmd ne "") {
		($s, $o) = ($cmd =~ /^([^\$]*)\$(.*)/);
		if (!defined($o)) {
			$outCmd .= $cmd;
			last;
		}
		if (!defined($s)) {
			# regexp in perl on MVS is slightly broken, so we need to do this
			$s = "";
		}
		print "s = '$s' o = '$o' cmd = '$cmd'\n" if ($DEBUG);
		$outCmd .= $s;
		if (substr($o, 0, 1) eq "{") {
			($varName, $theRest) = ($o =~ /^\{([^\{]+)\}(.*)/);
		} else {
			($varName, $theRest) = ($o =~ /^([a-zA-Z_]+)(.*)/);
		}
		if (!defined($theRest)) {
			# print "theRest is not defined\n";
			$theRest = "";
		}
		if (!defined($varName)) {
			$outCmd .= '$';
			$cmd = $o;
		} else {
			print "varName = '$varName' theRest = '$theRest'\n" if ($DEBUG);
			$cmd = $theRest;
			local($value);
			$value = $arr{$varName};
			if (defined($value)) {
				$outCmd .= $value;
			} else {
                ++$errcnt;
            }
		}
	}
	print "outCmd = '$outCmd'\n" if ($DEBUG);
	return $outCmd;
}

sub expand_args
	# Given a string and a set of potential arguments to that string,
	# fill in the arguments.
	# eg: $cmd = "tar rvf $2 $1"  @params=("foo.cc", "foo.tar")
	#     result = "tar rvf foo.tar foo.cc"
{
	local($cmd, @params) = @_;
	local($s, $o, $argNum, $theRest);
	local($outCmd) = "";

	# print "cmd='$cmd'\n";
	while ($cmd ne "") {
		($s, $o) = ($cmd =~ /^([^\$]*)\$(.*)/);
		if (!defined($s)) {
			$outCmd .= $cmd;
			last;
		}
		$outCmd .= $s;
		($argNum, $theRest) = ($o =~ /^([0-9]+)(.*)/);
		if (!defined($argNum)) {
			# print "Numeric argument not present from expand_cmd.\n";
			$outCmd .= '$';
			$cmd = $o;
			# print "cmd='$cmd' outCmd='$outCmd'\n";
		} else {
			$cmd = $theRest;
			--$argNum;  # compensate for 0 based indexing
			$outCmd .= $params[$argNum];
			# print "s='$s' o='$o' argNum='$argNum' cmd='$cmd' outCmd='$outCmd'\n";
		}
	}
	return $outCmd;
}

1;
