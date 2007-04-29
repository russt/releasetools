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
# @(#)bomsuprt.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# bomsuprt.pl
# support the parsing of BOM files
#

package bomsuprt;

$DEBUG = 0;

require "os.pl";
require "path.pl";
require "codeline.pl";

sub Init
{
	local($FORTE_PORT, $ue) = @_;
	local($var, $value);

	$useExternal = $ue;
	%VARDEF = ();
	if ($useExternal) {
		if (!defined($ENV{"RELEASE_ROOT"})) {
			print STDERR "warning: RELEASE_ROOT is not defined.\n";
		}
		# Copy %ENV into %VARDEF, making the variable names case insensitive.
		foreach $var (keys %ENV) {
			$value = $ENV{$var};
			&SetVar($var, $value);
		}
		&SetVar("RELEASE", $ENV{"RELEASE_ROOT"});
	}
	$prevKitType = "DEV";
	&SetKitType("DEV");

	if ($FORTE_PORT ne "") {
		&SetVar("FORTE_PORT", $FORTE_PORT);
		&SetVar("PORT", $FORTE_PORT);

		&SetVar("DS", &cl'which_display($FORTE_PORT));
	}
}

sub SetVar
{
	local($var, $value) = @_;

	$var =~ tr/a-z/A-Z/;
	# print "SetVar: $var = $value\n";
	$VARDEF{$var} = $value;
}

sub IsVarReallyDefined
	# Ignore the useExternal bit.  See if the thing is really defined,
	# this is used by the ifdef command.
{
	local($var) = @_;

	$var =~ tr/a-z/A-Z/;
	return defined($VARDEF{$var});
}

sub IsVarDefined
	# If useExternal is set, then the var is always defined;
	# otherwise, we check to see if it really was defined or not.
{
	local($var) = @_;

	$var =~ tr/a-z/A-Z/;
	if ($useExternal) {
		return defined($VARDEF{$var});
	} else {
		return 1;
	}
}

sub GetVar
{
	local($var) = @_;

	$var =~ tr/a-z/A-Z/;
	if (defined($VARDEF{$var})) {
		return $VARDEF{$var};
	} else {
		if (! $useExternal) {
			return "<$var>";
		}
	}
}

sub SetKitType
{
	local($kitType) = @_;

	&SetVar($prevKitType, 0);
	&SetVar($kitType, 1);
	$prevKitType = $kitType;
}

sub AreWePort
{
	local($port) = @_;

	local($real_port) = &GetVar('PORT');
	if ($real_port eq $port) {
		return 1;
	}
	# Should also check for psuedo ports
	if ($port eq "UNIX") {
		if (grep($_ eq $real_port, &cl'unix_ports)) {
			return 1;
		}
	} elsif ($port eq "NT") {
		if (grep($_ eq $real_port, &cl'nt_ports)) {
			return 1;
		}
	} elsif ($port eq "MAC") {
		if (grep($_ eq $real_port, &cl'mac_ports)) {
			return 1;
		}
	} elsif ($port eq "VMS") {
		if (grep($_ eq $real_port, &cl'vms_ports)) {
			return 1;
		}
	}
	return 0;
}

sub IsFlagSet
{
	local($flag) = @_;

	$flag =~ tr/a-z/A-Z/;
	# print "IsFlagSet: $flag = $VARDEF{$flag}\n";
	if (&IsVarDefined($flag) && &GetVar($flag) eq "1") {
		return 1;
	}
	return 0;
}

sub PrintObjTree
	# Print out every entry in our parsed tree in an internal format
{
	local($objNum) = @_;

	# We have to do our own tail recursion since perl doesn't support it.
  tail_recursion:
	if ($objNum == $bomparse'invalidObjNum) {
		# print "invalid\n";
	} elsif ($bomparse'objType[$objNum] eq "statement") {
		print "{statement}: ";
		&PrintObjTree($bomparse'objAttrib1[$objNum]);
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "mkdir_dcl") {
		printf("{mkdir} %s %s", $bomparse'objAttrib1[$objNum], $bomparse'objAttrib2[$objNum]);
		&PrintObjTree($bomparse'objAttrib3[$objNum]);
		print "\n";
	} elsif ($bomparse'objType[$objNum] eq "minstall_dcl") {
		printf("{minstall} %s %s %s", $bomparse'objAttrib1[$objNum], $bomparse'objAttrib2[$objNum], $bomparse'objAttrib3[$objNum]);
		print "\n";
	} elsif ($bomparse'objType[$objNum] eq "flag") {
		print " {flag} ";
		print $bomparse'objAttrib1[$objNum];
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "include") {
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "dcl") {
		print "{set} $bomparse'objAttrib1[$objNum] $bomparse'objAttrib2[$objNum]\n";
	} elsif ($bomparse'objType[$objNum] eq "filemapping") {
		printf("{filemapping} %s %s %s %s %s %s %s",
			   $bomparse'objAttrib1[$objNum], $bomparse'objAttrib2[$objNum],
			   $bomparse'objAttrib3[$objNum], $bomparse'objAttrib4[$objNum],
			   $bomparse'objAttrib5[$objNum], $bomparse'objAttrib6[$objNum]);
		&PrintObjTree($bomparse'objAttrib7[$objNum]);
		print "\n";
	} elsif ($bomparse'objType[$objNum] eq "expr") {
		print "{expr}: (";
		&PrintObjTree($bomparse'objAttrib1[$objNum]);   # operand1
		print ") ";
		print $bomparse'objAttrib2[$objNum];   # operator
		print " (";
		&PrintObjTree($bomparse'objAttrib3[$objNum]);   # operand2
		print ") ";
	} elsif ($bomparse'objType[$objNum] eq "value") {
		print "{value}: ";
		print $bomparse'objAttrib1[$objNum];
	} elsif ($bomparse'objType[$objNum] eq "if_cond") {
		print "{if_cond}: ";
		&PrintObjTree($bomparse'objAttrib1[$objNum]);
		print "\n";
		&PrintObjTree($bomparse'objAttrib2[$objNum]);
		print "{if_ELSE}\n";
		&PrintObjTree($bomparse'objAttrib3[$objNum]);
		print "{ENDIF}\n";
	} elsif ($bomparse::objType[$objNum] eq "ifdef_cond") {
		print "{ifdef_cond}: ";
		&PrintObjTree($bomparse::objAttrib1[$objNum]);
		print "\n";
		&PrintObjTree($bomparse::objAttrib2[$objNum]);
		print "{ifdef_ELSE}\n";
		&PrintObjTree($bomparse::objAttrib3[$objNum]);
		print "{ENDIFDEF}\n";
	} elsif ($bomparse::objType[$objNum] eq "ifndef_cond") {
		print "{ifndef_cond}: ";
		&PrintObjTree($bomparse::objAttrib1[$objNum]);
		print "\n";
		&PrintObjTree($bomparse::objAttrib2[$objNum]);
		print "{ifndef_ELSE}\n";
		&PrintObjTree($bomparse::objAttrib3[$objNum]);
		print "{ENDIFNDEF}\n";
	} elsif ($bomparse'objType[$objNum] eq "ifport_cond") {
		print "{ifport_cond}: ";
		&PrintObjTree($bomparse'objAttrib1[$objNum]);
		print "\n";
		&PrintObjTree($bomparse'objAttrib2[$objNum]);
		print "{ifport_ELSE}\n";
		&PrintObjTree($bomparse'objAttrib3[$objNum]);
		print "{ENDIFPORT}\n";
	} elsif ($bomparse'objType[$objNum] eq "ifnport_cond") {
		print "{ifnport_cond}: ";
		&PrintObjTree($bomparse'objAttrib1[$objNum]);
		print "\n";
		&PrintObjTree($bomparse'objAttrib2[$objNum]);
		print "{ifnport_ELSE}\n";
		&PrintObjTree($bomparse'objAttrib3[$objNum]);
		print "{ENDIFNPORT}\n";
	} elsif ($bomparse'objType[$objNum] eq "port_name") {
		print " {port} ";
		print $bomparse'objAttrib1[$objNum];
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "raise") {
		print "{raise} ";
		print $bomparse'objAttrib1[$objNum];
		print "\n";
	} elsif ($bomparse'objType[$objNum] eq "debug") {
		print "{debug} ";
		print $bomparse'objAttrib1[$objNum];
		print " ";
		print $bomparse'objAttrib2[$objNum];
		print "\n";
	} elsif ($bomparse::objType[$objNum] eq "pruned") {
	} else {
		print "BUILD_ERROR: unrecognized object $objNum: $bomparse::objType[$objNum]\n";
	}
}

sub ExpandVarObjTree
	# Find all variable settings in the parsed tree and then expand
	# all references to variables given those settings.
{
	local($objNum, $fullExpand) = @_;

	# We have to do our own tail recursion since perl doesn't support it.
  tail_recursion:
	if ($objNum == $bomparse'invalidObjNum) {
		# print "invalid\n";
	} elsif ($bomparse'objType[$objNum] eq "statement") {
		&ExpandVarObjTree($bomparse'objAttrib1[$objNum], $fullExpand);
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "mkdir_dcl") {
		if ($fullExpand) {
			&ExpandVarAttrib1($objNum);
		}
		&ExpandVarAttrib2($objNum);
		$objNum = $bomparse'objAttrib3[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "minstall_dcl") {
		&ExpandVarAttrib1($objNum);
		&ExpandVarAttrib2($objNum);
	} elsif ($bomparse'objType[$objNum] eq "flag") {
		&ExpandVarAttrib1($objNum);
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "include") {
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "dcl") {
		if ($fullExpand) {
			&ExpandVarAttrib2($objNum);
		}
		&SetVar($bomparse'objAttrib1[$objNum], $bomparse'objAttrib2[$objNum]);
	} elsif ($bomparse'objType[$objNum] eq "filemapping") {
		&SetVar("FILE", $bomparse'objAttrib1[$objNum]);
		&ExpandVarAttrib1($objNum);   # source file
		if ($fullExpand) {
			&ExpandVarAttrib2($objNum);   # permissions
			&ExpandVarAttrib3($objNum);   # type
		}
		&ExpandVarAttrib4($objNum);   # source dir
		&ExpandVarAttrib5($objNum);   # destination file
		&ExpandVarAttrib6($objNum);   # destination dir
		$objNum = $bomparse'objAttrib7[$objNum];   # flags
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "expr") {
		&ExpandVarObjTree($bomparse'objAttrib1[$objNum]);   # operand1
		# Skip operators, since they arn't allowed to have variables
		$objNum = $bomparse'objAttrib3[$objNum];   # operand2
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "value") {
		if ($fullExpand) {
			&ExpandVarAttrib1($objNum);
		}
	} elsif ($bomparse'objType[$objNum] eq "if_cond") {
		&ExpandVarObjTree($bomparse'objAttrib1[$objNum], $fullExpand);
		&ExpandVarObjTree($bomparse'objAttrib2[$objNum], $fullExpand);
		$objNum = $bomparse'objAttrib3[$objNum];
		goto tail_recursion;
	} elsif ($bomparse::objType[$objNum] eq "ifdef_cond") {
		&ExpandVarObjTree($bomparse::objAttrib1[$objNum], $fullExpand);
		&ExpandVarObjTree($bomparse::objAttrib2[$objNum], $fullExpand);
		$objNum = $bomparse::objAttrib3[$objNum];
		goto tail_recursion;
	} elsif ($bomparse::objType[$objNum] eq "ifndef_cond") {
		&ExpandVarObjTree($bomparse::objAttrib1[$objNum], $fullExpand);
		&ExpandVarObjTree($bomparse::objAttrib2[$objNum], $fullExpand);
		$objNum = $bomparse::objAttrib3[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "ifport_cond") {
		&ExpandVarObjTree($bomparse'objAttrib1[$objNum], $fullExpand);
		&ExpandVarObjTree($bomparse'objAttrib2[$objNum], $fullExpand);
		$objNum = $bomparse'objAttrib3[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "ifnport_cond") {
		&ExpandVarObjTree($bomparse'objAttrib1[$objNum], $fullExpand);
		&ExpandVarObjTree($bomparse'objAttrib2[$objNum], $fullExpand);
		$objNum = $bomparse'objAttrib3[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "port_name") {
		&ExpandVarAttrib1($objNum);
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "debug") {
		if ($bomparse'objAttrib1[$objNum] eq "expand") {
			eval $bomparse'objAttrib2[$objNum];
		}
	} elsif ($bomparse'objType[$objNum] eq "raise") {
	} elsif ($bomparse'objType[$objNum] eq "pruned") {
	} else {
		print "BUILD_ERROR: unrecognized object $objNum: $bomparse'objType[$objNum]\n";
	}
}

sub ExpandVar
{
	local($str) = @_;
	if ($str !~ /</) {
		return $str;
	}
	local($varName, $value, $s, $theRest);
	local($outBuf) = "";
	
	while ($str ne "") {
		($s, $varName, $theRest) = ($str =~ /^([^\<]*)\<([^\<]+)\>(.*)/);
		if (!defined($varName)) {
			$outBuf .= $str;
			last;
		}
		if (!defined($s)) {
			# regexp in perl on MVS is slightly broken, so we need to do this
			$s = "";
		}
		# print "s = '$s' o = '$o' str = '$str'\n" if ($DEBUG);
		$outBuf .= $s;
		if (!defined($theRest)) {
			# print "theRest is not defined\n";
			$theRest = "";
		}
		# print "varName = '$varName' theRest = '$theRest'\n" if ($DEBUG);
		$str = $theRest;
		if (&IsVarDefined($varName)) {
			$outBuf .= &GetVar($varName);
		} else {
			printf STDERR "BUILD_ERROR: the variable '$varName' is not defined\n";
			$outBuf .= "<$varName>";
		}
	}
	return $outBuf;
}

sub ExpandVarAttrib1
{
	local($objNum) = @_;

	$bomparse'objAttrib1[$objNum] = &ExpandVar($bomparse'objAttrib1[$objNum]);
}

sub ExpandVarAttrib2
{
	local($objNum) = @_;

	$bomparse'objAttrib2[$objNum] = &ExpandVar($bomparse'objAttrib2[$objNum]);
}

sub ExpandVarAttrib3
{
	local($objNum) = @_;

	$bomparse'objAttrib3[$objNum] = &ExpandVar($bomparse'objAttrib3[$objNum]);
}

sub ExpandVarAttrib4
{
	local($objNum) = @_;

	$bomparse'objAttrib4[$objNum] = &ExpandVar($bomparse'objAttrib4[$objNum]);
}

sub ExpandVarAttrib5
{
	local($objNum) = @_;

	$bomparse'objAttrib5[$objNum] = &ExpandVar($bomparse'objAttrib5[$objNum]);
}

sub ExpandVarAttrib6
{
	local($objNum) = @_;

	$bomparse'objAttrib6[$objNum] = &ExpandVar($bomparse'objAttrib6[$objNum]);
}

sub ExpandVarAttrib7
{
	local($objNum) = @_;

	$bomparse'objAttrib7[$objNum] = &ExpandVar($bomparse::objAttrib7[$objNum]);
}

sub ExecuteObjTree
	# Go thru the parsed tree and prune out those entried that have
	# conditionals around them which are false.  This is essentially
	# executing the tree, since we need to execute any if expressions
	# to find our if they are true or false.
	#
	# eg: if <predicate> <statements1> else <statements2>
	#    If <predicate> where true, then we'd prune <statements2> out.
	#    If <predicate> where false, then we'd prune <statements1> out.
{
	local($objNum) = @_;

	# We have to do our own tail recursion since perl doesn't support it.
  tail_recursion:
	if ($objNum == $bomparse'invalidObjNum) {
		# print "invalid\n";
	} elsif ($bomparse'objType[$objNum] eq "statement") {
		&ExecuteObjTree($bomparse'objAttrib1[$objNum]);
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "mkdir_dcl") {
		if ($bomparse'objAttrib3[$objNum] != $bomparse'invalidObjNum &&
			! &ExecuteObjTree($bomparse'objAttrib3[$objNum])) {
			$bomparse'objType[$objNum] = "pruned";
			return 0;
		}
		&ExpandVarAttrib1($objNum);
		&ExpandVarAttrib2($objNum);
	} elsif ($bomparse'objType[$objNum] eq "minstall_dcl") {
		&ExpandVarAttrib1($objNum);
		&ExpandVarAttrib2($objNum);
	} elsif ($bomparse'objType[$objNum] eq "flag") {
		&ExpandVarAttrib1($objNum);
		# print "Is flag set $bomparse'objAttrib1[$objNum]?\n";
		if (&IsFlagSet($bomparse'objAttrib1[$objNum])) {
			# print "Yes, we accepted $bomparse'objAttrib1[$objNum]\n";
			return 1;
		}
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "include") {
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "dcl") {
			&ExpandVarAttrib2($objNum);
			&SetVar($bomparse'objAttrib1[$objNum], $bomparse'objAttrib2[$objNum]);
	} elsif ($bomparse'objType[$objNum] eq "filemapping") {
		# check the flags
		if ($bomparse'objAttrib7[$objNum] != $bomparse'invalidObjNum &&
				 ! &ExecuteObjTree($bomparse'objAttrib7[$objNum])) {
			# print "Pruned $objNum: $bomparse'objAttrib1[$objNum]\n";
			$bomparse'objType[$objNum] = "pruned";
			return 0;
		}
		&ExpandVarAttrib1($objNum);   # source file
		&SetVar("FILE", $bomparse'objAttrib1[$objNum]);
		&ExpandVarAttrib2($objNum);   # permissions
		&ExpandVarAttrib3($objNum);   # type
		&ExpandVarAttrib4($objNum);   # source dir
		&ExpandVarAttrib5($objNum);   # destination file
		&ExpandVarAttrib6($objNum);   # destination dir
	} elsif ($bomparse'objType[$objNum] eq "expr") {
		# print "expr $objNum: $bomparse'objAttrib1[$objNum] $bomparse'objAttrib2[$objNum] $bomparse'objAttrib3[$objNum]\n";
		local($operand1) = &ExecuteObjTree($bomparse'objAttrib1[$objNum]);
		local($oper) = $bomparse'objAttrib2[$objNum];
		local($operand2) = &ExecuteObjTree($bomparse'objAttrib3[$objNum]);
		# Compute the actual result
		local($Result) = &EvalExpr($operand1, $oper, $operand2, $objNum);
		# print "expr $objNum: Result = $Result\n";
		return $Result;
	} elsif ($bomparse'objType[$objNum] eq "value") {
		&ExpandVarAttrib1($objNum);
		return $bomparse'objAttrib1[$objNum];
	} elsif ($bomparse::objType[$objNum] eq "if_cond") {
		if (&ExecuteObjTree($bomparse'objAttrib1[$objNum])) {
			$bomparse'objAttrib3[$objNum] = $bomparse'invalidObjNum;
			$objNum = $bomparse'objAttrib2[$objNum];
			goto tail_recursion;
		} else {
			$bomparse'objAttrib2[$objNum] = $bomparse'invalidObjNum;
			$objNum = $bomparse::objAttrib3[$objNum];
			goto tail_recursion;
		}
	} elsif ($bomparse::objType[$objNum] eq "ifdef_cond") {
		local($var);
		$var = &ExecuteObjTree($bomparse::objAttrib1[$objNum]);
		if (&IsVarReallyDefined($var)) {
			$bomparse::objAttrib3[$objNum] = $bomparse::invalidObjNum;
			$objNum = $bomparse::objAttrib2[$objNum];
			goto tail_recursion;
		} else {
			$bomparse::objAttrib2[$objNum] = $bomparse::invalidObjNum;
			$objNum = $bomparse::objAttrib3[$objNum];
			goto tail_recursion;
		}
	} elsif ($bomparse::objType[$objNum] eq "ifndef_cond") {
		local($var);
		$var = &ExecuteObjTree($bomparse::objAttrib1[$objNum]);
		if (! &IsVarReallyDefined($var)) {
			$bomparse::objAttrib3[$objNum] = $bomparse::invalidObjNum;
			$objNum = $bomparse::objAttrib2[$objNum];
			goto tail_recursion;
		} else {
			$bomparse::objAttrib2[$objNum] = $bomparse::invalidObjNum;
			$objNum = $bomparse::objAttrib3[$objNum];
			goto tail_recursion;
		}
	} elsif ($bomparse'objType[$objNum] eq "ifport_cond") {
		if (&ExecuteObjTree($bomparse'objAttrib1[$objNum])) {
			$bomparse'objAttrib3[$objNum] = $bomparse'invalidObjNum;
			$objNum = $bomparse'objAttrib2[$objNum];
			goto tail_recursion;
		} else {
			$bomparse'objAttrib2[$objNum] = $bomparse'invalidObjNum;
			$objNum = $bomparse'objAttrib3[$objNum];
			goto tail_recursion;
		}
	} elsif ($bomparse'objType[$objNum] eq "ifnport_cond") {
		if (! &ExecuteObjTree($bomparse'objAttrib1[$objNum])) {
			$bomparse'objAttrib3[$objNum] = $bomparse'invalidObjNum;
			$objNum = $bomparse'objAttrib2[$objNum];
			goto tail_recursion;
		} else {
			$bomparse'objAttrib2[$objNum] = $bomparse'invalidObjNum;
			$objNum = $bomparse'objAttrib3[$objNum];
			goto tail_recursion;
		}
	} elsif ($bomparse'objType[$objNum] eq "port_name") {
		&ExpandVarAttrib1($objNum);
		# print "Are we " . $bomparse'objAttrib1[$objNum] . "?\n";
		if (&AreWePort($bomparse'objAttrib1[$objNum])) {
			# print "Yes, we are that port\n";
			return 1;
		}
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "raise") {
		print "BUILD_ERROR: raise " .
			&bomparse'ObjLocation($objNum) . ": $bomparse'objAttrib1[$objNum]\n";
	} elsif ($bomparse'objType[$objNum] eq "debug") {
		if ($bomparse'objAttrib1[$objNum] eq "execute") {
			eval $bomparse'objAttrib2[$objNum];
		}
	} elsif ($bomparse'objType[$objNum] eq "pruned") {
	} else {
		print "BUILD_ERROR: unrecognized object $objNum: $bomparse'objType[$objNum]\n";
	}
	return 0;
}

sub EvalExpr
{
	local($operand1, $oper, $operand2, $objNum) = @_;

	print "EvalExpr: $operand1 $oper $operand2 $objNum\n" if ($DEBUG);
	if ($oper eq "=") {
		if ($operand1 eq $operand2) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($oper eq "!=") {
		if ($operand1 ne $operand2) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($oper eq "not" || $oper eq "!") {
		if ($operand1) {
			return 0;
		} else {
			return 1;
		}
	} elsif ($oper eq "or" || $oper eq "||") {
		if ($operand1 || $operand2) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($oper eq "and" || $oper eq "&&") {
		if ($operand1 && $operand2) {
			return 1;
		} else {
			return 0;
		}
	} else {
		print STDERR "BUILD_ERROR: Undefined operator '$oper' " .
			&bomparse'ObjLocation($objNum) . "\n";
	}
	return 0;
}

sub BuildDirObjTree
	# Take 2 associative arrays and put into the first every directory
	# while into the second goes the object number
	# associated with that directory as well as all of the files.
	# The contents of the first is
	# the list of directories and files which are in that directory.
	# Note that the first's "/" entry is used as the top.
	#
	# eg: userapp/cl0/ole/foo.c, userapp/test.h
	#     $dirContents{"/"} = "userapp"
	#       $dirObjNum{"/"} = 2;
	#     $dirContents{"userapp"} = "cl0" . $; . "test.h"
	#       $dirObjNum{"userapp"} = 3;
	#     $dirContents{"userapp/cl0"} = "ole"
	#       $dirObjNum{"userapp/cl0"} = 4;
	#     $dirContents{"userapp/cl0/ole"} = "foo.c"
	#       $dirObjNum{"userapp/cl0/ole"} = 5
	#       $dirObjNum{"userapp/cl0/ole/foo.c"} = 6
	#       $dirObjNum{"userapp/test.h"} = 7
{
	local($objNum, *dirContents, *dirObjNum) = @_;

	# We have to do our own tail recursion since perl doesn't support it.
  tail_recursion:
	if ($objNum == $bomparse'invalidObjNum) {
		# print "invalid\n";
	} elsif ($bomparse'objType[$objNum] eq "statement") {
		&BuildDirObjTree($bomparse'objAttrib1[$objNum], *dirContents, *dirObjNum);
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "mkdir_dcl") {
		# print "mkdir: with objNum=$objNum\n";
		local($destDir) = $bomparse'objAttrib2[$objNum];
		$destDir =~ s#(/\.)+$##;
		&BuildDirMkdir($destDir, $objNum,
					   *dirContents, *dirObjNum);
	} elsif ($bomparse'objType[$objNum] eq "minstall_dcl") {
		local($destDir) = $bomparse'objAttrib2[$objNum];
		$destDir =~ s#(/\.)+$##;
		&BuildDirMkdir($destDir, $objNum, *dirContents, *dirObjNum);
		$dirObjNum{$destDir} = $objNum;
	} elsif ($bomparse'objType[$objNum] eq "flag") {
		# not relevant to a file tree
	} elsif ($bomparse'objType[$objNum] eq "include") {
		$objNum = $bomparse'objAttrib2[$objNum];
		goto tail_recursion;
	} elsif ($bomparse'objType[$objNum] eq "dcl") {
		# not relevant to a file tree
	} elsif ($bomparse'objType[$objNum] eq "filemapping") {
		local($destDir) = $bomparse'objAttrib6[$objNum];
		local($destFile) = $bomparse'objAttrib5[$objNum];
		local($fullDestFile);
		$destDir =~ s#(/\.)+$##;
		if ($destDir eq "." || $destDir eq "") {
			$fullDestFile = $destFile;
			$destDir = "/";
		} else {
			$fullDestFile = $destDir . "/" . $destFile;
		}
		if (defined($dirObjNum{$fullDestFile})) {
			print STDERR "Duplicate file: $fullDestFile\n";
			print STDERR "   Original instance "
				. &bomparse'ObjLocation($dirObjNum{$fullDestFile}) . "\n";
			print STDERR "   Duplicate instance "
				. &bomparse'ObjLocation($objNum) . "\n";
			return 0;
		}
		# Make sure the directory is created in our table.
		&BuildDirMkdir($destDir, $objNum, *dirContents, *dirObjNum);
		if (!defined($dirContents{$destDir})) {
			print "dirContents{$destDir} not defined\n";
		}
		# Add this particular file to that dir's listing.
		$dirContents{$destDir} .= $; . $destFile;
		# And create an entry for this particular file.
		$dirObjNum{$fullDestFile} = $objNum;
	} elsif ($bomparse'objType[$objNum] eq "expr") {
		# not relevant to a file tree
	} elsif ($bomparse'objType[$objNum] eq "value") {
		# not relevant to a file tree
	} elsif ($bomparse::objType[$objNum] eq "if_cond") {
		&BuildDirObjTree($bomparse'objAttrib2[$objNum], *dirContents, *dirObjNum);
		&BuildDirObjTree($bomparse::objAttrib3[$objNum], *dirContents, *dirObjNum);
	} elsif ($bomparse::objType[$objNum] eq "ifdef_cond") {
		&BuildDirObjTree($bomparse::objAttrib2[$objNum], *dirContents, *dirObjNum);
		&BuildDirObjTree($bomparse::objAttrib3[$objNum], *dirContents, *dirObjNum);
	} elsif ($bomparse::objType[$objNum] eq "ifndef_cond") {
		&BuildDirObjTree($bomparse::objAttrib2[$objNum], *dirContents, *dirObjNum);
		&BuildDirObjTree($bomparse::objAttrib3[$objNum], *dirContents, *dirObjNum);
	} elsif ($bomparse'objType[$objNum] eq "ifport_cond") {
		&BuildDirObjTree($bomparse'objAttrib2[$objNum], *dirContents, *dirObjNum);
		&BuildDirObjTree($bomparse'objAttrib3[$objNum], *dirContents, *dirObjNum);
	} elsif ($bomparse'objType[$objNum] eq "ifnport_cond") {
		&BuildDirObjTree($bomparse'objAttrib2[$objNum], *dirContents, *dirObjNum);
		&BuildDirObjTree($bomparse'objAttrib3[$objNum], *dirContents, *dirObjNum);
	} elsif ($bomparse'objType[$objNum] eq "port_name") {
		# not relevant to a file tree
	} elsif ($bomparse'objType[$objNum] eq "raise") {
	} elsif ($bomparse'objType[$objNum] eq "debug") {
		if ($bomparse'objAttrib1[$objNum] eq "builddir") {
			eval $bomparse'objAttrib2[$objNum];
		}
	} elsif ($bomparse'objType[$objNum] eq "pruned") {
	} else {
		print "BUILD_ERROR: unrecognized object in BuildDirObjTree, $objNum: $bomparse'objType[$objNum]\n";
	}
	return 0;
}

sub BuildDirMkdir
	# Helper function to BuildDirObjTree, marks the directories in the
	# associative arrays.
{
	local($dir, $objNum, *dirContents, *dirObjNum) = @_;

	print "BuildDirMkdir: $dir\n" if ($DEBUG);
	local(@pathList, $curFullDir, $prevDir, $curDir);
	@pathList = split("/", $dir);
	push(@pathList, "");
	$fullDir = "";
	$prevDir = "";
	foreach $curDir (@pathList) {
		if ($prevDir eq "") {
			$fullDir = "/";
		} elsif ($fullDir eq "/") {
			$fullDir = $prevDir;
		} else {
			$fullDir .= "/" . $prevDir;
		}
		if ($fullDir eq ".") {
			$fullDir = "/";
		}
		
		if (!defined($dirObjNum{$fullDir})) {
			$dirContents{$fullDir} = $curDir;
			$dirObjNum{$fullDir} = $objNum;
			# print "Setting dirObjNum{$fullDir} = $dirObjNum{$fullDir}\n";
		} else {
			if (!defined($dirContents{$fullDir})) {
				print STDERR "Overlapping file and directory in '$fullDir'\n";
				print STDERR "   Original instance "
					. &bomparse'ObjLocation($dirObjNum{$fullDir}) . "\n";
				print STDERR "   Duplicate instance "
					. &bomparse'ObjLocation($objNum) . "\n";
				# "promote" it to a directory so that there won't be
				# further errors.
				$dirContents{$fullDir} = $curDir;
				$dirObjNum{$fullDir} = $objNum;
			} else {
				# Don't need to append if it already exists in there.
				if (! grep($_ eq $curDir, split($;, $dirContents{$fullDir}))) {
					$dirContents{$fullDir} .= $; . $curDir;
				}
			}
		}
		print "BuildDirMkdir: fullDir = '$fullDir' prevDir='$prevDir' curDir='$curDir' dirContents{$fullDir} = $dirContents{$fullDir}\n" if ($DEBUG);

		$prevDir = $curDir;
	}
}

1;
