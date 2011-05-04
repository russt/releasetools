#
# @(#)whereclasses.pl - ver 1.1 - 05/03/2011
#
# Copyright 2011 Russ Tremain. All Rights Reserved.
# 

#
# whereclasses - where did each file contained in a jar come from?
#

package whereclasses;

use strict;

my (
    $p,
    #options:
    $VERBOSE,
    $DEBUG,
    $DDEBUG,
    $HELPFLAG,
    $theJarToc,
    $theJarFile,
) = (
    $main::p,       #$main'p is the program name set by the skeleton
    0,    #VERBOSE option
    0,    #DEBUG
    0,    #DDEBUG
    0,    #HELPFLAG option
    "NULL",    #theJarToc
    "NULL",    #theJarFile
);

sub main
{
    local(*ARGV, *ENV) = @_;

    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    if (! -r $theJarToc ) {
        printf STDERR "%s:  jar toc '%s' is not readable.\n", $p, $theJarToc;
        return 1;
    }

    if (! -r $theJarFile ) {
        printf STDERR "%s:  jar file '%s' is not readable.\n", $p, $theJarFile;
        return 1;
    }
    
    #read the jar toc into my index:
    my %JARDB = ();
    if (&read_jardb(\%JARDB, $theJarToc) != 0) {
        printf STDERR "%s:  errors processing jar toc '%s'.\n", $p, $theJarToc;
        return 1;
    }

    my @JARTOC = ();
    if (&read_jartoc(\@JARTOC, $theJarFile) != 0) {
        printf STDERR "%s:  errors processing jar file '%s'.\n", $p, $theJarFile;
        return 1;
    }
#printf STDERR "#JARTOC=%d\n", $#JARTOC;

    #now, foreach entry in JARTOC, search the index and save the results:
    my @nojars = ();
    my %RESULT = ();
    for my $je (@JARTOC) {
#printf STDERR "je='%s'\n", $je;
        if ( defined($JARDB{$je}) ) {
            $RESULT{$je} = $JARDB{$je};
        } else {
            $RESULT{$je} = \@nojars;
        }
    }

    &show_results(\%RESULT);

    return 0;
}

################################# IMPLEMENTATION ###############################

sub read_jartoc
{
    my ($listOut, $fn) = @_;

    my @tmp = `jar tf "$fn"`;

    if ($#tmp < 0) {
        printf STDERR "%s[read_jardb]:  cannot get jar entries from '%s' (%s).\n", $p, $fn, $!;
        return 1;
    }

    printf STDERR "%s:  read %d entries from '%s'\n", $p, $#tmp+1, $fn;

    @tmp = grep(chomp, @tmp);

    #exclude directories:
    @tmp = grep($_ !~ /\/$/ && $_ !~ /^META-INF\// , @tmp);

    @$listOut = @tmp;

    return 0;
}

sub read_jardb
{
    my ($hashOut, $fn) = @_;

    if (!open(INFILE, $fn)) {
        printf STDERR "%s[read_jardb]:  cannot open jartoc output, '%s'.\n", $p, $fn;
        return 1;
    }

    my %tmp = ();
    my $cnt = 0;
    my $nentries = 0;

    while(<INFILE>) {
        chomp($_);
        my ($jarname, $je)  = split(/\s+/, $_);

        ++$cnt;

        if (!defined($je)) {
            printf STDERR "%s[read_jardb]:  bad entry, line #%d in jar toc '%s' - ABORT.\n", $p, $cnt, $fn;
            return 1;
        }

        if (defined $tmp{$je}) {
            push @{$tmp{$je}} , $jarname;
        } else {
            $tmp{$je} = [$jarname];
            ++$nentries;
        }
    }
    close(INFILE);
    %$hashOut = %tmp;

    printf STDERR "%s:  added %d unique entries from %d read from '%s'\n", $p, $nentries, $cnt, $fn;

    return 0;
}

sub show_results
{
    my ($outRef) = @_;

    for my $kk ( sort keys %{$outRef} ) {
        printf "%s:\n\t%s\n", $kk, join("\n\t", @{${$outRef}{$kk}});
    }
}

############################### USAGE SUBROUTINES ##############################

sub parse_args
#proccess command-line aguments
{
    local(*ARGV, *ENV) = @_;

    #eat up flag args:
    my ($flag);
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
        $flag = shift(@ARGV);

        if ($flag =~ '^-v') {
            $VERBOSE = 1;
        } elsif ($flag =~ '^-d') {
            $DEBUG = 1;
        } elsif ($flag =~ '^-dd') {
            $DDEBUG = 1;
        } elsif ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return &usage(0);
        } else {
            printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
            return &usage(1);
        }
    }

    #eliminate empty args (this happens on some platforms):
    @ARGV = grep(!/^$/, @ARGV);

    if ($#ARGV >= 1) {
        $theJarFile = shift(@ARGV);
        $theJarToc = shift(@ARGV);
    } else {
        printf STDERR "%s:  not enough arguments!\n", $p;
        return &usage(1);
    }

    return 0;
}

sub usage
{
    my($status) = @_;

    print STDERR <<"!";
Usage:  $p [-help] [-verbose] jarfile jartoc_index

SYNOPSIS
  Look-up each entry in jarfile and determine the origin jar in jartoc.
  Ignore directory and META-INF entries.

OPTIONS
  -help    Display this help message.
  -verbose Display informational messages.
  -debug   Display debug messages.

EXAMPLE
  % jartoc `find somedir -name '*.jar'` > /tmp/jartoc.txt
  % $p foo.jar /tmp/jartoc.txt
!
    return ($status);
}

sub cleanup
{
}
1;
