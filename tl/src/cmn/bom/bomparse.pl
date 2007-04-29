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
# @(#)bomparse.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# bomparse.pl
# parse BOM files
#
# The Grammar:
#   G           -> statements
#
#   statements  -> statement
#               -> statement statements
#
#   statement   -> (dcl | filemapping | mkdir_dcl | minstall_dcl | conditional | comment | include | debugstmt | raisestmt)
#
#   comment     -> '#' .* '\n'
#
#   include     -> 'include' file
#
#   conditional -> (if_cond | ifport_cond | ifnport_cond | ifdef_cond | ifndef_cond)
#
#   if_cond     -> 'IF' expr '\n' (statement)* 'ENDIF'
#               -> 'IF' expr '\n' (statement)* 'ELSE' (statement)* 'ENDIF'
#
#   expr        -> bool_binary_expr
#
#   bool_binary_expr
#               -> negate_expr ('and' | 'or' | '&&' | '||') bool_binary_expr
#               -> negate_expr
#
#   negate_expr -> ('not' | '!') negate_expr
#               -> comp_expr
#
#   comp_expr   -> value_expr ('=' | '<' | '>' | '!=' | '<=' | '>=') comp_expr
#               -> value_expr
#
#   value_expr  -> '(' expr ')'
#               -> \s+
#
#   ifport_cond -> 'IFPORT' port_list '\n' (statement)* 'ENDIFPORT'
#               -> 'IFPORT' port_list '\n' (statement)* 'ELSE' (statement)* 'ENDIFPORT'
#
#   ifnport_cond -> 'IFNPORT' port_list '\n' (statement)* 'ENDIFNPORT'
#                -> 'IFNPORT' port_list '\n' (statement)* 'ELSE' (statement)* 'ENDIFNPORT'
#
#   port_list   -> port_name
#               -> port_name port_list
#
#   port_name   -> [A-Za-z0-9_]+
#
#   ifdef_cond  -> 'IFDEF' flag (statement)* 'ENDIFDEF'
#               -> 'IFDEF' flag (statement)* 'ELSE' (statement)* 'ENDIFDEF'
#
#   ifndef_cond -> 'IFNDEF' flag (statement)* 'ENDIFNDEF'
#               -> 'IFNDEF' flag (statement)* 'ELSE' (statement)* 'ENDIFNDEF'
#
#   flag        -> [A-Za-z0-9_]+
#
#   debugstmt   -> 'debug' debugcomponent debugexpr
#
#   raisestmt   -> 'raise' .*
#
#   dcl         -> 'set' var_name var_expr
#
#   var_name    -> [A-Za-z0-9_]+
#
#   var_expr    -> [^\s]+
#               -> "[^"]*"
#
#   mkdir_dcl   -> 'mkdir' perm dirname (flags)?
#
#   perm        -> [0-7]+
#
#   dirname     -> [^\s]+
#
#   flags       -> flag
#               -> flag ',' flags
#
# 	minstall_dcl -> 'minstall' file dirname (flags)?
#
#   filemapping -> file '|' perm '|' type '|' src_dir '|' dst_file '|' dst_dir ('|' flags)
#
#   file        -> \s+
#
#   src_dir     -> dirname
#
#   dst_file    -> file
#
#   dst_dir     -> dirname

package bomparse;

$DEBUG = 0;
$ParseErrorCount = 0;

&'require_os;
require "path.pl";
require "scan.pl";

sub ReadBOM
{
	local($filename, $doInclude) = @_;
	local($bomFileObj) = $invalidObjNum;
	local($includeObjNum, $prevLine, $prevChar);
	local($topObj) = $invalidObjNum;

	$ParseErrorCount = 0;
	@includeList = ($filename);
	@includeObjList = ($invalidObjNum);

	while ($theFile = shift @includeList) {
		$includeObjNum = shift @includeObjList;

		$curCharNum = $curLineNum = 0;
		if (! -r $theFile) {
			&ParseError("'$theFile' is not readable\n", 0);
			next;
		}
		if (&scan'Open($theFile)) {
			&ParseError("Failed to open '$theFile': $!\n", 0);
			next;
		}

		print "\n --------- Parsing $theFile ---------\n" if ($DEBUG);

		while (1) {
			$prevLine = &scan'CurLineNum;
			$prevChar = &scan'CurCharNum;
			$TOKVAL = &scan'TokenWS;              #get first token
			$bomFileObj = &statements;
			if ($includeObjNum == $invalidObjNum) {
				$topObj = $bomFileObj;
			} else {
				$objAttrib2[$includeObjNum] = $bomFileObj;
			}
			if (! $scan'EOF) {
				&ParseError("Unexpected token: '$TOKVAL' (could be just a cascading error).", 1);
				# Find the last statement of the list so that we may
				# string on more statements, since we possibly didn't
				# find the last one.
				$iObjNum = &lastStatement($bomFileObj);
				if ($iObjNum != $invalidObjNum) {
					$includeObjNum = $iObjNum;
				}
				print "includeObjNum = $includeObjNum\n" if ($DEBUG);
			} else {
				last;
			}
			if ($prevChar == &scan'CurCharNum && $prevLine == &scan'CurLineNum) {
				&ParseError("Parse not advancing, aborting.  On token '$TOKVAL'", 1);
				last;
			}
		}
		if (! $doInclude) {
			# break out of the include loop if we're not suppose to
			# include any more
			last;
		}
	}
	
	return $topObj;
}

sub statements
{
	local($objNum, $prevObjNum);
	local($statementsObjNum) = &NewObject;
	$prevObjNum = $statementsObjNum;
	while (! $scan'EOF) {
		$objNum = &statement;
		print "statements: objNum=$objNum\n" if ($DEBUG);
		if ($objNum == $invalidObjNum) {
			last;
		}
		$objAttrib2[$prevObjNum] = $objNum;
		$prevObjNum = $objNum;
	}
	$objAttrib2[$prevObjNum] = $invalidObjNum;
	return $objAttrib2[$statementsObjNum];
}

sub statement
{
 	while ($TOKVAL eq "\n") {
 		$TOKVAL = &scan'TokenWS;
 	}
	if ($scan'EOF) {
		return $invalidObjNum;
	}
	local($objNum, $statementObjNum);
	$statementObjNum = &NewObject;
	$objType[$statementObjNum] = "statement";

	print "TOKVAL = '$TOKVAL'\n" if ($DEBUG);
	$objNum = &dcl;
	if ($objNum == $invalidObjNum) {
		
		$objNum = &mkdir_dcl;
		if ($objNum == $invalidObjNum) {
		
		    $objNum = &minstall_dcl;
			if ($objNum == $invalidObjNum) {

				$objNum = &conditional;
				if ($objNum == $invalidObjNum) {
				
					$objNum = &include;
					if ($objNum == $invalidObjNum) {

						$objNum = &raisestmt;
						if ($objNum == $invalidObjNum) {
						
							$objNum = &debugstmt;
							if ($objNum == $invalidObjNum) {
							
								$objNum = &filemapping;
							}
						}
					}
				}
			}
		}
	}
	if ($objNum != $invalidObjNum) {
		$objAttrib1[$statementObjNum] = $objNum;
		return $statementObjNum;
	}
	return $invalidObjNum;
}

sub IsCommand
{
	local($cmdName) = @_;
	local($t) = $TOKVAL;
	$t =~ tr/A-Z/a-z/;
	if ($cmdName eq $t && &scan'LookAheadWS eq " ") {
		return 1;
	}
	return 0;
}

sub dcl
	# a declaration
	#   set var value
{
	if (!&IsCommand("set")) {
		return $invalidObjNum;
	}
	print "Hit dcl\n" if ($DEBUG);
	local($dclObjNum) = &NewObject;
	$objType[$dclObjNum] = "dcl";
	$objAttrib1[$dclObjNum] = &scan'Token;
	local($value);
	$value = &scan'RestOfLine;
	# trim off WS at the end
	$value =~ s/\s+$//;
	# remove the double quotes if there are any
	if ($value =~ /^"(.*)"$/) {
		$value = $1;
	}
	$objAttrib2[$dclObjNum] = $value;
	print "dcl: $objAttrib1[$dclObjNum] = '$value'\n" if ($DEBUG);
	$TOKVAL = &scan'TokenWS;
	return $dclObjNum;
}

sub raisestmt
{
	if (! &IsCommand("raise")) {
		return $invalidObjNum;
	}
	local($raiseObjNum) = &NewObject;
	$objType[$raiseObjNum] = "raise";
	$objAttrib1[$raiseObjNum] = &scan'RestOfLine;

	$TOKVAL = &scan'TokenWS;
	return $raiseObjNum;
}

sub debugstmt
{
	local($endChar) = "";
	
	if (! &IsCommand("debug")) {
		return $invalidObjNum;
	}
	print "Hit debug\n" if ($DEBUG);
	local($dclObjNum) = &NewObject;
	$objType[$dclObjNum] = "debug";
	$objAttrib1[$dclObjNum] = &scan'Token;
	$objAttrib2[$dclObjNum] = &scan'RestOfLine;
	print "debug: $objAttrib1[$dclObjNum]: $objAttrib2[$dclObjNum]\n" if ($DEBUG);
	$TOKVAL = &scan'TokenWS;
	return $dclObjNum;
}

sub filemapping
{
	local($isError) = 0;
	local($src_file, $perm, $type, $src_dir, $dst_file, $dst_dir);
	# Supply some defaults
	$perm = "0775"; $type = "binary"; $src_dir = "<SRC_DIR>";
	$dst_file = "<FILE>"; $dst_dir = "<DST_DIR>";
	local($endchar) = "";

	print "testing for a filemapping TOKVAL='$TOKVAL'\n" if ($DEBUG);
	$src_file = $TOKVAL . &scan'GetUpTo("|", *endChar);
	print "filemapping src_file = '$src_file' endChar=$endChar\n" if ($DEBUG);
	# If the first field isn't followed by a "|", then this must not
	# be a filemapping.
	if ($endChar ne "|") {
		return $invalidObjNum;
	}
	# Since this is a filemapping, any errors from here on are
	# reported and the default is supplied.
	local($filemappingObjNum) = &NewObject;
	$perm = &scan'GetUpTo("|", *endChar);
	if ($endChar eq "|") {
		$type = &scan'GetUpTo("|", *endChar);
		if ($endChar eq "|") {
			$src_dir = &scan'GetUpTo("|", *endChar);
			if ($endChar eq "|") {
				$dst_file = &scan'GetUpTo("|", *endChar);
				if ($endChar eq "|") {
					$dst_dir = &scan'GetUpTo("|", *endChar);
				} else {
					$isError = 1;
				}
			} else {
				$isError = 1;
			}
		} else {
			$isError = 1;
		}
	} else {
		$isError = 1;
	}
	if ($isError) {
		&ParseError("Missing fields in file mapping", 1);
	}
	
	$TOKVAL = &scan'Token;
	print "src_file=$src_file perm=$perm type=$type src_dir=$src_dir dst_file=$dst_file dst_dir=$dst_dir\n" if ($DEBUG);
	local($flagsObjNum) = $invalidObjNum;
	if ($endChar eq "|") {
		$flagsObjNum = &flags;
	}
	$objType[$filemappingObjNum] = "filemapping";
	$objAttrib1[$filemappingObjNum] = $src_file;
	$objAttrib2[$filemappingObjNum] = $perm;
	$objAttrib3[$filemappingObjNum] = $type;
	$objAttrib4[$filemappingObjNum] = $src_dir;
	$objAttrib5[$filemappingObjNum] = $dst_file;
	$objAttrib6[$filemappingObjNum] = $dst_dir;
	$objAttrib7[$filemappingObjNum] = $flagsObjNum;
		
	return $filemappingObjNum;
}

sub mkdir_dcl
{
	local($endChar) = "";
	print "testing for a mkdir_dcl TOKVAL=$TOKVAL\n" if ($DEBUG);
	if (!&IsCommand("mkdir")) {
		return $invalidObjNum;
	}
	print "Hit mkdir_dcl\n" if ($DEBUG);
	local($mkdirObjNum) = &NewObject;
	$objType[$mkdirObjNum] = "mkdir_dcl";
	$TOKVAL = &scan'Token;
	
	local($perm) = $TOKVAL;
	if ($perm !~ /^[0-7]+$/) {
		&ParseError("Permissions need to be octal (perm='$perm').", 1);
		$perm = "0777";
	}
	local($dir) = &scan'GetUpToWS;
	print "mkdir_dcl looking for flags:\n" if ($DEBUG);
	local($flagsObjNum) = $invalidObjNum;
	$TOKVAL = &scan'TokenWS;
	if ($TOKVAL ne "\n") {
		$flagsObjNum = &flags;
	}
	
	print "mkdir_dcl: ($perm, $dir, $flagsObjNum)\n" if ($DEBUG);
	$objAttrib1[$mkdirObjNum] = $perm;
	$objAttrib2[$mkdirObjNum] = $dir;
	$objAttrib3[$mkdirObjNum] = $flagsObjNum;
	return $mkdirObjNum;
}

sub minstall_dcl
{
	local($endChar) = "";
	print "testing for a minstall_dcl TOKVAL=$TOKVAL\n" if ($DEBUG);
	if (!&IsCommand("minstall")) {
		return $invalidObjNum;
	}
	print "Hit minstall_dcl\n" if ($DEBUG);
	local($minstallObjNum) = &NewObject;
	$objType[$minstallObjNum] = "minstall_dcl";
	$TOKVAL = &scan'TokenWS;
	local($srcFile) = &scan'GetUpToWS;
	local($targetDir) = &scan'GetUpToWS;
	local($minstallFlag) = &scan'RestOfLine;
	$minstallFlag =~ s/,/ /g;
	print "minstall_dcl: ($srcFile, $targetDir, $minstallFlag)\n" if ($DEBUG);
	$objAttrib1[$minstallObjNum] = $srcFile;
	$objAttrib2[$minstallObjNum] = $targetDir;
	$objAttrib3[$minstallObjNum] = $minstallFlag;
	$TOKVAL = &scan'TokenWS;
	return $minstallObjNum;
}

sub flags
{
	local($objNum, $prevObjNum);
	local($flagsObjNum) = &NewObject;
	$prevObjNum = $flagsObjNum;
	while (! $scan'EOF) {
		$objNum = &flag;
		print "flags: objNum=$objNum\n" if ($DEBUG);
		last if ($objNum == $invalidObjNum);
		$objAttrib2[$prevObjNum] = $objNum;
		$prevObjNum = $objNum;
		last if ($TOKVAL ne ",");
		$TOKVAL = &scan'TokenWS;  # go past the comma
	}
	$objAttrib2[$prevObjNum] = $invalidObjNum;
	return $objAttrib2[$flagsObjNum];
}

sub flag
{
	print "flag: TOKVAL=$TOKVAL\n" if ($DEBUG);
	local($flagObjNum) = &NewObject;
	$objType[$flagObjNum] = "flag";
	$objAttrib1[$flagObjNum] = $TOKVAL;
	$TOKVAL = &scan'TokenWS;
	return $flagObjNum;
}

sub include
{
	if (!&IsCommand("include")) {
		return $invalidObjNum;
	}
	local($includeFile) = &scan'RestOfLine;
	$TOKVAL = &scan'TokenWS;
	local($includeObjNum) = &NewObject;
	$objType[$includeObjNum] = "include";
	$objAttrib1[$includeObjNum] = $includeFile;
	push(@includeList, $includeFile);
	push(@includeObjList, $includeObjNum);
	return $includeObjNum;
}

sub conditional
{
	local($objNum);
	print "testing for a conditional TOKVAL=$TOKVAL\n" if ($DEBUG);
	$objNum = &if_cond;
	if ($objNum == $invalidObjNum) {
		$objNum = &ifport_cond;
	}
	if ($objNum == $invalidObjNum) {
		$objNum = &ifnport_cond;
	}
	if ($objNum == $invalidObjNum) {
		$objNum = &ifdef_cond;
	}
	if ($objNum == $invalidObjNum) {
		$objNum = &ifndef_cond;
	}
	print "conditional:objNum = $objNum\n" if ($DEBUG);
	return $objNum;
}

sub if_cond
{
	if (! &IsCommand("if")) {
		return $invalidObjNum;
	}
	print "Hit if_cond\n" if ($DEBUG);
	local($condObjNum) = &NewObject;
	$TOKVAL = &scan'TokenWS;
	$objType[$condObjNum] = "if_cond";
	$objAttrib1[$condObjNum] = &expr;
	$objAttrib2[$condObjNum] = &statements;
	$TOKVAL =~ tr/A-Z/a-z/;
	if ($TOKVAL eq "else") {
		$TOKVAL = &scan'TokenWS;
		$objAttrib3[$condObjNum] = &statements;
		$TOKVAL =~ tr/A-Z/a-z/;
	}
	if ($TOKVAL ne "endif") {
		&ParseError("Expected 'endif' got '$TOKVAL' instead.\n   Originating 'if' " . &ObjLocation($condObjNum) . "\n", 1);
	}
	$TOKVAL = &scan'TokenWS;
	return $condObjNum;
}

sub expr
{
	# Call the lowest precendence operator
	return &bool_binary_expr;
}

sub bool_binary_expr
{
	print "Hit bool_binary_expr TOKVAL='$TOKVAL'\n" if ($DEBUG);

	local($objNum, $operand1, $operator, $operand2, $isOper);
	# call the next highest precedence
	$operand1 = &negate_expr;

	$isOper = 0;
	if ($TOKVAL eq "and" || $TOKVAL eq "or") {
		$isOper = 1;
		$operator = $TOKVAL;
	} else {
		if (($TOKVAL eq "&" && &scan'LookAhead eq "&") ||
			($TOKVAL eq "|" && &scan'LookAhead eq "|")) {
			$isOper = 1;
			$operator = $TOKVAL;
			$TOKVAL = &scan'TokenWS;
			$operator .= $TOKVAL;
		}
	}
	if ($isOper) {
		print "New bool_binary_expr\n" if ($DEBUG);
		$objNum = &NewObject;
		$TOKVAL = &scan'TokenWS;
		$operand2 = &bool_binary_expr;
		$objType[$objNum] = "expr";
		$objAttrib1[$objNum] = $operand1;
		$objAttrib2[$objNum] = $operator;
		$objAttrib3[$objNum] = $operand2;
		return $objNum;
	} else {
		# This operator type doesn't apply, so just return what was given to us
		return $operand1;
	}
}

sub negate_expr
{
	print "Hit negate_expr TOKVAL='$TOKVAL'\n" if ($DEBUG);

	local($objNum, $operand1, $operator);

	if ($TOKVAL eq "not" ||	$TOKVAL eq "!") {
		print "New negate_expr\n" if ($DEBUG);
		$objNum = &NewObject;
		$operator = $TOKVAL;
		$TOKVAL = &scan'TokenWS;
		$operand1 = &negate_expr;
		$objType[$objNum] = "expr";
		$objAttrib1[$objNum] = $operand1;
		$objAttrib2[$objNum] = $operator;
		return $objNum;
	} else {
		# This operator type doesn't apply, so just call the next
		# higher precendence operator.
		return &comp_expr;
	}
}

sub comp_expr
{
	print "Hit comp_expr TOKVAL='$TOKVAL'\n" if ($DEBUG);

	local($objNum, $operand1, $operator, $operand2, $valueObjNum,
		  $isOper);

	$operand1 = &value_expr;
	$isOper = 0;
	if ($TOKVAL eq "=" || $TOKVAL eq "<" || $TOKVAL eq ">") {
		$isOper = 1;
		$operator = $TOKVAL;
	} elsif (($TOKVAL eq "!" || $TOKVAL eq "<" || $TOKVAL eq ">")
			 && &scan'LookAhead eq "=") {
		$isOper = 1;
		$operator = $TOKVAL;
		$TOKVAL = &scan'TokenWS;
		$operator .= $TOKVAL;
	}
	if ($isOper) {
		print "New comp_expr\n" if ($DEBUG);
		$objNum = &NewObject;
		$TOKVAL = &scan'TokenWS;
		$operand2 = &comp_expr;
		$objType[$objNum] = "expr";
		$objAttrib1[$objNum] = $operand1;
		$objAttrib2[$objNum] = $operator;
		$objAttrib3[$objNum] = $operand2;
		return $objNum;
	} else {
		# This operator type doesn't apply, so just return what was given to us
		return $operand1;
	}
}

sub value_expr
{
	local($operand1);
	if ($TOKVAL eq ")") {
		&ParseError("Unexpected '$TOKVAL' found.", 1);
		$TOKVAL = &scan'TokenWS;
	}
	if ($TOKVAL eq "(") {
		local($placeHolderObjNum) = &NewObject;
		$TOKVAL = &scan'TokenWS;
		print "value_expr: found a '(' going into expr\n" if ($DEBUG);
		$operand1 = &expr;
		print "value_expr: done with paren recursion\n" if ($DEBUG);
		if ($TOKVAL eq ")") {
			$TOKVAL = &scan'TokenWS;
		} else {
			&ParseError("Missing ')' got '$TOKVAL' instead.\n   Originating '(' " . &ObjLocation($placeHolderObjNum) . "\n", 1);
		}
	} else {
		$valueObjNum = &NewObject;
		$objType[$valueObjNum] = "value";
		$objAttrib1[$valueObjNum] = $TOKVAL . &scan'GetUpToWS;
		$TOKVAL = &scan'TokenWS;
		print "value_expr: objAttrib1[$valueObjNum] = $objAttrib1[$valueObjNum]  TOKVAL=$TOKVAL\n" if ($DEBUG);
		$operand1 = $valueObjNum;
	}
	return $operand1;
}

sub ifport_cond
{
	if (! &IsCommand("ifport")) {
		return $invalidObjNum;
	}
	print "Hit ifport_cond\n" if ($DEBUG);
	local($condObjNum) = &NewObject;
	$TOKVAL = &scan'Token;
	$objType[$condObjNum] = "ifport_cond";
	$objAttrib1[$condObjNum] = &port_list;
	$objAttrib2[$condObjNum] = &statements;
	$TOKVAL =~ tr/A-Z/a-z/;
	if ($TOKVAL eq "else") {
		$TOKVAL = &scan'Token;
		$objAttrib3[$condObjNum] = &statements;
		$TOKVAL =~ tr/A-Z/a-z/;
	}
	if ($TOKVAL ne "endifport" && $TOKVAL ne "endif") {
		&ParseError("Expected 'endifport' got '$TOKVAL' instead.\n   Originating 'ifport' " . &ObjLocation($condObjNum) . "\n", 1);
	}
	$TOKVAL = &scan'TokenWS;
	return $condObjNum;
}

sub ifnport_cond
{
	if (! &IsCommand("ifnport")) {
		return $invalidObjNum;
	}
	print "Hit ifnport_cond\n" if ($DEBUG);
	local($condObjNum) = &NewObject;
	$TOKVAL = &scan'Token;
	$objType[$condObjNum] = "ifnport_cond";
	$objAttrib1[$condObjNum] = &port_list;
	$objAttrib2[$condObjNum] = &statements;
	$TOKVAL =~ tr/A-Z/a-z/;
	if ($TOKVAL eq "else") {
		$TOKVAL = &scan'Token;
		$objAttrib3[$condObjNum] = &statements;
		$TOKVAL =~ tr/A-Z/a-z/;
	}
	if ($TOKVAL ne "endifnport" && $TOKVAL ne "endif") {
		&ParseError("Expected 'endifnport' got '$TOKVAL' instead.   Originating 'ifnport' " . &ObjLocation($condObjNum) . "\n", 1);
	}
	$TOKVAL = &scan'TokenWS;
	return $condObjNum;
}

sub port_list
{
	local($objNum, $prevObjNum);
	local($portsObjNum) = &NewObject;
	$prevObjNum = $portsObjNum;
	while ($TOKVAL ne "\n" && ! $scan'EOF) {
		$objNum = &port_name;
		print "port_list: $objNum\n" if ($DEBUG);
		last if ($objNum == $invalidObjNum);
		$objAttrib2[$prevObjNum] = $objNum;
		$prevObjNum = $objNum;
	}
	$objAttrib2[$prevObjNum] = $invalidObjNum;
	$TOKVAL = &scan'TokenWS;
	return $objAttrib2[$portsObjNum];
}

sub port_name
{
	local($portObjNum) = &NewObject;
	$objType[$portObjNum] = "port_name";
	$objAttrib1[$portObjNum] = $TOKVAL;
	print "port_name: $TOKVAL\n" if ($DEBUG);
	$TOKVAL = &scan'TokenWS;
	return $portObjNum;
}

sub ifdef_cond
{
	if (! &IsCommand("ifdef")) {
		return $invalidObjNum;
	}
	print "Hit ifdef_cond\n" if ($DEBUG);
	local($condObjNum) = &NewObject;
	$TOKVAL = &scan::Token;
	$objType[$condObjNum] = "ifdef_cond";
	$objAttrib1[$condObjNum] = &value_expr;
	$objAttrib2[$condObjNum] = &statements;
	$TOKVAL =~ tr/A-Z/a-z/;
	if ($TOKVAL eq "else") {
		print "Hit ifdef_cond ELSE\n" if ($DEBUG);
		$TOKVAL = &scan::Token;
		$objAttrib3[$condObjNum] = &statements;
		$TOKVAL =~ tr/A-Z/a-z/;
	}
	if ($TOKVAL ne "endifdef" && $TOKVAL ne "endif") {
		&ParseError("Expected 'endifdef' got '$TOKVAL' instead.   Originating 'ifdef' " . &ObjLocation($condObjNum) . "\n", 1);
	}
	$TOKVAL = &scan::TokenWS;
	return $condObjNum;
}

sub ifndef_cond
{
	if (! &IsCommand("ifndef")) {
		return $invalidObjNum;
	}
	print "Hit ifndef_cond\n" if ($DEBUG);
	local($condObjNum) = &NewObject;
	$TOKVAL = &scan::Token;
	$objType[$condObjNum] = "ifndef_cond";
	$objAttrib1[$condObjNum] = &value_expr;
	$objAttrib2[$condObjNum] = &statements;
	$TOKVAL =~ tr/A-Z/a-z/;
	if ($TOKVAL eq "else") {
		print "Hit ifndef_cond ELSE\n" if ($DEBUG);
		$TOKVAL = &scan::Token;
		$objAttrib3[$condObjNum] = &statements;
		$TOKVAL =~ tr/A-Z/a-z/;
	}
	if ($TOKVAL ne "endifndef" && $TOKVAL ne "endif") {
		&ParseError("Expected 'endifndef' got '$TOKVAL' instead.   Originating 'ifndef' " . &ObjLocation($condObjNum) . "\n", 1);
	}
	$TOKVAL = &scan::TokenWS;
	return $condObjNum;
}

sub lastStatement
	# Find the last statement in a statement list
{
	local($objNum) = @_;
	
	if ($objNum == $invalidObjNum || $objAttrib2[$objNum] == $invalidObjNum) {
		return $objNum;
	} else {
		return &lastStatement($objAttrib2[$objNum]);
	}
}

$invalidObjNum = 0;
$nextObjNum = 1;
sub NewObject
{
	local($result) = $nextObjNum;
	++$nextObjNum;
	$objType[$result] = "invalid";
	$objAttrib1[$result] = 0;
	$objAttrib2[$result] = 0;
	$objAttrib3[$result] = 0;
	$objAttrib4[$result] = 0;
	$objAttrib5[$result] = 0;
	$objAttrib6[$result] = 0;
	$objAttrib7[$result] = 0;
	$objFile[$result] = $theFile;
	$objLineNum[$result] = &scan'CurLineNum;
	$objCharNum[$result] = &scan'CurCharNum;
	return $result;
}

sub ObjLocation
{
	local($objNum) = @_;

	if ($DEBUG) {
		return sprintf("in %s around line #%d char #%d (objNum=%d)", $objFile[$objNum],
					   $objLineNum[$objNum], $objCharNum[$objNum], $objNum);
	} else {
		return sprintf("in %s around line #%d char #%d", $objFile[$objNum],
					   $objLineNum[$objNum], $objCharNum[$objNum]);
	}
}

sub ParseError
{
	local($msg, $printWhere) = @_;
	local($header, $footer);
	$footer = "";
	
	$header = "BUILD_ERROR: $'p parse error";
	if ($printWhere) {
		$header .= sprintf(" (file $theFile line %d char %d)", &scan'CurLineNum, &scan'CurCharNum);
		$footer = &scan'CurLine . "\n" . &scan'CurLocStr . "\n";
	}
	if ($DEBUG) {
		print "$header: $msg\n$footer";
	} else {
		print STDERR "$header: $msg\n$footer";
	}
	
	++$ParseErrorCount;
}

1;
