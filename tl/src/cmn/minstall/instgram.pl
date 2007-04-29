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
# @(#)instgram.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
#instgram.pl - parse the install map grammar:
#
# G            -> scope* <EOF>
#
# scope        -> dcl*  mapping+
#
# dcl          -> '<iden>' '=' dcl_elem (',' dcl_elem) * <EOL>
#
# mapping      -> <filename> install_expr '<octal>' command <EOL>
# command      -> '['command_string']'|command_alias|<EOL>
#
# dcl_elem     -> '*'
#              -> "''"		#two single quotes => empty string
#              -> idenlist
#              -> '{' idenlist }'
#              ->				#empty
#
# install_expr -> (var_expr) ('/' var_expr) *
# var_expr     -> ('<iden>' | '$' '<iden>' | '$' '{' '<iden>' '}' ) +
#
# idenlist     -> flist (',' flist) *
# flist        -> '<iden>' ( ('|' | '^' '&' ) fexpr ) *
# fexpr        -> '<iden>' fparamlist ?
# fparamlist   -> '(' '<string>' ( ',' '<string>' )* ')'
#
# 
##lexicon:
# '<iden>'     -> [a-zA-Z_][a-zA-Z0-9_.]*
# '<filename>' -> [a-zA-Z0-9_.!@%,]+
# '<octal>'    -> [0-7]+

#
# prerequisits:
#	lex.pl
#

package ig;

require "scan.pl";

$DEBUG = 0;
$VERBOSE = 0;
	
sub init
#initialize the scanner and screener
{
	($theFile) = @_;

	$scan'DEBUG = 1 if ($DEBUG);
	if (&scan'Open($theFile)) {
		&ParseError("Failed to open '$theFile': $!\n", 0);
        return 1;
    }

	%GATE_TABLE = ();
	%PROCEDURE_TABLE = ();

	# Whether or not a mapping will get installed.  This represents
	# the "truth of the gates" (can I pass or not right now).
	$is_gated_cache = 1;
	# The list of procedures to do on the file ("sh", "skel", ....)
	$procedures = "";
    $ParseErrorCount = 0;

	# &tok'debugON;
	return 0;
}

sub G 
#assume scanner has been initialized
# G            -> scope* <EOF>
{
	local($prevLine, $prevChar);

	$scan'DEBUG = 1 if ($DEBUG);
	print "\n_________ Parsing _________\n" if ($DEBUG);

	$TOKVAL = &scan'Token;              #get first token
	while (! $scan'EOF) {
		$prevLine = &scan'CurLineNum;
	    $prevChar = &scan'CurCharNum;  #'
		&scopes;
		if (! $scan'EOF) {
			&ParseError("Unexpected token: '$TOKVAL' (could be just a cascading error).", 1);
            &scan'RestOfLine;   # Eat up the rest of the line hoping
			                    # that the next line will set us back on
			                    # track.
			$TOKVAL = &scan'Token;
        }
		if ($prevChar == &scan'CurCharNum && $prevLine == &scan'CurLineNum) {
			&ParseError("Parse not advancing, aborting.  On token '$TOKVAL'", 1);
			last;
		}
	}
	
	return $ParseErrorCount;
}

sub scopes
	# scope   -> scope*
{
	while (! $scan'EOF) {
        if (&scope) {
            return 1;
        }
    }
    return 0;
}

sub scope
    # scope        -> dcl*  mapping*
{
	local($prevLine, $prevChar, $res);
	local ($ndcl, $nmap) = (0,0);

	if ($TOKVAL eq " ") {
		# skip over whitespace in the beginning
		$TOKVAL = &scan::Token;
	}
	while (! &dcl() && ! $scan'EOF) {
		++$ndcl;
	}
	#print STDERR "\ndcl=$ndcl\n";

	while (! $scan'EOF) {
 		#$prevLine = &scan'CurLineNum;
 	    #$prevChar = &scan'CurCharNum;
		$res = &mapping();
		if ($res == 1) {
			# it's wasn't a mapping
			last;
		} elsif ($res == 2) {
			# an error
			return 1;
		}
		++$nmap;
 		#if ($prevChar == &scan'CurCharNum && $prevLine == &scan'CurLineNum) {
 		#	&ParseError("Parse not advancing, aborting.  On token '$TOKVAL'", 1);
 		#	return 1;
 		#}
	}
	#print STDERR "nmap=$nmap\n";

	if ($ndcl > 0 && $nmap == 0) {
		&ParseError("Expected at least one mapping ($ndcl,$nmap).", 1);
		return 1;
	}
	if ($ndcl == 0 && $nmap == 0) {
		# It's not a scope
		&ParseError("Expected at least one declaration/mapping ($ndcl,$nmap).", 1);
		return 1;
	}

	return 0;
}

sub dcl
# dcl          -> '<iden>' '=' dcl_elem (',' dcl_elem) * <EOL>
{
	if (!&scan'IsIdentifier($TOKVAL)) {
        return 1;
    }

	if (&scan'LookAhead ne "=") {
		return 1;
	}

	#save iden & scan past '=':
	local($dclname) = $TOKVAL;
	$TOKVAL = &scan'Token;  	#scan '='
	$TOKVAL = &scan'Token;

	local($dclval) = "";
	local(@dclvals);
	if (&dcl_elem(*dclval)) {
		&ParseError("Expected dcl_elem.", 1);
		return 1;
	}

	if ($TOKVAL ne "\n") {
		&ParseError("Expected EOL.", 1);
		return 1;
	}

	# dcl_elem returns a string where the first character is either a
	# 'P' or a 'D' and the rest of the string is a $; separated list
	# of filenames.  The 'P' or 'D' say whether the returned list is for
	# Permiting or Denying these filenames.
	local($dcl_type) = substr($dclval, 0, 1);
	$dclval = substr($dclval, 1);
	
	@dclvals = split($;, $dclval);
	#printf("dclname=%s dcl_type = %s dclvals=(%s)\n", $dclname,
	#			   $dcl_type, join(',', @dclvals)) if ($DEBUG);
    #printf("dclname=%s dcl_type = %s dclvals=(%s)\n", $dclname, $dcl_type, join(',', @dclvals));

	local($the_procs) = "";
	$do_install = &test_var($dclname, $dcl_type, *the_procs, @dclvals);
	if ($do_install =~ /^BUILD_ERROR/) {
		&ParseError($do_install, 1);
		$do_install = 0;
	}

	$GATE_TABLE{$dclname} = $do_install;
		
	if ($do_install == 0) {
		$is_gated_cache = 0;
	} else {
		# We only need to worry about procedures when the gate is good.

		# $the_procs now hold the procedures list from this declaration
		$PROCEDURE_TABLE{$dclname} = $the_procs;
		
		$is_gated_cache = &is_gated;

		print "procedures = '$procedures' the_procs = '$the_procs'\n"
			if ($DEBUG);
	}

	print "do_install = '$do_install' is_gated_cache = '$is_gated_cache'\n\n" if ($DEBUG);

	$TOKVAL = &scan'TokenWS;	# scan beyond EOL

	return 0;
}

sub mapping
# mapping      -> <filename> install_expr '<octal>' command
# return: 0 -> okay, got a mapping
#         1 -> this ain't no mapping
#         2 -> error
{
	if (&scan'LookAhead eq "=") {
 		#then it is a dcl, not a mapping
        #print "\nmapping its a dcl\n";
 		return 1;
	}

 	local($filename) = $TOKVAL;
	print "mapping: looking to build filename, currently '$filename'\n" if ($DEBUG);
	# If this filename has more than just the normal identifiers in
	# it, we have to read further.  &tok'getword will read until
	# whitespace.  $TOKVAL had the text of the filename upto any
	# special characters (including '/', directory separators).
	$filename .= &scan'GetUpToWS;
	print "filename = '$filename'\n" if ($DEBUG);

    local($install_expr_str);
    $install_expr_str = &scan'GetUpToWS;
	if ($install_expr_str eq "") {
        &ParseError("Install expression (destination filename) is empty.", 1);
        return 2;
	}
	print "install_expr_str = '$install_expr_str'\n" if ($DEBUG);

	local($mode) = &scan'TokenWS;		#assume it is octal for now
    print "mode = '$mode'\n" if ($DEBUG);
	if (! &scan'IsOctal($mode)) {
        &ParseError("Expected octal number for MODE got '$mode'", 1);
        return 2;
    }

	$TOKVAL = &scan'Token;

	local($cmdString) = "";
	if (&command(*cmdString)) {
		return 2;
	}
	
	if ($TOKVAL ne "\n") {
		&ParseError("Expected EOL, got '$TOKVAL'.", 1);
		return 2;
	}

    local($errorCount);
	$filename = &vars'expand_vars($filename, *ENV, *errorCount);
	printf("MAPPING: filename='%s' into '%s' mode='%s' cmd='%s'\n",
		   $filename, $install_expr_str, $mode, $cmdString) if ($DEBUG);

	# If they want us to actually install this file (it must be defined in
	# @'FILE_IN_INSTALLMAP), then we expand out all of the variables and 
	# ask for it to be installed.
	if (defined($minstall'FILE_IN_INSTALLMAP{$filename})) {
		++$minstall'FILE_IN_INSTALLMAP{$filename};
		# print "minstall'FILE_IN_INSTALLMAP{$filename} = $minstall'FILE_IN_INSTALLMAP{$filename}\n" if ($DEBUG);
		if ($is_gated_cache) {
			local(@dir_list);
			# The powers of expand_dir are not currently used.
			# @dir_list = &expand_dir(@install_expr_list);
			$install_expr_str = &vars'expand_vars($install_expr_str, *ENV, *errorCount); #'
            print "install_expr_str = '$install_expr_str'\n" if ($DEBUG);
			@dir_list = ($install_expr_str);

			# If the first element in the array has the special "BUILD_ERROR: "
			# token in front of it, then an error occured.
			if ($#dir_list+1 > 0 && $dir_list[0] =~ /^BUILD_ERROR: /) {
				&ParseError($dir_list[0], 1);
			} else {
				# install does the actual copying
				&minstall'install($filename, $mode, $minstall'BASE,
								  $procedures, $cmdString, @dir_list);
				
				print "FILE_IN_INSTALLMAP{$filename} = $minstall'FILE_IN_INSTALLMAP{$filename}\n" if ($DEBUG);
			}
		}
	}

	print "mapping: poke20\n" if ($DEBUG);
	$TOKVAL = &scan::TokenWS;
	print "mapping: poke26\n" if ($DEBUG);

    return 0;
}

sub command
# command      -> '['command_string']'|command_alias|<EOL>
{
	local(*cmdString) = @_;
	local($str, $endChar);
	
	$cmdString = "";
	print "command: TOKVAL='$TOKVAL'\n" if ($DEBUG);
	if ($TOKVAL eq "\n") {
		# Do not advance the token, as this is the EOL and our parent
		# expects an EOL.
		return 0;
	}
	if ($TOKVAL eq "[") {
		# read upto corresponding "]"
		local($bracketCount) = 1;
		$cmdString .= $TOKVAL;
		while ($bracketCount) {
			$str = &scan'GetUpToString("[]", *endChar); #'
			if ($endChar eq "[") {
				++$bracketCount;
			} elsif ($endChar eq "]") {
				--$bracketCount;
			} else {
				&ParseError("Unexpected EOL (bracketed expression not terminated).", 1);
				return 1;
			}
			$cmdString .= $str . $endChar;
			$TOKVAL = &scan'Token; #'
		}
	} else {
		# read upto whitespace or EOL
		$cmdString = $TOKVAL;
		$cmdString .= &scan'GetUpToWS;
		$TOKVAL = &scan'Token;
	}
	print "cmdString = '$cmdString' TOKVAL = '$TOKVAL'\n" if ($DEBUG);
	return 0;
}

sub dcl_elem
# dcl_elem     -> '*'
#              -> "''"		#two single quotes => empty string
#              -> idenlist
#              -> '{' idenlist }'
#              ->				#empty
#
# returns a string with the element.  If the element is a list,
# returns the list as a joined string.  Pasted onto the front of that
# string is either a 'P' or a 'D' signifying that this is a Permit
# list or a Deny list (curly braces denote a deny list).
{
	local (*dclval) = @_;
	local (@mylist);
	$dclval = "";	#result

	if ($TOKVAL eq "*") {
		$dclval = "P" . $TOKVAL;
		$TOKVAL = &scan'Token;
	} elsif ($TOKVAL eq '\'') {
		$TOKVAL = &scan'Token;
		if ($TOKVAL eq '\'') {
			$TOKVAL = &scan'Token;
			$dclval = "P" . "";	#empty
		} else {
			#don't know.
			# print "dcl_elem poke 3\n";
			return 1;
		}
	} elsif ($TOKVAL eq '{') {
		$TOKVAL = &scan'Token;
		if ($TOKVAL eq '*') {
			do {
				$TOKVAL = &scan'Token;
			} while ($TOKVAL ne '}' && ! $scan'EOF);
			$dclval = "D" . join($;, ("*"));
	    	$TOKVAL = &scan'Token;
		}
		if (! &idenlist(*mylist)) {
			if ($TOKVAL eq '}') {
				$TOKVAL = &scan'Token;
				$dclval = "D" . join($;, @mylist);
			} else {
				return 1;
			}
		} elsif ($TOKVAL eq '}') {
			$TOKVAL = &scan'Token;
			return 0;
		} else {
			# print "dcl_elem poke 10\n";
			return 1;
		}
	} elsif (! &idenlist(*mylist)) {
		$dclval = "P" . join($;, @mylist);
	} else {
		# print "dcl_elem poke 20\n";
		return 1;
	}

    # printf("dclval='%s'\n", $dclval);
	return 0;
}

sub idenlist
# idenlist     -> flist (',' flist) *
{
	local (*list) = @_;
	local($txt) = "";
	@list = ();		#result

	# print "idenlist poke 1\n";

	if (&flist(*txt)) {
		return 1;
	}
	push(@list, $txt);

	while ($TOKVAL eq ',') {
		$TOKVAL = &scan'Token;
		if (&flist(*txt)) {
			return 1;
		}
	    push(@list, $txt);
	}
	
	print "idenlist = (" . join(", ", @list) . ")\n" if ($DEBUG);
	return 0;
}

sub flist
# flist        -> '<iden>' ( ('|' | '^' '&' ) fexpr ) *
{
	local(*txt) = @_;
	local($hasAmpersand) = 0;
	local($separator);

	if (!&scan'IsIdentifier($TOKVAL)) {
		return 1;
	}

	$txt = $TOKVAL;
	$TOKVAL = &scan'Token;

	while ($TOKVAL eq '&' || $TOKVAL eq '|' || $TOKVAL eq '^') {
		$separator = $TOKVAL;
		$TOKVAL = &scan'Token;

		return 0 unless (&fexpr(*ftxt));

		if ($separator eq '|') {
			$txt .= "&post:";
		} elsif ($separator eq '^') {
			$txt .= "&pre:";
		} else {
			$txt .= "&during:";
		}

		$txt .= $ftxt;
		$hasAmpersand = 1;
	}

	if (! $hasAmpersand) {
		$txt .= "&";
	}

#print "flist = $txt\n";
	return 0;
}

sub fexpr
# fexpr        -> '<iden>' fparamlist ?
{
	local(*txt) = @_;
	$txt = "";		#result

#print "fexpr (A)\n";
	if (!&scan'IsIdentifier($TOKVAL)) {
		return 1;
	}

	$txt = $TOKVAL;
	$TOKVAL = &scan'Token;

	&fparamlist(*txt);	#optional

#print "fexpr (B) = $txt\n";
	return 1;
}

sub fparamlist
# fparamlist   -> '(' '<string>' ( ',' '<string>' )* ')'
{
	local(*txt) = @_;
	local($endChar);
	local($fptxt) = "";

#print "fparamlist A fptxt=$fptxt\n";
	return 1 unless ($TOKVAL eq '(');

	$fptxt .= '#!#';
	$TOKVAL = &scan'TokenWS; #'

#print "fparamlist B fptxt=$fptxt\n";
	while ($TOKVAL eq "\"") {
		$fptxt .= $TOKVAL;
		$fptxt .= &scan'GetUpTo("\"", *endChar); #'
		if ($endChar ne "\"") {
			&ParseError("Failed to find enclosing quote", 1);
			return 1;
		}
		$fptxt .= $endChar;
		$TOKVAL = &scan'Token;

		last unless ($TOKVAL eq ',');
		$fptxt .= $TOKVAL;
		$TOKVAL = &scan'Token;
	}

#print "fparamlist C fptxt=$fptxt\n";
	return 1 unless ($TOKVAL eq ')');

	#NOTE: discard final paren.
	$TOKVAL = &scan'Token; #'

    # print "fparamlist D fptxt=$fptxt\n";

	$txt .= $fptxt;
	return 0;
}

# sub expand_dir
# # expand_dir is a recursive function that will expand variables into a
# # list of strings.
# #
# # input: a list of strings.  It is assumed (but not required) that
# # these strings concatenate together to form a path name with
# # variables.  If the string begins with a '$', then it's a reference
# # to a variable; every value of that variable is then applied to every
# # string in the list gotten through recursion.  Without a '$', the
# # string itself is applied to every string in the list gotten through
# # recursion.
# # PERMIT_DCL{<variable name>} is a $; separated list where all values
# # from the '$' variables must be in PERMIT_DCL{} if PERMIT_DCL{} is
# # defined.  eg: TARGET_OS=(cmn,nt,mac) PERMIT_DCL{TARGET_OS}=(nt,cmn)
# #               => outList=(cmn,nt)
# # DENY_DCL{<variable_name>} is a $; separated list where the resultant
# # cannot be in DENY_DCL{}
# #
# # output: a list of strings without a variables.  This
# # list is assumed (but not required) to be a list of filenames with
# # the variables filled in.
# #
# # eg: input: (bin, /, $TARGET_OS, /, foo)
# #     TARGET_OS = (cmn, nt, mac)
# #     PERMIT_DCL{TARGET_OS} = (cmn,nt,mac,....)
# #     output: (bin/cmn/foo, bin/nt/foo, bin/mac/foo)
# {
# 	local(@dirs) = @_;
# 	local(@dir_list, $varName);
# 	local($value);
# 	local(@outList) = ();

# 	if ($#dirs+1 <= 0) {
# 		return ();
# 	}
# 	local($component) = shift @dirs;

# 	if ($#dirs+1 > 0) {
# 		@dir_list = &expand_dir(@dirs);
# 		# If there was an ERROR or if the list came back empty, then
# 		# we return that ERROR or we return the empty list.
# 		if ($#dir_list+1 <= 0 || $dir_list[0] =~ /^BUILD_ERROR: /) {
# 			return @dir_list;
# 		}
# 	}

# 	# print "comp = $component\n" if ($DEBUG);
# 	if (substr($component, 0, 1) eq "\$") {
# 		$varName = substr($component, 1);
# 		# print "varName = $varName\n";
# 		print "$varName is VARDEFSd to be $minstall'VARDEFS{$varName}\n" if ($DEBUG);
# 		if (!defined($minstall'VARDEFS{$varName})) {
# 		    return ("BUILD_ERROR: $varName is undefined");
# 		}

# 		local($value) = $minstall'VARDEFS{$varName};
# 		local(@temp_list);
# 		@outList = (@outList, &prepend_onto_list($value, @dir_list));
# 		print "outList = (" . join(", ", @outList) . ")\n" if ($DEBUG);
# 	} else {
# 		@outList = &prepend_onto_list($component, @dir_list);
# 	}

# 	return @outList;
# }

# sub prepend_onto_list
# # This is basicaly a scalar times by a vector.
# # Every item in <vec> will have <sca> concatenated onto the front of
# # the return list.
# # If <vec> is empty, then we return <sca> as a list.
# # eg: input:  sca = a   vec = (b,c,d)
# #     output: (ab,ac,ad)
# {
# 	local($sca, @vec) = @_;
# 	local($dir);
# 	local(@outList) = ();

# 	if ($#vec+1 <= 0) {
# 		@outList = ($sca);
# 	} else {
# 		foreach $dir (@vec) {
# 			push(@outList, $sca . $dir);
# 			# print "Just pushed $sca onto $dir\n";
# 		}
# 	}
# 	return @outList;
# }	

# sub append_onto_list
# # This is basicaly a scalar times by a vector.
# # Every item in <vec> will have <sca> concatenated onto the front of
# # the return list.
# # If <vec> is empty, then we return <sca> as a list.
# # eg: input:  sca = a   vec = (b,c,d)
# #     output: (ab,ac,ad)
# {
# 	local($sca, @vec) = @_;
# 	local($dir);
# 	local(@outList) = ();

# 	if ($#vec+1 <= 0) {
# 		@outList = ($sca);
# 	} else {
# 		foreach $dir (@vec) {
# 			push(@outList, $dir . $sca);
# 			# print "Just pushed $sca onto $dir\n";
# 		}
# 	}
# 	return @outList;
# }

sub test_var
# This is the subroutine that tests whether or not the next "scope"
# gets to do installs.  
{
	local($dclname, $dcl_type, *procedures, @dclvals) = @_;
	
 	printf("dclname=%s dcl_type = %s dclvals=(%s)\n", $dclname,
 				   $dcl_type, join(',', @dclvals)) if ($DEBUG);

	local($result) = $dcl_type eq "P" ? 1 : 0;
	
	if (!defined($minstall'VARDEFS{$dclname})) {
		return "BUILD_ERROR: $dclname is undefined";
	}
	local($vardef) = $minstall'VARDEFS{$dclname};
	local($filter, $filterops, $dummy);
	foreach $filterops (@dclvals) {
		($filter, $procedures) = ($filterops =~ /^([^&]+)(.*)$/);
		print "filter = '$filter' vardef = '$vardef'\n" if ($DEBUG);
		if ($filter eq "*" || $vardef eq $filter) {
			return $result;
		}
	}
	$procedures = "";
	return ($result ? 0 : 1);
}

sub is_gated
	# Are all of the gates in the GATE_TABLE saying true.
	# Essentially, are we gated at this point or not.
{
	local($k);

	$procedures = "";
	# If ever there is a false in the table, then the whole thing is
	# false (logical AND).
	foreach $k (keys %GATE_TABLE) {
		if ($GATE_TABLE{$k} == 0) {
			return 0;
		}
		$procedures .= $PROCEDURE_TABLE{$k};
	}
	return 1;
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
