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
# @(#)jxtohtml.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#jxtohtml - if input file contains java exception traces,
#             1. convert the file to html.
#             2. convert the exception strings to javadoc -linksource hrefs.
#
# 11-Dec-02
#	russt - created.

package jxtohtml;

require "path.pl";

&init;

#################################### MAIN #####################################

sub main
{
    local (*ARGV, *ENV) = @_;

    #set global flags:
    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    return (-1) unless (&check_and_set_env());

    my ($status) = &jxtohtml($INFILE);

    if ($status eq 0 && $VERBOSE) {
        if ($OUTFILE ne "") {
            printf STDERR "%s: %s -> %s\n", $p, $INFILE, $OUTFILE;
        } else {
            printf STDERR "%s: %s -> stdout\n", $p, $INFILE, $OUTFILE;
        }
    } elsif ($status eq 1 && $VERBOSE > 1) {
		printf STDERR "%s: %s examined.\n", $p, $INFILE;
	}

	return(1) if ($status < 0);		#errors encountered

    return(0);
}

sub jxtohtml
#return 0 if found and translated one or more exceptions
#return 1 if no exceptions
#return -1 if errors
{
    my ($fn) = @_;
    my(@intxt) = ();

    #read the file into a list:
    if (open(INFILE, $fn)) {
        @intxt = <INFILE>;
        close INFILE;
    } else {
        printf STDERR "%s:  cannot open '%s' for reading (%s).\n", $p, $fn, $!;
        return -1;
    }

#printf STDERR "jxtohtml T0 cnt=%d\n", $#intxt;

    return 1 if ($#intxt < 0);  #empty file

#printf STDERR "jxtohtml T1 cnt=%d\n", $#intxt;

    #get rid of line endings:
    grep(chomp($_), @intxt);

#printf STDERR "jxtohtml T2 cnt=%d\n", $#intxt;

    if (!&has_exceptions(\@intxt)) {
        return 1;
    }

    &convert_exceptions(\@intxt);

    #output it:
    if ($OUTFILE eq "") {
        printf "%s\n", join("\n", @intxt);
    } else {
        if (open(OUTFILE, ">$OUTFILE")) {
            printf OUTFILE "%s\n", join("\n", @intxt);
        } else {
            printf STDERR "%s:  cannot open '%s' for writing (%s).\n", $p, $OUTFILE, $!;
            return -1;
        }
    }

    return 0;
}

sub convert_exceptions
#convert all exceptions to javadoc -linksource href's
{
    my ($inref) = @_;
    my ($htmltab) = '&nbsp; &nbsp; &nbsp; &nbsp;';      #an html tab stop, sort of.

#printf STDERR "convert_exceptions T0\n";

    #EXAMPLE:
    #IN:    at com.sun.iis.ebxml.internal.support.io.SharedFileOutputStream.<init>(SharedFileOutputStream.java:31)
    #OUT:   <A HREF="$HTML_SRCROOT/com/sun/iis/ebxml/internal/support/io/SharedFileOutputStream.html#line.31">at com.sun.iis.ebxml.internal.support.io.SharedFileOutputStream.<init>(SharedFileOutputStream.java:31)</A>

    for ($ii=0; $ii <= $#{$inref}; $ii++) {
        my $linetxt = ${$inref}[$ii];

#printf STDERR "line %d: '%s'\n", $ii, $linetxt;

        my ($linenum,$pkg);
        if ( $linetxt =~ /$MATCH_PATTERN/ && &package_prefix_match($1) ) {
            $pkg = $1;      #from pattern match in if ()...
            $linenum = $2;  #ditto

#printf STDERR "line %d: linenum='%s' pkg='%s'\n", $ii, $linenum, $pkg;

            #fix the package name:
            my @xx = split('[(]', $pkg);
            $pkg = $xx[0];
            $pkg =~ s/\.[^\.]+$//;  #get rid of method from pkg name
            $pkg =~ s|\.|/|g;   #change pkg to path

            $linetxt =~ s/^\t//;
            ${$inref}[$ii] = sprintf("<br>\n%s<A HREF=\"%s/%s.html#line.%d\">%s</A>", $htmltab, $HTML_SRCROOT, $pkg, $linenum, $linetxt);

        } else {
            #replace spaces at beginning of line with $htmltab.
            #this only approximates the original doc, but oh well...

            my $indent = "";
            $indent = $htmltab if ( $linetxt =~ /^\s+/);

            $linetxt =~ s/^\s+//;
            ${$inref}[$ii] = sprintf("<br>\n%s%s", $indent, $linetxt);
        }
    }
}

sub package_prefix_match
#true if <string> matches one of our included packages
{
    my ($pkgstr) = @_;

    return 1 if ($HAVE_PKG_DEFS == 0);  #no package defs

    #if included...
    if ( grep(index($pkgstr, $_) >= 0, @INCLUDE_PACKAGES) ) {
        return 1 if ($#EXCLUDE_PACKAGES < 0);   #exclude not defined

        #yes, unless excluded:
        return 0 if ( grep(index($pkgstr, $_) >= 0, @EXCLUDE_PACKAGES) );

        return 1;   #included but not excluded;
    }

    return 0;   #no match
}

sub has_exceptions
#true if <inref> list has java exceptions
{
    my ($inref) = @_;


#my $cnt = grep(/$RECOGNIZE_PATTERN/, @{$inref});
#printf STDERR "has_exceptions T0 cnt=%d\n", $cnt;
#printf STDERR "has_exceptions T0 cnt=%d input=(\n%s\n)\n", $cnt, join("\n", @{$inref});

    if (grep(/$RECOGNIZE_PATTERN/, @{$inref}) > 0) {
        return 1
    }

    return 0;
}

################################ USAGE SUBROUTINES ###############################

sub usage
{
    my($status) = @_;

    print STDERR <<"!";
Usage:  $p [options] logfile

Synopsis:
 If <logfile> has one or more java exception traces, convert it
 to html with hrefs to an xref annotated source tree.

Options:
 -help     display this usage message
 -v        display verbose messages to STDERR
 -vv       be more verbose (show each file examined)
 -out fn   if exception traces found, output the html to <fn> instead of stdout

Environment:
 \$HTML_SRCROOT       The root of the xref-decorated source tree.

 \$INCLUDE_PACKAGES   Semi-colon delimited list of packages that have xref'd source.
                     If \$INCLUDE_PACKAGES is undefined, will include all packages
                     that are not listed in \$EXCLUDE_PACKAGES.

 \$EXCLUDE_PACKAGES   Semi-colon delimited list of packages to exclude.

Example:
 setenv HTML_SRCROOT "http://iis.sfbay/sodor/main/javadoc/regress_javadoc/src-html"
 setenv INCLUDE_PACKAGES "com.sun.iis.ebxml"

 $p somejava.log

!
    return($status);
}

sub parse_args
#proccess command-line aguments
{
    local (*ARGV, *ENV) = @_;

    $OUTFILE = "";
    $VERBOSE = 0;

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
        $flag = shift(@ARGV);

        if ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return &usage(0);
        } elsif ($flag eq '-v') {
            $VERBOSE = 1;
        } elsif ($flag eq '-vv') {
            $VERBOSE = 2;
        } elsif ($flag eq "-out") {
            return &usage(1) if (!@ARGV);
            $OUTFILE = shift(@ARGV);
        } else {
            printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
            return &usage(1);
        }
    }

    #take remaining args as files to parse:
    if ($#ARGV < 0) {
        printf STDERR "%s:  you must name a file to convert.\n", $p;
        return &usage(1);
    } else {
        $INFILE = shift(@ARGV);
    }

    return(0);
}

sub init
{
    #set recognition pattern.  look for optional ant task string at beginning of line:

    #EXAMPLE: "\tcom.sun.iis.ebxml.internal.support.io.SharedFileOutputStream.<init>(SharedFileOutputStream.java:31)"
    #EXAMPLE: "\tat com.sun.iis.ebxml.internal.support.io.SharedFileOutputStream.<init>(SharedFileOutputStream.java:31)"
    #EXAMPLE: "\s+[junit] \tat com.sun.iis.ebxml.internal.api.TracedException.logStackTrace(TracedException.java:105)
    #                    ^^  this is a space-tab sequence!

    $MATCH_PATTERN = '\ta?t? ?(.*\.java):(\d+)\)$';
        # $1 is 'package+method(filename.java', $2 is the line number.
        # split $1 on '(' to get package name.
        # discard method and convert '.' to '/' to get relative source file name

    $RECOGNIZE_PATTERN = $MATCH_PATTERN;
}

sub check_and_set_env
#return true if okay.
{
    my $nerrs = 0;
    if (defined($ENV{'HTML_SRCROOT'})) {
        $HTML_SRCROOT = $ENV{'HTML_SRCROOT'};
    } else {
        $HTML_SRCROOT = "http://iis.sfbay/sodor/main/javadoc/regress_javadoc/src-html";
        printf STDERR "%s:  WARNING: HTML_SRCROOT is not defined, defaulted to '%s'.\n", $p, $HTML_SRCROOT;
    }

    $HAVE_PKG_DEFS = 0;

    @INCLUDE_PACKAGES = ();
    if (defined($ENV{'INCLUDE_PACKAGES'})) {
        @INCLUDE_PACKAGES = split(';', $ENV{'INCLUDE_PACKAGES'});
        $HAVE_PKG_DEFS = 1;
    }

    @EXCLUDE_PACKAGES = ();
    if (defined($ENV{'EXCLUDE_PACKAGES'})) {
        @EXCLUDE_PACKAGES = split(';', $ENV{'EXCLUDE_PACKAGES'});
        $HAVE_PKG_DEFS = 1;
    }

#printf STDERR "HAVE_PKG_DEFS=%d INCLUDE_PACKAGES=(%s) EXCLUDE_PACKAGES=(%s)\n", $HAVE_PKG_DEFS, join(",", @INCLUDE_PACKAGES), join(",", @EXCLUDE_PACKAGES);

    if ($HAVE_PKG_DEFS == 0) {
        @INCLUDE_PACKAGES = ("com.sun.iis.ebxml");
        printf STDERR ("%s:  WARNING: INCLUDE_PACKAGES is not defined, defaulted to '%s'.\n", $p, join(';', @INCLUDE_PACKAGES));
        $HAVE_PKG_DEFS = 1;
    }

    return ($nerrs == 0);
}

1;
