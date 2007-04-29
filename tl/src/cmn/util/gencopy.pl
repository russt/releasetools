package gencopy;	#generate commands for local OS to copy file & dirs

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
# @(#)gencopy.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


require "path.pl";

$p = $'p;		#$main'p is the program name set by the skeleton

sub main
{
	local(*ARGV, *ENV) = @_;

	&init;

	#set global options:
	return (1) if (&parse_args(*ARGV, *ENV) != 0);
	return (0) if ($HELPFLAG);

	for $ff (@SPECS) {
		if (!&gencopy($ff)) {
			printf STDERR ("%s:  errors processing copy spec '%s'\n", $p, $ff);
			return(1);
		}
	}

	return 0;
}

sub gencopy
#returns true on success, false on error.
{
	local($fn) = @_;
	local($cnt) = 0;
	local($nerrors) = 0;

	@OUTBUF = ();
	%VARREFS = ();

	if (!open(INFILE, $fn)) {
		printf STDERR ("%s:  can't open '%s'\n", $p, $fn);
		return 0;
	}

	while (<INFILE>) {
		++$cnt;
		#skip comments, blank lines:
		next if (/^\s*#/ || /^\s*$/);

		# Remove any end of line characters.
		$_ =~ s/[\r\n]+$//;

		@INREC = split("\t", $_);

		if (&copyfile()) {
			;
		} elsif (&copydir) {
			;
		} elsif (&deletefile) {
			;
		} elsif (&deletedir) {
			;
		} elsif (&makedir) {
			;
		} else {
			printf STDERR ("%s: bad line, %d\n", $p, $cnt);
			++$nerrors;
		}
	}

	if ($nerrors == 0) {
		&output;
		return 1;	#SUCCESS
	}

	return 0;	#FAILED - errors
}

sub output
{
	&gen_script_header;
	&gen_envcheck;
	print @OUTBUF;
}

sub gen_script_header
{
	if ($TARGET_OS == $UNIX || $TARGET_OS == $NT) {
		print "#!/bin/sh\n";
	} elsif ($TARGET_OS == $MACINTOSH) {
		print "set exit 0\n\n";
	} else {
	}
}

sub gen_envcheck
{
	local ($evar);

	for $evar (sort keys %VARREFS) {
		&gen_checkvar($evar);
	}

	print "\n";
}

sub gen_checkvar
{
	local ($evar) = @_;

	if ($TARGET_OS == $MACINTOSH) {

		print <<"!";
if ( "{$evar}" == "" )
	echo {0} - '$evar' - undefined variable.
	exit 1
end
!

	} else {

		print <<"!";
if [ "\$$evar" = "" ]; then
	echo \$0 - '$evar' - undefined variable.
	exit 1
fi
!

	}
}

sub filespec
{
	local ($tok) = @_;

	#save var refs:
	local(@fspec) = split('/', $tok);
	for (@fspec) {
		if (/^\$/) {
			s/^\$//;
			++$VARREFS{$_};
		}
	}

	if ($TARGET_OS == $UNIX || $TARGET_OS == $NT) {
		return $tok;
	} elsif ($TARGET_OS == $MACINTOSH) {
		$tok =~ s|\$([^/]+)|{$1}|g;
		$tok =~ s|/|:|g;
		return $tok;
	} else {
		return $tok;
	}
}

sub copydir
{
	local ($ii) = 0;
	local ($tok, $src, $dst);

	return 0 if ($#INREC != 2);

	$tok = $INREC[$ii++];

	if ($tok !~ /$COPYDIR_TOK/i) {
		return 0;
	}

	$tok = $INREC[$ii++];
	$src = &filespec($tok);

	$tok = $INREC[$ii++];
	$dst = &filespec($tok);

	return &gencopydir($src, $dst);
}

sub copyfile
{
	local ($ii) = 0;
	local ($tok, $src, $dst);

	return 0 if ($#INREC != 2);

	$tok = $INREC[$ii++];

	if ($tok !~ /$COPYFILE_TOK/i) {
		return 0;
	}

	$tok = $INREC[$ii++];
	$src = &filespec($tok);

	$tok = $INREC[$ii++];
	$dst = &filespec($tok);

	return &gencopyfile($src, $dst);
}

sub deletefile
{
	local ($ii) = 0;
	local ($tok, $del);

	return 0 if ($#INREC != 1);

	$tok = $INREC[$ii++];

	if ($tok !~ /$DELETEFILE_TOK/i) {
		return 0;
	}

	$tok = $INREC[$ii++];
	$del = &filespec($tok);

	return &gendeletefile($del);
}

sub deletedir
{
	local ($ii) = 0;
	local ($tok, $del);

	return 0 if ($#INREC != 1);

	$tok = $INREC[$ii++];

	if ($tok !~ /$DELETEDIR_TOK/i) {
		return 0;
	}

	$tok = $INREC[$ii++];
	$del = &filespec($tok);

	return &gendeletedir($del);
}

sub makedir
{
	local ($ii) = 0;
	local ($tok, $dir);

	return 0 if ($#INREC != 1);

	$tok = $INREC[$ii++];

	if ($tok !~ /$MAKEDIR_TOK/i) {
		return 0;
	}

	$tok = $INREC[$ii++];
	$dir = &filespec($tok);

	return &genmakedir($dir);
}

sub gencopyfile
{
	local ($src, $dst) = @_;

	push (@OUTBUF, <<"!");
echo "	FILE $src --> $dst"
!

	if ($TARGET_OS == $UNIX || $TARGET_OS == $NT) {
		push (@OUTBUF, sprintf("cp \"%s\"  \"%s\"\n", $src, $dst));
	} elsif ($TARGET_OS == $MACINTOSH) {
		push (@OUTBUF, sprintf("duplicate -y \"%s\"  \"%s\"\n", $src, $dst));
	} else {
		pop @OUTBUF;
		return 0;
	}

	return 1;
}

sub gencopydir
{
	local ($src, $dst) = @_;

	push (@OUTBUF, <<"!");
echo "	DIR $src --> $dst"
!

	if ($TARGET_OS == $UNIX || $TARGET_OS == $NT) {
		push (@OUTBUF, sprintf("cp -r \"%s\"  \"%s\"\n", $src, $dst));
	} elsif ($TARGET_OS == $MACINTOSH) {
		push (@OUTBUF, sprintf("duplicate -y \"%s\"  \"%s\"\n", $src, $dst));
	} else {
		pop @OUTBUF;
		return 0;
	}

	return 1;
}

sub gendeletefile
{
	local ($fn) = @_;

	if ($TARGET_OS == $UNIX || $TARGET_OS == $NT) {
		push (@OUTBUF, sprintf("rm -f  \"%s\"\n", $fn));
	} elsif ($TARGET_OS == $MACINTOSH) {
		push (@OUTBUF, sprintf("killfile \"%s\"\n", $fn));
	} else {
		return 0;
	}
	
	return 1;
}

sub gendeletedir
{
	local ($fn) = @_;

	if ($TARGET_OS == $UNIX || $TARGET_OS == $NT) {
		push (@OUTBUF, sprintf("rm -rf  \"%s\"\n", $fn));
	} elsif ($TARGET_OS == $MACINTOSH) {
		push (@OUTBUF, sprintf("killfile \"%s\"\n", $fn));
	} else {
		return 0;
	}

	return 1;
}

sub genmakedir
{
	local ($fn) = @_;

	if ($TARGET_OS == $UNIX || $TARGET_OS == $NT) {
		push (@OUTBUF, sprintf("installdir \"%s\"\n", $fn));
	} elsif ($TARGET_OS == $MACINTOSH) {
		push (@OUTBUF, sprintf("installdir \"%s\"\n", $fn));
	} else {
		return 0;
	}

	return 1;
}

sub parse_args
#proccess command-line aguments
{
	local(*ARGV, *ENV) = @_;
	local($flag, $arg);

	$TARGET_OS = $OS;

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flag = shift(@ARGV);

		if ($flag =~ '^-h') {
			$HELPFLAG = 1;
			return &usage(0);
		} elsif ($flag eq "-os") {
			return &usage(1) if (!@ARGV);
			$arg = shift(@ARGV);

			if (!&valid_os(*TARGET_OS, $arg)) {
				printf STDERR ("%s: bad -os, '%s', valid args are: {%s}\n",
					$p,$arg, join(',', sort keys %VALID_TARGETS));
				return &usage(1) 
			}

		} else {
			return &usage(1);
		}
    }

#printf "TARGET_OS=%d MAC=%d UNIX=%d NT=%d\n", $TARGET_OS, $MACINTOSH, $UNIX, $NT;

    #take remaining args as input files:
    if ($#ARGV >= 0) {
		@SPECS = @ARGV;
	} else {
		return &usage(1);
	}

	return(0);
}

sub usage
{
	local($status) = @_;
	local($valid) = join("|", sort keys %VALID_TARGETS);

    print STDERR <<"!";
Usage:  $p [-os {$valid}] copy_spec_files...

Options:
 -os <platform>
     output commands appropriate for <platform>.

Syntax of copy_spec_files:
 copy_spec  -> (specline|comment)*
 specline   -> copydir | copyfile | deletefile
 comment    -> <spaces>* '#' <text> <EOL>
 copydir    -> 'COPYDIR'  <tab> filespec <tab> filespec
 copyfile   -> 'COPYFILE' <tab> filespec <tab> filespec
 deletedir  -> 'DELETEDIR' <tab> filespec
 deletefile -> 'DELETEFILE' <tab> filespec
 makedir    -> 'MAKEDIR' <tab> filespec
 filespec   -> var ('/' (name|var))*
 var        -> '<' iden '>' ('/' name)*
 name       -> <iden> (' ' <iden>)*

Notes:
 filespecs can be directories or plain files where appropriate.
!
    return($status);
}

sub cleanup
{
}

sub valid_os
#convert string specifying os to $OS token
#result returned in <osval>, true if found.
{
	local (*osval, $ostr) = @_;

	# Convert key to lower case.
	$ostr = lc($ostr);

	return(0) if (!defined($osval = $VALID_TARGETS{$ostr}));

	return(1)
}

sub init
{
	#
	#initialize token values:
	#
	$COPYDIR_TOK = '^COPYDIR$';
	$COPYFILE_TOK = '^COPYFILE$';
	$DELETEFILE_TOK = '^DELETEFILE$';
	$DELETEDIR_TOK = '^DELETEDIR$';
	$MAKEDIR_TOK = '^MAKEDIR$';

	#make local copies of some vars defined in prlskel:
	$OS = $'OS;
	$UNIX = $'UNIX;
	$MACINTOSH = $'MACINTOSH;
	$NT = $'NT;

	%VALID_TARGETS = (
		'unix', $UNIX,
		'mac', $MACINTOSH,
		'ntcmn', $NT,
		'nt', $NT,
		'axpnt', $NT,
	);

}
1;
