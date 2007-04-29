package changes;
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
# @(#)changes.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


# changes - List modified, added and deleted files in the local path.
#

use strict;

use Time::Local;
require "path.pl";
require "walkdir.pl";

# declare global variables, SCALARS only in this section:
my $SRCROOT = "NULL";
my $CHANGES_PATH=$ENV{CHANGES_PATH}; 
my $DEBUG=1;
my $p = $'p;       #$main'p is the program name set by the skeleton
my $DOT = $'DOT;
my $VOLUME=0;
my $REVNUMBER="NULL";

#Read CVS/Entries file
my $FILENAME = 0;
my $REVNO = 1;
my $TIMESTAMP = 2;

my $NEW=0;
my $DELETED=0;
my $MOD=0;

my $modline="";
my %totalFile= ();
my $MTIME = 9;

#read CVS/Entries
my $MON = 1;
my $MDAY = 2;
my $HOUR = 0;
my $MIN = 1;
my $SEC = 2;
my $YEAR = 4;

#Read filearray
my $CO = 0; #cvs edit executed?
my $AD = 1; #add delete flag
my $MU = 2; #modified/unmodified flag
my $REV =3; #revnumber
my $ETS =4; #timestamp from CVS/Entries
my $FTS = 5; #timestamp from file (using stat(file) )
my $ERROR = 6;

my $HELPFLAG = 0;
my $DOSTATS = 0;
my @DIRLIST = ();

#the total number of CVS entries we parse:
my $TOTAL_ENTRIES_LINES_PARSED = 0;
my $TOTAL_ENTRIES_FILES = 0;

#maximum length filename we found:
my $MAX_FN = 0;

&init;

#################################### MAIN #####################################

sub main
{
    local (*ARGV, *ENV) = @_;
    my(%DIRDB, @rec);

    #set global flags:
    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    my ($cwd) = &path'pwd;

    %totalFile=();
    %DIRDB = ();

    if ($cwd eq "NULL" && $#DIRLIST > 0) {
        printf STDERR ("%s: sorry, cannot process multiple dirs unless pwd function available\n", $p);
        return(1);
    } elsif ($cwd eq "NULL") {
        $cwd = $DOT;
    }

    &walkdir::save_file_info(1); 
    &walkdir::option_cvs_only(1); 

    for my $dir (@DIRLIST) {
        my $error = &walkdir::dirTree(*DIRDB, $cwd, $dir);

        if ($error != 0) {
            printf STDERR
            ("%s: WARNING:  dirTree failed with error %d while walking %s\n", $p, $error, $dir);
        }
    }

    #find all the CVS directories:  
    my @cvsEntries = grep(/\/CVS\/Entries$/, &walkdir::file_list(*DIRDB));
    $TOTAL_ENTRIES_FILES = $#cvsEntries + 1;

    #foreach CVS/Entries file...
    for my $e (@cvsEntries) {
        #... examine state of each entry:
        my $err = &entries($e);
        if ($err) {
            # print STDERR "$err-Difficulty in entries [$e]\n";
            $err = 0;
        }
    }

    &filter_output(%totalFile);
        # output information based on user preferences (newfiles etc.)
        # &output print the actual files.;
    
    dump_stats() if ($DOSTATS);

    return 0;
} # main

sub dump_stats
#print statistics about the run
{
    printf "Scanned %d CVS/Entries Meta-files\n", $TOTAL_ENTRIES_FILES;
    printf "Processed %d CVS file entires\n", $TOTAL_ENTRIES_LINES_PARSED;
}

sub entries
{
    my ($e) = @_;

    if (!open(ENT, $e)) {
        printf STDERR "%s [main]:  ERROR:  cannot open '%s' for reading .\n", $p, $e;
        return 1;
    }

    #read file into array, ignoring directory entries:
    my @entry_lines = grep($_ !~ /^D/ && chomp($_), <ENT>);
    close ENT;

    return 0 if ($#entry_lines < 0);    #entries are all directories - DONE.

    #keep track of how many entries we parse
    $TOTAL_ENTRIES_LINES_PARSED += ($#entry_lines + 1);

    my @d = split /\/CVS\//, $e;   #this excludes dirs like CVSROOT    
    my @f = split /$SRCROOT\//, $d[0];

    my $cvsdir = $e;
    $cvsdir =~ s/\/Entries$//;

#printf "cvsdir='%s'\n", $cvsdir;

#EXAMPLE: /changes.pl/1.3/Mon Mar  7 20:05:18 2005/-ko/Tesbpoc

    my ($dummy, $filename, $REVNUMBER, $etimestamp);
    my ($line);

    #filearray CO, AD, MU, REVNO, ENTRIES_TS, FILE_TS ERROR_STATUS 
    my @filearray = ();

    for $line (@entry_lines) {
        ($dummy, $filename, $REVNUMBER, $etimestamp) = split("/", $line);
        @filearray = ("0","0","0","$REVNUMBER","$etimestamp","0","0");

        # parse filename
        my $dirfile = "$d[0]/$filename";
        my $dirfileS = "";
        if ($f[1]) {
            $dirfileS = "$f[1]/$filename";
        } else {
            $dirfileS = "$f[0]/$filename";
        }

#printf "dummy='%s' filename='%s' REVNUMBER='%s' etimestamp='%s' dirfile='%s' dirfileS='%s'\n", $dummy, $filename, $REVNUMBER, $etimestamp, $dirfile, $dirfileS;

        my $parsed_revno = &parse_revnumber($REVNUMBER, $dirfile); 
        # if revno is 0 or negative, don't need to parse etimestamp.
        # add directly to array.

        if ($parsed_revno > 0) {
            my @statfile = stat($dirfile);

            if (my $time = $statfile[$MTIME]) {

                my $parsed_etimestamp = &parse_etimestamp($etimestamp, $dirfile, \@filearray);
#printf "parsed_etimestamp='%s' filearray=(%s)\n", $parsed_etimestamp, join('|', @filearray);
                if ($parsed_etimestamp > 0 ) {

                    $filearray[$ETS] = "$parsed_etimestamp";
                    $filearray[$FTS] = "$time";

                    my $diftime = $parsed_etimestamp - $time;
                    if ($'OS == $'NT ) {
                        #fudge
                        if ($diftime ne  1 && $diftime ne 0 && abs($diftime) ne 3600 ) { 
                            # Fudging for the benefit of NT which changes stattime 
                            # based upon user settings.  If the setting 
                            # 'adjust automatically for daylight savings time'is 
                            # set, on the users machine, file stat times are 
                            # retroactively adjusted by one hour.  This is a
                            # documented FEATURE of the NT operating system.  
                            # All files which were changed EXACTLY one hour from 
                            # previous modification date will be ignored.  
                            # This runs the risk of ignoring legitimately changed 
                            # files, but should eliminate 1000's of erroneous false
                            # positives.

                            $filearray[$MU]="1";
                        }
                        
                    } else {

                        #don't fudge
                        if ($diftime ne 0 ) { 
                            $filearray[$MU]="1";
                        }
                    }
                } else {
                    #this just means that estamp returned a non-integer value.
                    #CVS puts things like "Result of merge" in the timestamp field.
                }
            } else {
                if ( $VOLUME >= 0 ) {
                    printf STDERR "%s: Unable to stat file [%s].  You may need to execute cvs remove\n", $p, $dirfile;
                }
                # return(1);
            }
        } elsif ($parsed_revno == 0) {
            $filearray[$AD]="1";
        } elsif ($parsed_revno < 0) {
            #this probably means the file is deleted locally.
            $filearray[$AD]="-1";
            printf STDERR "%s: WARNING: Unable to parse revision number for '%s'. (file deleted locally?)\n", $p, $dirfile if ($VOLUME > 0);
        }

        #is this files edited?
        if ( -r "$cvsdir/Base/$filename" ) {
            $filearray[$CO] = 1;
        }

        if (&changed(\@filearray)) {
            $totalFile{$dirfileS} = [ @filearray ];
        }
    }

    return 0;
}

sub changed
#true if file represented by the file-array arg has been modified.
{
    my ($filearef) = @_;
    my (@filearray) = @{$filearef};

#printf "changed filearray=(%s)\n", join('|', @filearray);

    if ( $filearray[$REV] eq 0 || $filearray[$AD] eq 1 ) {
        return 1;    #new file
    }

    if ($filearray[$MU] > 0) {
        return 1;    #modified
    }

    if ($filearray[$REV]) {
        my @revno = split /\./, $filearray[$REV];

        if ( $revno[0] < 0)  {
            return 1;
        }
    }

    #identify pco'd files
    if ( $filearray[$CO] eq 1 ) {
        return 1;
    }

    return 0;
}

sub parse_etimestamp 
#return time in seconds since epoch.
#return 0 if new file or merge & set filearray entries appropriately.
#return -1 if error
{
    my ($stamp, $dirfile, $filearray) = @_;

#printf "parse_etimestamp INPUT='%s'\n", $stamp;

    #look for exceptional timestamps.
    if ($stamp =~ /Result of merge\+?.*/ ) {
#printf "parse_etimestamp Result of merge\n";
        ## Add to array -- files are changed as a result of merge
        ${$filearray}[$MU] = "2";  
        return 0;
    } elsif ($stamp =~ /dummy timestamp/ || $stamp =~ /Initial/) {
#printf "parse_etimestamp dummy timestamp\n";
        ## Add to array -- files are new.
        ${$filearray}[$AD]=1;
        return 0;
    } else {
        my @ets = split /\s+/, $stamp;

        my $thismon = &mon2num($ets[$MON]);
        if ( $thismon eq "NULL") {
            printf STDERR 
            ("%s: Unable to translate month-name %s in %s\n", $p,$ets[$MON],$dirfile);
            return -1;
        }

        my @hr = split /:/, $ets[3];  
        for my $h (@hr, $thismon, $ets[$MDAY], $ets[$YEAR]) {
            if ($h !~ /^\d*$/) {
                printf STDERR "%s: Non-numeric time element [$h] [%s] in %s\n",
                    $p, $ets[3], $dirfile;
                return -1;
            }

            #### $TIME = timegm($sec,$min,$hours,$mday,$mon,$year);
            $stamp = timegm ($hr[$SEC], $hr[$MIN], $hr[$HOUR], $ets[$MDAY], $thismon, $ets[$YEAR]); 
            if ($stamp !~ /^\d*$/ ) {
                printf STDERR "%s: Unable to convert Entries time to gmtime. |%s|%s|%s|%s|%s|%s| in %s\n",
                    $p, $hr[$SEC], $hr[$MIN], $hr[$HOUR], $ets[$MDAY], $thismon, $ets[$YEAR], $dirfile; 
                return -1;
            }
        }
    
    } # else -timestamp is not wierd.

#printf "parse_etimestamp='%s'\n", $stamp;  

    return $stamp;  
}

sub parse_revnumber 
{
    my ($REVNUMBER, $dirfile) = @_;

    if($REVNUMBER ne "NULL" && $REVNUMBER ne "" && $dirfile ne "" ) { 
        my @rev = split /\./, $REVNUMBER ;

        unless ( $rev[0] ne $REVNUMBER || $rev[0] == 0 ) {
            #Split returns original string if unsplitable
            printf STDERR 
           ("%s: Unable to parse REVNUMBER [%s][%s] in %s\n", $p,$REVNUMBER,$rev[0],$dirfile);
            return -1;
        }
        unless ($rev[0] =~ /^-?\d*$/) { #if is numeric, skip this
            printf STDERR 
           ("%s: Non-numeric REVNUMBER [%s] in %s\n", $p,$REVNUMBER,$dirfile);
            return -1;
        }
        return $rev[0];
    }

    print "REVNO is NULL or REVNO is empty or DIRFILE is empty\n";
    return -1;
}

sub filter_output
{
    my (%totalFile) = @_;

    my @k = sort(keys %totalFile);

    if ($#k < 0) {
        print "There are no changes for this path.\n";
        # This is the fast out.
        # in case the user has chosen specific display options
        # we will need to check one more time for nochanges.
        return(1) ;
    }
    
    my $count=0;
    my $ke ="";

    foreach $ke (@k) {
        #run through the whole list once to get the MAX filename:
        $MAX_FN=length($ke) if ( length($ke) > $MAX_FN );
    }

    foreach $ke (@k) {
        my $n = "";
        if (defined $totalFile{$ke}[$CO] && defined $totalFile{$ke}[$REV]) { 
            &output(\$count, $ke, $n);
        }
    }
    # if ($DEBUG) { print "COUNT is $count\n"; }
    if ( $count eq 0 ) { print "There are no changes for this path.\n"; }
}

sub output
#output the list of changed files, with associated verbosity level.
{
    my( $countref, $ke, $n) =  @_;

    my (@OUTPUT_LIST) = ();

    #de-reference file-info array:
    my (@file_info) = @{$totalFile{$ke}};
#printf "\noutput:  ke='%s' file_info=(%s)\n", $ke, join('|', @file_info);

    #identify new files
    if ( ( $file_info[$REV] eq 0 || $file_info[$AD] eq 1 ) && $NEW == 1 ) {
        ${$countref}++;
        if ($VOLUME >= 0) {
            push @OUTPUT_LIST, sprintf("%-${MAX_FN}s\t(NEW)", $ke);
        } else {
            push @OUTPUT_LIST, $ke;
        }
    }

    #identify deleted files
    if ($file_info[$REV]) {
        my @revno = split /\./, $file_info[$REV];

        if ( $revno[0] < 0 && $DELETED==1)  {
            $file_info[$AD] = -1;
            ${$countref}++;
            if ($VOLUME >= 0) {
                $n = "(DELETED)";
                if ($VOLUME > 0) {
                    $n = "$n\tRev $file_info[$REV]";
                }
                push @OUTPUT_LIST, sprintf("%-${MAX_FN}s\t%s", $ke, $n);
            } else {
                push @OUTPUT_LIST, $ke;
            }
        }  else { # MAGIC ELSE

            #identify pco'd files
            if ( $file_info[$CO] eq 1 && $MOD==1 && $file_info[$MU] >= 0) {
                # print "CO $file_info[$CO] eq 1 MO$MOD==1 && MU$file_info[$MU] >= 0\n";
                ${$countref}++;
                if ($VOLUME > 0) {
                    $n = "\t";
                    if ($file_info[$MU] == 1) {
                        $n = "(MODIFIED)";
                    }
                    if ($file_info[$MU] == 2) {
                        $n = "(Result of Merge)";
                    }
                    $n = "$n\tRev $file_info[$REV] (CHECKED OUT)";

                    push @OUTPUT_LIST, sprintf("%-${MAX_FN}s\t%s", $ke, $n);
                } else {
                    push @OUTPUT_LIST, $ke;
                }

                ##Coming if takes care of case where file exists in Base/ but not in Entries.
                ##this is a fix until I can figure out how this situation could occur. (ELG 2/2/01)

            } else {  #not pco'd, but has it been changed anyway?
                if ($file_info[$MU] > 0 && $MOD==1) {
                    ${$countref}++;
                    if ( $VOLUME > 0) {
                        $n = "(MODIFIED)";
                        push @OUTPUT_LIST, sprintf("%-${MAX_FN}s\t%s", $ke, $n);
                    } else {
                        push @OUTPUT_LIST, $ke;
                    }
                }
            }
        } # ELSE
    } else {
        #CVS DOES NOT CLEAN UP AFTER ITSELF. FILES which have been cvs co'd & removed will
        # show up here.
    }

    #output SORTED list, only if something was discovered:
    if ($#OUTPUT_LIST >= 0) {
        @OUTPUT_LIST = sort @OUTPUT_LIST;
        print join("\n", @OUTPUT_LIST), "\n";
    }
}

sub mon2num 
{
    my($monthnum) = @_;
    if ($monthnum =~ '^Jan') {
        $monthnum = 0;
    } elsif ($monthnum =~ '^Feb') {
        $monthnum = 1;
    } elsif ($monthnum =~ '^Mar') {
        $monthnum = 2;
    } elsif ($monthnum =~ '^Apr') {
        $monthnum = 3;
    } elsif ($monthnum =~ '^May') {
        $monthnum = 4;
    } elsif ($monthnum =~ '^Jun') {
        $monthnum = 5;
    } elsif ($monthnum =~ '^Jul') {
        $monthnum = 6;
    } elsif ($monthnum =~ '^Aug') {
        $monthnum = 7;
    } elsif ($monthnum =~ '^Sep') {
        $monthnum = 8;
    } elsif ($monthnum =~ '^Oct') {
        $monthnum = 9;
    } elsif ($monthnum =~ '^Nov') {
        $monthnum = 10;
    } elsif ($monthnum =~ '^Dec') {
        $monthnum = 11;
    } else {
        $monthnum = "NULL";  #provide a useful error message here.
    }
    return $monthnum;
}


################################ USAGE SUBROUTINES #############################

sub usage
{
my($status) = @_;

print STDERR <<"!";
Usage:  $p [-help] [-new] [-deleted] [-m] [-v] [-q] [dirs...]

Synopsis:
Tools to list all changed, added and deleted files.:
Identify New Files (will have revno=0 and timestamp="dummy timestamp")
Identify Deleted Files (will have revno<0) 
Identify Modified Files (Compare Timestamp in CVS/Entries with file timestamp)

Options:
 -help    Display this usage message
 -new     Display only new files
 -deleted Display only deleted files
 -m       Display only modified files
 -all     Display new, deleted & changed files (default) 
 -v       Verbose:  Display version info
 -q       Quiet: Do not indicate if files are new, changed, or deleted
 dirs     Search only specified directories for changes 
          (defaults to current working directory)


Environment:
\$CHANGES_PATH optional semi-colon separated path listing directories to check when calling changes.

Example:
$p  bin xml xmlview
$p

!
return($status);
}

sub parse_args
#proccess command-line aguments
{
    local (*ARGV, *ENV) = @_;

    $HELPFLAG = 0;

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
        my $flag = shift(@ARGV);

        if ($flag =~ '^-deleted') {
            $DELETED=1;
            $VOLUME=-1;
        } elsif ($flag =~ '^-n') {
            $NEW=1;
            $VOLUME=-1;
        } elsif ($flag =~ '^-m') {
            $MOD=1;
            $VOLUME=-1;
        } elsif ($flag =~ '^-a') {
            $DELETED=1;
            $NEW=1;
            $MOD=1;
        } elsif ($flag =~ '^-v') {
            $VOLUME=1;
        } elsif ($flag =~ '^-q') {
            $VOLUME=-1;
        } elsif ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return &usage(0);
        } else {
            printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
            return &usage(1);
        }
    }

    $DOSTATS = 1 if ($VOLUME >= 1);

    # Set modification specs if NONE were set
    if ($DELETED+$NEW+$MOD <= 0) {
        $DELETED=1;
        $NEW=1;
        $MOD=1;
    }

    if ($SRCROOT eq "NULL" || $SRCROOT eq "") {
        #get CVSROOT from env if it is defined:
        if (defined($ENV{'SRCROOT'})) {
            $SRCROOT = $ENV{'SRCROOT'};
        } else {
            $SRCROOT = $DOT;
        }
    }

    #eliminate empty args (this happens on some platforms):
    @ARGV = grep(!/^$/, @ARGV);

    #take remaining args as directories to process:
    if ($#ARGV < 0) {
        ## CHECK FOR CHANGES_PATH if no args
        if (defined $CHANGES_PATH) {
            ## USE CHANGES_PATH
            # print "CHANGES_PATH $CHANGES_PATH\n";
            @DIRLIST = split(/;/, $CHANGES_PATH);
            # if ($DEBUG) { for $d (@DIRLIST) { print "DD$d\n"; } }
        } else {
            @DIRLIST = $DOT;
        }
    } else {
        @DIRLIST = @ARGV;
        # if ($DEBUG) { for $d (@DIRLIST) { print "DD$d\n"; } }
    }

    return(0);
}

sub init
{
}

1;
