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
# @(#)shprops.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# shprops - get/set sh/csh properties from a file
#

package shprops;

$p = $'p;       #$main'p is the program name set by the skeleton

&init;      #init globals

sub main
{
    local(*ARGV, *ENV) = @_;

    &init;      #init globals

    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    if (&read_properties($PROPFILE) != 0) {
        return 1;
    }

    if ($SETMODE) {
        &set_properties(@ARGV);
        return &write_properties($PROPFILE);
    } else {
        return &get_properties(@ARGV);
    }

    return 0;
}

sub set_properties
#add or replace a property
#return 0 if no errors.
{
    my (@vardefs) = @_;

    my($vardef);
    for $vardef (@vardefs) {
        next if ($vardef eq "");                  #empty def

        my(@avar) = split('=', $vardef);
        next if ($#avar < 0 || $avar[0] eq "");   #no var name

        if ($#avar+1  < 2) {
            $avar[1] = "";    #empty value.
        }

        printf STDERR ("Setting %s=%s\n", $avar[0], &quoteit($avar[1]) ) if ($VERBOSE);
        $PROPERTIES{$avar[0]} = &quoteit($avar[1]);
    }

    return 0;
}

sub get_properties
#retrieve a property and output it in a form as specified by user
#if property does not exist, then display error to stderr if -verbose.
#return 0 if no errors.
{
    my (@vars) = @_;

    #dump all properties if none specified.
    if ($#vars < 0) {
        @vars = (sort keys %PROPERTIES);
    }

    my($var);
    for $var (@vars) {
        next if ($var eq "");      #empty var

        if (defined($PROPERTIES{$var})) {
            printf "%s\n", &gendef($var, $PROPERTIES{$var});
        }
    }

    return 0;
}

sub read_properties
#return 0 if no errors
{
    my ($filename) = @_;

    if (!open(INFILE, $filename)) {
        if ($GETMODE) {
            printf STDERR ("%s:  ERROR:  can't open properties file '%s' for reading.\n", $p, $PROPFILE);
            return 1;
        } else {
            printf STDERR ("%s:  will create new properties file '%s'\n", $p, $PROPFILE) if ($VERBOSE);;
            return 0;
        }
    }

    my($line, $linecnt) = ("", 0);
    my($errcnt) = 0;

    while (defined($line = <INFILE>)) {
        ++$linecnt;
        $line =~ s/[\r\n]*$//;         #allows files from mult. platforms

        printf STDERR ("Reading line [%d] %s\n", $linecnt, $line) if ($VERBOSE);

        next if ($line =~ /^\s*#/);    #skip comment lines

        my(@rec) = split('=', $line, 2);
        if ($#rec+1 != 2 || $rec[0] eq "") {
            printf STDERR ("%s:  ERROR:  bad record, line %d, file %s - ABORT.\n", $p, $linecnt, $PROPFILE);
            ++$errcnt;
            last;
        }

        $PROPERTIES{$rec[0]} = $rec[1];
    }

    close(INFILE);

    return $errcnt;
}

sub write_properties
#return 0 if no errors
{
    my ($filename) = @_;

    if (!open(OUTFILE, ">$filename")) {
        printf STDERR ("%s:  ERROR:  can't open properties file '%s' for writing.\n", $p, $PROPFILE);
        return 1;
    }

    for $kk (sort keys %PROPERTIES) {
        printf OUTFILE ("%s=%s\n", $kk, $PROPERTIES{$kk});
    }

    close OUTFILE;
    return 0;
}

sub gendef
#generate definition strings, as per shell and export options
#returns string.
{
    my ($var, $val) = @_;

    #generate quoted values if requested:
    $val = &quoteit($val);

    if ($DO_CSH) {
        if ($DO_EXPORT) {
            return sprintf("setenv %s %s;", $var, $val);
        } else {
            return sprintf("set %s = %s;", $var, $val);
        }
    } else {
        if ($DO_EXPORT) {
            return sprintf("export %s; %s=%s;", $var, $var, $val);
        } else {
            return sprintf("%s=%s;", $var, $val);
        }
    }

    return "";    #NOTREACHED
}

sub quoteit
#return a quoted string, as specified by command line options.
{
    my ($val) = @_;

    if ($DO_SQUOTE) {
        return("'" . $val . "'");
    } elsif ($DO_DQUOTE) {
        return('"' . $val . '"');
    } elsif ($DO_QUOTE) {
        if ($val =~ /'/ || $val =~ /\$/) {
            return('"' . $val . '"');
        } else {
            return("'" . $val . "'");
        }
    }

    return($val);
}

sub init
{
}

sub parse_args
#proccess command-line aguments
{
    local(*ARGV, *ENV) = @_;

    $DO_QUOTE = $DO_DQUOTE = $DO_SQUOTE = $GETMODE = $SETMODE = 0;
    $DO_EXPORT = $DO_CSH = 0;
    $VERBOSE = $HELPFLAG = 0;
    $PROPFILE = "";

    #eat up flag args:
    my ($flag);
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
        $flag = shift(@ARGV);

        if ($flag eq "-get") {
            return &usage(1) if (!@ARGV);
            $GETMODE = 1;
            $PROPFILE = shift(@ARGV);
            if ($PROPFILE =~ /^-/) {
                printf STDERR "%s:  -get option requires a file arg.\n", $p;
                return &usage(1);
            }
        } elsif ($flag eq "-set") {
            return &usage(1) if (!@ARGV);
            $SETMODE = 1;
            $PROPFILE = shift(@ARGV);
            if ($PROPFILE =~ /^-/) {
                printf STDERR "%s:  -set option requires a file arg.\n", $p;
                return &usage(1);
            }
        } elsif ($flag =~ '^-csh') {
            $DO_CSH = 1;
        } elsif ($flag =~ '^-e') {
            $DO_EXPORT = 1;
        } elsif ($flag =~ '^-q') {
            $DO_QUOTE = 1;
        } elsif ($flag =~ '^-dq') {
            $DO_DQUOTE = 1;
        } elsif ($flag =~ '^-sq') {
            $DO_SQUOTE = 1;
        } elsif ($flag =~ '^-v') {
            $VERBOSE = 1;
        } elsif ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return &usage(0);
        } else {
            printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
            return &usage(1);
        }
    }

    if (($DO_QUOTE + $DO_DQUOTE + $DO_SQUOTE) > 1) {
        printf STDERR "%s:  one only of -quote, -squote, and -dquote is allowed.\n", $p, $flag;
        return &usage(1);
    }

    if (($SETMODE + $GETMODE) != 1) {
        printf STDERR "%s:  must select -get or -set but not both\n", $p, $flag;
        return &usage(1);
    }

    return 0;
}

sub usage
{
    local($status) = @_;

    print STDERR <<"!";
Usage:  $p [-help] [-verbose] -get properties_file [-e] [-csh] [property ...]
        $p [-help] [-verbose] -set properties_file property=value
                [-quote] [-squote] [-dquote] [property=value ...]

SYNOPSIS
  Manage a file of shell properties (variables).  First form sets or resets
  variables in <properties_file>.  Second form retrieves named variables
  from the properties file and generates output that can be evaluated by
  a shell command interpreter.

OPTIONS
  -help    Display this help message.
  -verbose Display informational messages.
  -e       [get] generate output to export definitions to the environment.
  -csh     [get] generate output suitable to be evaluated by csh or tcsh.
                 Default is to generate definitions suitable for sh, ksh, or bash.
  -quote   [set] store single-quoted values instead of plain values.  If the
                 value contains single quote or \$ chars, double quotes are
                 used so the variables will be re-expanded when the shell
                 processes them.  If the value contains double quotes, then
                 sinqle quotes are used.  If it contains both double and single
                 quotes, then use the -squote or -dquote options to specify
                 how to quote.
  -squote  [set] always single quote the values.
  -dquote  [set] always double quote the values.

EXAMPLES
  % eval `$p -get bldparams.sh -e -csh FOOVAR`
  \$ eval `$p -get bldparams.sh -e FOOVAR`
  % $p -quote -set bldparams.sh FOOVAR='1 + 2'

NOTES
  The properties file is not meant to be hand-edited.  Do this at your
  own risk.

!
    return ($status);
}

sub cleanup
{
}
1;
