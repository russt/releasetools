package bmail;

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
# @(#)bmail.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

use MIME::Lite;

$p = $'p;       #$main'p is the program name set by the skeleton
&init;      #init globals

sub main
{
#  $DOMIME = 1;
#  @TO_LIST = ();
#  $FROM_ADDR = ();
#  $SUBJECT = "(no subject)";
#  $SMTP_HOST = "mail";
#  $INPUT_FILE = "";
#  @ATTACH_LIST = ();
#  $USE_STDIN = 0;

    local(*ARGV, *ENV) = @_;

    #set global flags:
    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    if (&read_data() != 0) {
        printf STDERR ("%s: failed to process input data from file '%s'\n", $p, $INPUT_FILE);
        return 1;
    }

    $msg = MIME::Lite->new(
Subject  => $SUBJECT,
To       => join(',', @TO_LIST),
From     => $FROM_ADDR,
Data     => join("", @INPUT_DATA),
Encoding => '7bit',
     );


    &show_msg if ($VERBOSE || !$DOSEND);

    if ($DOSEND) {
        MIME::Lite->send('smtp', $SMTP_HOST, Timeout=>60);
        ### Now this will do the right thing:
        $msg->send;         ### will now use Net::SMTP as shown above
    }

    return 0;
}

sub show_msg
{
    printf "SMTP_HOST is '%s'\n", $SMTP_HOST;

    $msg->print(\*STDOUT);
}

sub read_data
{
    if ($USE_STDIN) {
        @INPUT_DATA = <STDIN>;
    } else {
        if (!open(INFILE, $INPUT_FILE)) {
            printf STDERR ("%s: can't open '%s'\n", $p, $INPUT_FILE);
            return 1;
        }
        @INPUT_DATA = <INFILE>;
        close INFILE;
    }

#printf "INPUT_DATA=(%s)\n", join(',',@INPUT_DATA);

    if ($#TO_LIST < 0) {
        #do we have a To address in data?
        @TO_LIST = grep(/^To:/, @INPUT_DATA);

#printf "TO_LIST=(%s)\n", join(',',@TO_LIST);

        #if we still are empty...
        if ($#TO_LIST >= 0) {
            #delete To: lines from data:
            @INPUT_DATA = grep(!/^To:/, @INPUT_DATA);
#printf "INPUT_DATA=(%s)\n", join(',',@INPUT_DATA);
            #chomp the TO_LIST:
            @TO_LIST = grep(chomp $_ && $_ =~ s/^To:\s*//, @TO_LIST);
        } else {
            #send it to ourselves
            if ($#TO_LIST < 0 && $LOGNAME ne "") {
                @TO_LIST = ($LOGNAME);
            } else {
                printf STDERR ("%s: can't compute a To: address.\n", $p);
                return 1;
            }
        }
    }

    if ($FROM_ADDR eq "") {
        #do we have a From address in data?
        my @tmp = grep(/^From:/, @INPUT_DATA);
        if ($#tmp >= 0) {
            $FROM_ADDR = $tmp[0];
            chomp $FROM_ADDR;
            $FROM_ADDR =~ s/^From:\s*//;
            #delete From: lines from data:
            @INPUT_DATA = grep(!/^From:/, @INPUT_DATA);
        } elsif ($LOGNAME ne "") {
            $FROM_ADDR = "$LOGNAME";
        } else {
            printf STDERR ("%s: can't compute a From: address.\n", $p);
            return 1;
        }

    }

    if ($SUBJECT eq "") {
        #do we have a Subject in data?
        my @tmp = grep(/^Subject:\s*/, @INPUT_DATA);
        if ($#tmp >= 0) {
            $SUBJECT = $tmp[0];
            chomp $SUBJECT;
            $SUBJECT =~ s/^Subject:\s*//;
            #delete Subject: lines from data:
            @INPUT_DATA = grep(!/^Subject:/, @INPUT_DATA);
        } else {
            $SUBJECT = "(no subject)";
        }
    }

    return 0;
}

################################ USAGE SUBROUTINES ###############################

sub usage
{
    local($status) = @_;

    print STDERR <<"!";
Usage:  $p [options...]

Synopsis:
  Portable email sender.  Message headers can be
  specified on the command line, or via the contents
  of the message file.  If input file is not specified,
  then reads message from stdin.

Options:
  -help  display this usage message and exit.
  -v     verbose output
  -test  display message, but don't send it.
  -to addr[,addr...]
         Send to comma-separated list of recipients.
  -from email_address
         Use this return address.
  -s string
         Use this string as the subject of the message.
  -smtp mailhost
         Use this STMP host instead of "mail".
  -i message_file
         Read this file as the body of the message.
         If an input file is not specified, then read stdin.

Environment:
 \$SMTP_HOST        Use this STMP host if not specified on command line.
 \$BMAIL_FROM_ADDR  Use this address as the -from address if otherwise specified.

!

#NOT IMPLEMENTED:
#  -mime  send MIME encoded message (default).
#  -text  send a plain-text message (turn off MIME).
#  -attach file[,file...]
#         Attach one or more files to the message.  If an html message
#         has references to gifs, this is the place to attach them.

    return($status);
}

sub parse_args
#proccess command-line aguments
{
    local(*ARGV, *ENV) = @_;
    my ($flag, $arg);

    #set defaults:
    $HELPFLAG = 0;
    $VERBOSE = 0;
    $DOMIME = 1;
    @TO_LIST = ();
    $FROM_ADDR = "";
    $SUBJECT = "";
    $SMTP_HOST = "";
    $INPUT_FILE = "";
    @ATTACH_LIST = ();
    $USE_STDIN = 0;
    $DOSEND = 1;

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
        $flag = shift(@ARGV);

        if ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return(&usage(0));
        } elsif ($flag =~ '^-v') {
            $VERBOSE = 1;
        } elsif ($flag eq '-mime') {
            #not implemented
            $DOMIME = 1;
        } elsif ($flag eq '-text') {
            #not implemented
            $DOMIME = 0;
        } elsif ($flag eq '-test') {
            $DOSEND = 0;
        } elsif ($flag eq '-to') {
            printf STDERR "%s: -from requires addr[,addr...].\n", $p if (!@ARGV);
            return(&usage(1)) if (!@ARGV);
            @TO_LIST = split(',', shift(@ARGV));
        } elsif ($flag eq '-from') {
            printf STDERR "%s: -from requires address.\n", $p if (!@ARGV);
            return(&usage(1)) if (!@ARGV);
            $FROM_ADDR = shift(@ARGV);
        } elsif ($flag eq '-s') {
            printf STDERR "%s: -s requires subject string.\n", $p if (!@ARGV);
            return(&usage(1)) if (!@ARGV);
            $SUBJECT = shift(@ARGV);
        } elsif ($flag eq '-smtp') {
            printf STDERR "%s: -smtp requires host name.\n", $p if (!@ARGV);
            return(&usage(1)) if (!@ARGV);
            $SMTP_HOST = shift(@ARGV);
        } elsif ($flag eq '-i') {
            printf STDERR "%s: -i requires file.\n", $p if (!@ARGV);
            return(&usage(1)) if (!@ARGV);
            $INPUT_FILE = shift(@ARGV);
        } elsif ($flag eq '-attach') {
            #not implemented
            printf STDERR "%s: -attach requires file[,file...].\n", $p if (!@ARGV);
            return(&usage(1)) if (!@ARGV);
            @ATTACH_LIST = split(',', shift(@ARGV));
        } else {
            return(&usage(1));
        }

    }

    if ($INPUT_FILE eq "") {
        $USE_STDIN = 1;
        $INPUT_FILE = "<STDIN>";
    }

    $FROM_ADDR = "";
    if ($SMTP_HOST eq "") {
        if ( defined($ENV{'SMTP_HOST'}) ) {
            $SMTP_HOST = $ENV{'SMTP_HOST'};
            printf STDERR ("%s: set SMTP_HOST to '%s' from environment\n", $p, $SMTP_HOST) if ($VERBOSE);
        } else {
            $SMTP_HOST = "mail";
            printf STDERR "%s: defaulting SMTP_HOST to '%s'\n", $p, $SMTP_HOST if ($VERBOSE);
        }
    }

    if ($FROM_ADDR eq "") {
        if ( defined($ENV{'BMAIL_FROM_ADDR'}) ) {
            $FROM_ADDR = $ENV{'BMAIL_FROM_ADDR'};
            printf STDERR ("%s: set FROM_ADDR to '%s' from environment\n", $p, $BMAIL_FROM_ADDR) if ($VERBOSE);
        }
    }

    #eliminate empty args (this happens on some platforms):
    @ARGV = grep(!/^$/, @ARGV);

    #display warning if unused args:
    if ($#ARGV >= 0) {
        printf STDERR "%s: WARNING: ignoring extra arguments: (%s)\n", $p, join(',', @ARGV);
        return(&usage(1));
    }

    return(0);
}

sub init
#copies of global vars from main package:
{
    $p = $'p;       #$main'p is the program name set by the skeleton

    #collect some env vars:
    $LOGNAME = "";
    $LOGNAME = $ENV{'LOGNAME'} if (defined($ENV{'LOGNAME'}));

#    $HOSTNAME = `sh -c "uname -n"`;
#    chomp $HOSTNAME;
#    $HOSTNAME = "localhost" if ($HOSTNAME eq "");
}

sub cleanup
{
}

1;
