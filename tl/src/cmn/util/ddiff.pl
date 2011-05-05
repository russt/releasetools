package ddiff;

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
# @(#)ddiff.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# Copyright 2010-2011 Russ Tremain. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


# ddiff - compute differences between 2 directories
#

require "walkdir.pl";
require "listutil.pl";

&init;
$DEBUG= 0;

#################################### MAIN #####################################

sub main
{
    local(*ARGV, *ENV) = @_;
    local (@tmp, $dir);

    #set global flags:
    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    local($cwd) = &path'pwd;

    if ($cwd eq "NULL" && $#DIRLIST > 0) {
        printf STDERR 
        ("%s: sorry, cannot process multiple dirs unless pwd function available\n", $p);
        return(1);
    }

    %DIRDBA = ();
    $DUMMYCRC1 = -1;

    %DIRDBB = ();
    $DUMMYCRC2 = -2;

    &walkdir::option_skip_cvs(1) unless ($DO_CVS);
    &walkdir::save_file_info($FILEFLAG);

    $dir = $ARG_A;
    if ($A_TYPE eq "DIRECTORY") {
        if (!chdir($cwd)) {
            print STDERR "$p: ERROR: Failed to chdir into $cwd: $!\n";
        }
        if (!chdir($dir)) {
            print STDERR "$p: ERROR: Failed to chdir into $dir: $!\n";
            return 1;
        }
        printf STDERR "%s: saving directory info...\n", $p if ($VERBOSE);
        if (($error = &walkdir'dirTree(*DIRDBA, $DOT, $DOT)) != 0) {
            printf STDERR
            ("%s: ERROR:  dirTree failed with error %d while walking %s\n", $p, $error, $dir);
        }
    } else {
        #arg is assumed to be a file containing crc's of a previous walk:
        if (!chdir($cwd)) {
            print STDERR "$p: ERROR: Failed to chdir into $cwd: $!\n";
        }
        if ( &walkdir'parse_crcfile($ARG_A, *DIRDBA) < 1) {
            printf STDERR "%s: ERROR parsing crc file %s\n", $p, $ARG_A;
        }
    }

    $dir = $ARG_B;
    if ($B_TYPE eq "DIRECTORY") {
        if (!chdir($cwd)) {
            print STDERR "$p: ERROR: Failed to chdir into $cwd: $!\n";
        }
        if (!chdir($dir)) {
            print STDERR "$p: ERROR: Failed to chdir into $dir: $!\n";
            return 1;
        }
        if (($error = &walkdir'dirTree(*DIRDBB, $DOT, $DOT)) != 0) {
            printf STDERR
            ("%s: ERROR:  dirTree failed with error %d while walking %s\n", $p, $error, $dir);
        }
    } else {
        #arg is assumed to be a file containing crc's of a previous walk:
        if (!chdir($cwd)) {
            print STDERR "$p: ERROR: Failed to chdir into $cwd: $!\n";
        }
        if ( &walkdir'parse_crcfile($ARG_B, *DIRDBB) < 1) {
            printf STDERR "%s: ERROR parsing crc file %s\n", $p, $ARG_B;
        }
    }

    if ($CRCLOG_DIFF) {
        @setA = grep( /F$/o, (keys %DIRDBA));
        @setB = grep( /F$/o, (keys %DIRDBB));
    } else {
        @setA = (keys %DIRDBA);
        @setB = (keys %DIRDBB);
    }

    if ($DEBUG) {
        printf "*-*-* DB for $ARG_A\n";
        foreach $key (@setA) {
            print "$key is key for $DIRDBA{$key}\n\n";
        }
        printf "*-*-* DB for $ARG_B\n";
        foreach $key (@setB) {
            print "$key is key for $DIRDBB{$key}\n\n";
        }
    }

    if ($DISPLAY_ARG_A) {
        if ($SLOPPY_DIFF) {
            @tmp = &list'KEYED_MINUS(*setA, *setB, $WDK_FS, $WDK_FNAME);
            &dump_dirlist2("In $ARG_A but not in $ARG_B:", $ARG_A, "", *tmp, *tmp, 0, *DIRDBA, *DIRDBB);
        } else {
            @tmp = &list'MINUS(*setA, *setB);
            if ($TABLE_FORMAT) {
                &dump_table("LEFT", *tmp, 0, *DIRDBA, *DIRDBB);
            } else {
                &dump_dirlist("In $ARG_A but not in $ARG_B:", *tmp, 0, *DIRDBA, *DIRDBB);
            }
        }
    }

    if ($DISPLAY_ARG_B) {
        if ($SLOPPY_DIFF) {
            @tmp = &list'KEYED_MINUS(*setB, *setA, $WDK_FS, $WDK_FNAME);
            &dump_dirlist2("In $ARG_B but not in $ARG_A:", "", $ARG_B, *tmp, *tmp, 0, *DIRDBA, *DIRDBB);
        } else {
            @tmp = &list'MINUS(*setB, *setA);
            if ($TABLE_FORMAT) {
                &dump_table("RIGHT", *tmp, 0, *DIRDBA, *DIRDBB);
            } else {
                &dump_dirlist("In $ARG_B but not in $ARG_A:", *tmp, 0, *DIRDBA, *DIRDBB);
            }
        }
    }

    if ($DISPLAY_COMMON) {
        if ($SLOPPY_DIFF) {
            @tmp = &list'KEYED_AND(*setA, *setB, $WDK_FS, $WDK_FNAME);
            @keysinA = grep(defined($DIRDBA{$_}), @tmp);
            @keysinB = grep(defined($DIRDBB{$_}), @tmp);

            #if both arguments are directories, and we are not ignoring EOL diffs, then we can use binary crc calc:
            my ($isBinary) = (!$IGNORE_EOL_DIFFS && $A_TYPE eq "DIRECTORY" && $B_TYPE eq "DIRECTORY")? 1 : 0;

            if ($FDIFF_FLAG || $CRCLOG_DIFF) {
                #
                # add crc's for all common files if we are comparing content.
                # re-establish directory context so crc will work!
                #
                printf STDERR "%s: Computing crc's for common files...\n", $p if ($VERBOSE);

                if ($A_TYPE eq "DIRECTORY") {
                    $dir = $ARG_A; chdir($cwd); chdir($dir);
                    &walkdir'insert_crcs(*DIRDBA,*keysinA, $isBinary);
                }

                if ($B_TYPE eq "DIRECTORY") {
                    $dir = $ARG_B; chdir($cwd); chdir($dir);
                    &walkdir'insert_crcs(*DIRDBB,*keysinB, $isBinary);
                }
            }

            &dump_dirlist2("In both $ARG_A and $ARG_B:", $ARG_A, $ARG_B, *keysinA, *keysinB, ($FDIFF_FLAG || $CRCLOG_DIFF), *DIRDBA, *DIRDBB);
        } else {
            #standard case - no sloppy diff:

            @tmp = &list'AND(*setA, *setB);

            if ($FDIFF_FLAG || $CRCLOG_DIFF) {
                #if both arguments are directories, and we are not ignoring EOL diffs, then we can use binary crc calc:
                my ($isBinary) = (!$IGNORE_EOL_DIFFS && $A_TYPE eq "DIRECTORY" && $B_TYPE eq "DIRECTORY")? 1 : 0;

                #compute relevant crc's:
                printf STDERR "%s: Computing crc's for common files...\n", $p if ($VERBOSE);

                if ($A_TYPE eq "DIRECTORY") {
                    $dir = $ARG_A; chdir($cwd); chdir($dir);
                    &walkdir'insert_crcs(*DIRDBA, *tmp, $isBinary);
                }

                if ($B_TYPE eq "DIRECTORY") {
                    $dir = $ARG_B; chdir($cwd); chdir($dir);
                    &walkdir'insert_crcs(*DIRDBB, *tmp, $isBinary);
                }

                if ($TABLE_FORMAT) {
                    &dump_table("BOTH", *tmp, 1, *DIRDBA, *DIRDBB);
                } else {
                    &dump_dirlist("In both $ARG_A and $ARG_B:", *tmp, 1, *DIRDBA, *DIRDBB);
                }
            } else {
                #don't compare crcs:
                if ($TABLE_FORMAT) {
                    &dump_table("BOTH", *tmp, 0, *DIRDBA, *DIRDBB);
                } else {
                    &dump_dirlist("In both $ARG_A and $ARG_B:", *tmp, 0, *DIRDBA, *DIRDBB);
                }
            }
        }
    }

    return(0);
    &squawk_off;
}

sub create_output_list
#local routine to set up ouput list for sloppy diff keys.
{
    local($dirname, $dodiff, *keylist, *DIRDB) = @_;
    local($dir, $fn, $type);
    local($kk, $rec, @result, $crc);

    for $kk (@keylist) {
        #formulate output record:
        ($dir,$fn,$type) = split($;, $kk);
        next if ($type eq 'D' || $type eq 'L');

        @rec = &walkdir'unpack_wdrec($DIRDB{$kk});

        #NOTE - use sprintf here to convert to - unsigned compares don't work...
        #this may be a perl bug.  RT 10/22/98
        push @result,
            join($;, $fn, (sprintf "%d", $rec[$WD_CRC]),
            &path'ParseRelativePathName(&path'mkpathname($dirname, $dir, $fn))
        );

    }

    return @result;
}

sub dump_dirlist2
#local routine to output sloppy diff sets
{
    local($hdr, $adir, $bdir, *akeys, *bkeys, $dodiff, *DIRDBA, *DIRDBB) = @_;
    local(@list) = ();
    local($fn, $crc, $path);
    local($lcrc);

    if ($adir ne "") {
        if ($A_TYPE eq "CRC FILE") {
            @list = &create_output_list($adir . ": ", $dodiff, *akeys, *DIRDBA);
        } else {
            @list = &create_output_list($adir, $dodiff, *akeys, *DIRDBA);
        }
    }

    if ($bdir ne "") {
        if ($B_TYPE eq "CRC FILE") {
            push (@list, &create_output_list($bdir . ": ", $dodiff, *bkeys, *DIRDBB));
        } else {
            push (@list, &create_output_list($bdir, $dodiff, *bkeys, *DIRDBB));
        }
    }

    printf "### %s\n", $hdr;

    ####
    #now that we've collected the output, sort by filename
    #and mark similar crcs:
    ####

    $lcrc = -1;
    $lfn = "";
    for (sort @list) {
        ($fn, $crc, $path) = split($;, $_);

        printf "%s\t%s%-20s\t%s\n",
            ($dodiff && $VERBOSE) ? sprintf("%08X", $crc) : "",
            $dodiff == 0 ? "" : (($fn ne $lfn) ? "" : ($crc == $lcrc) ? "  =" : "  !"),
            $fn,
            $path;

        $lcrc = $crc;
        $lfn = $fn;
    }
}

sub dump_table
{
    local($hdr, *tmp, $dodiff, *DIRDBA, *DIRDBB) = @_;
    local($kk,$pn,$vv);
    local($dir,$fn,$type,$pn);
    local($crcA, $crcB);
    local($type_fld, $diff_fld);

    return if ($#tmp < 0);

    for $kk (sort @tmp) {
        ($dir,$fn,$type) = split($;, $kk);

        $diff_fld = "-1";
        $type_fld = "undef";
        $pn = "undef";

        if ($type eq 'F') {      ###### type plain file
            $pn = &path'mkpathname($dir,$fn);
            $type_fld = "F";

            if ($dodiff) {
                $crcA = $crcB = -1;
                $vv = $DIRDBA{$kk};
                if (defined($vv)) {
                    @recA = &walkdir'unpack_wdrec($vv);
                    $crcA = $recA[$WD_CRC];
                }
                $vv = $DIRDBB{$kk};
                if (defined($vv)) {
                    @recB = &walkdir'unpack_wdrec($vv);
                    $crcB = $recB[$WD_CRC];
                }
#$pn = sprintf("%s %08X %08X", $pn, $crcA, $crcB);
                if ($DISPLAYALLCRCS && $crcA != $crcB) {
                    $diff_fld = "1";
                } else {
                    $diff_fld = "0";
                }
            }
        } elsif ($type eq 'D') {  ###### type DIR
            $pn = $dir;
            $type_fld = "D";
        } else {
            $pn = &path'mkpathname($dir,$fn);
            $type_fld = "L";
        }

        #### output the table entry:
        #### (where_seen, type, pathname, isdifferent)

        printf "%s\t%s\t%s\t%s\n", $hdr, $type_fld, $pn, $diff_fld;
    }
}

sub dump_dirlist
#local routine to output normal diff sets
{
    local($hdr, *tmp, $dodiff, *DIRDBA, *DIRDBB) = @_;
    local($kk,$pn,$vv,$cnt);
    local($dir,$fn,$type,$pn);
    local($crcA, $crcB);
    $cnt= 0;

    printf "### %s\n", $hdr;

    if ($#tmp < 0) {
        print "\tNULL\n";
        return;
    }

    my $displayCnt = 0;
    for $kk (sort @tmp) {
        ($dir,$fn,$type) = split($;, $kk);
        next unless ($DIRFLAG && $type eq 'D' || $FILEFLAG && $type eq 'F');

        if ($type eq 'F') {
            $pn = &path'mkpathname($dir,$fn);
            if ($dodiff) {
                $crcA = $crcB = -1;
                $vv = $DIRDBA{$kk};
                if (defined($vv)) {
                    @recA = &walkdir'unpack_wdrec($vv);
                    $crcA = $recA[$WD_CRC];
                }
                $vv = $DIRDBB{$kk};
                if (defined($vv)) {
                    @recB = &walkdir'unpack_wdrec($vv);
                    $crcB = $recB[$WD_CRC];
                }
#$pn = sprintf("%s %08X %08X", $pn, $crcA, $crcB);
                if ($DISPLAYALLCRCS && $crcA != $crcB) {
                    $pn =  $pn . '*';
                }
            }
        } elsif ($type eq 'D') {
            $pn = $dir;
        } else {
            $pn = &path'mkpathname($dir,$fn) . "@";
        }

        if ( $DISPLAYALLCRCS ) {
            printf "\t%s\n", $pn;
	    ++$displayCnt;
        } elsif ( $crcA != $crcB ) {
            printf "\t%s\n", $pn;
	    ++$displayCnt;
        }
    }

    print "\tNULL\n" unless ($displayCnt > 0);
}

sub option_displaycrcdiffsonly
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $DISPLAYALLCRCS= $bool? 0: 1;
    } else {
        printf STDERR "%s:  ERROR: option_crc requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub iscrcfile
#returns 1 if success else 0
{
    local($filename)= @_;

    if ( !(-d $filename) && (-e $filename)) {
        if (open(TEST_CRC, $filename) > 0) {
            $line= <TEST_CRC>;
            chomp($line);
            return 1 if ($line=~ /CRC=/i);
        }
    }
    return 0;
}

sub init
#copies of global vars from main package:
{
    $p = $'p;       #$main'p is the program name set by the skeleton
    $OS = $'OS;
    $UNIX = $'UNIX;
    $MACINTOSH = $'MACINTOSH;
    $NT = $'NT;
    $DOT = $'DOT;

    #record defs for dirTree DB:
    $WD_NF = $walkdir'WD_NF;
    $WD_LINKTO = $walkdir'WD_LINKTO;
    $WD_CRC = $walkdir'WD_CRC;
    $WD_DEV = $walkdir'WD_DEV;
    $WD_INO = $walkdir'WD_INO;
    $WD_MODE = $walkdir'WD_MODE;
    $WD_NLINK = $walkdir'WD_NLINK;
    $WD_UID = $walkdir'WD_UID;
    $WD_GID = $walkdir'WD_GID;
    $WD_RDEV = $walkdir'WD_RDEV;
    $WD_SIZE = $walkdir'WD_SIZE;
    $WD_ATIME = $walkdir'WD_ATIME;
    $WD_MTIME = $walkdir'WD_MTIME;
    $WD_CTIME = $walkdir'WD_CTIME;
    $WD_BLKSIZE = $walkdir'WD_BLKSIZE;
    $WD_BLOCKS = $walkdir'WD_BLOCKS;

    #Key defs:
    $WDK_FS = $walkdir'WDK_FS;
    $WDK_DNAME = $walkdir'WDK_DNAME;
    $WDK_FNAME = $walkdir'WDK_FNAME;
    $WDK_TYPE  = $walkdir'WDK_TYPE;

    $DISPLAYALLCRCS= 1;
}

################################ USAGE SUBROUTINES ###############################

sub squawk_off
#shut up extraneous warnings from perl -w option:
{
    if (1 > 2) {
    }
}

sub usage
{
    local($status) = @_;

    print STDERR <<"!";
Usage:    $p [-h] [-v] [-csl] [-fdiff] [-common] [-sloppy] <dirA | crcfileA> <dirB | crcfileB>

Options:
 -h        display this usage message.
 -v        verbose mode - display informational messages on stderr.
           displays crc values for common files when -sloppy selected.
 -f        display file entries only.
 -d        display directory entries only.
 -ieol     ignore platform end-of-line differences when comparing files.
           NOTE:  this option precludes optimizations used to calculate file crcs.
 -noscm    skip RCS, CVS, SCCS, SUBVERSION, and GIT meta-directories.
 -nocvs    alias for -noscm
 -norcs    alias for -noscm
 -nosccs   alias for -noscm
 -nosvn    alias for -noscm
 -nogit    alias for -noscm
 -exclude pat
           exclude files or directories matching pattern, which is a perl RE.
 -csl      parse crc log file and compare list against dir. display
           unique files to log, unique files to dir and mark files
           that are different in common list with a '*'.
 -fdiff    mark files that are different in common list with a '*'.
 -common   only display files in common.
 -left     display files present in first dir but not in second.
 -right    display files present in second dir but not in first.
 -table    display files in tabular format:
             (where_seen, type, pathname, isdifferent)
           where:
              where_seen is one of:  {LEFT, RIGHT, BOTH}
              type is one:  {D, F, L}, where D=dir, F=plain file, & L=symlink
              filename is the name of the file or dir, relative to the arg. dir
              isdifferent is one of: {1, 0, -1}  (1=different, 0=same, -1 = undef)

          note that -table is modified by {-left, -right, and -comm}
          args to display only the asked for results.

-sloppy   ignore directory names in compares.

Examples:

Form 1 (include directory names in compares):

    $p -fdiff a b

    $p -csl checksum.log dir

    $p -fdiff tst/{a,b}
    ### In tst/a but not in tst/b:
            ./x3
    ### In tst/b but not in tst/a:
            ./x4
    ### In both tst/a and tst/b:
            .
            ./x1*
            ./x2
            ./c
            ./c/x2*

In this form, the command shows all exact matches
between the two directory structures.  Common
pathnames that have different contents are marked
with '*', if -fdiff is selected.

Note that in this form, directory names are
significant and are included in the output.

Form 2 (ignore directory names in compares):

    $p -v -sloppy -fdiff -common a b

    ### In both a and b:
    8AD5E083    x2                      a/x2
    8AD5E083      =x2                   b/x2
    EBE0F56A      !x2                   a/c/x2
    79A6468B      !x2                   b/c/x2


In this form, the first column is the computed crc of each file.
The second column is the file name only.  An equals sign (=)
indicates that the file contents match the previous
instance.  An exclamation mark (!) indicates that the file
contents do not match.  All files are sorted by the crc
value.

Note that crc's are not displayed unless the verbose (-v)
option is selected.

!
    return($status);
}

sub parse_args
#proccess command-line aguments
{
    local(*ARGV, *ENV) = @_;

    #default option settings:
    $HELPFLAG = 0;
    $VERBOSE = 0;
    $FDIFF_FLAG = 0;
    $DISPLAY_COMMON = -1;
    $DISPLAY_ARG_A = -1;
    $DISPLAY_ARG_B = -1;
    $SLOPPY_DIFF = 0;
    $CRCLOG_DIFF= 0;
    $TABLE_FORMAT = 0;
    $FILEFLAG = 0;
    $DIRFLAG = 0;
    $DO_CVS = 1;
    #true if we are ignoring EOL differences (i.e. compare DOS to unix) conventions:
    $IGNORE_EOL_DIFFS = 0;

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
        $flag = shift(@ARGV);

        if ($flag eq "-f") {
            $FILEFLAG = 1;
        } elsif ($flag eq "-d") {
            $DIRFLAG = 1;
        } elsif ($flag eq "-ieol") {
            $IGNORE_EOL_DIFFS = 1;
            printf STDERR "OPTION '-ieol' selected\n" if ($VERBOSE);
        } elsif ($flag eq "-v") {
            $VERBOSE = 1;
            printf STDERR "OPTION '-verbose' selected\n" if ($VERBOSE);
        } elsif ($flag eq '-noscm' || $flag eq '-nocvs' || $flag eq '-nogit' ||
                 $flag eq '-norcs' || $flag eq '-nosccs' || $flag eq '-nosvn') {
            $DO_CVS = 0;
            printf STDERR "OPTION '-nocvs' selected\n" if ($VERBOSE);
        } elsif ($flag =~ /^-ex(clude)?/ ) {
            return &usage(1) if (!@ARGV);
            return &usage(1) if (!&walkdir::option_exclude(shift(@ARGV)));
            printf STDERR "OPTION -exclude selected with pattern /%s/\n", $walkdir::EXCLUDE_PATTERN if ($VERBOSE);
        } elsif ($flag eq '-csl') {
            $CRCLOG_DIFF= 1;
            printf STDERR "OPTION '-csl' selected\n" if ($VERBOSE);
        } elsif ($flag eq '-common') {
            $DISPLAY_COMMON = 1;
            #set -left & -right if they haven't been specified:
            $DISPLAY_ARG_A = 0 if ($DISPLAY_ARG_A < 0);
            $DISPLAY_ARG_B = 0 if ($DISPLAY_ARG_B < 0);
            printf STDERR "OPTION '-common' selected\n" if ($VERBOSE);
        } elsif ($flag eq '-left') {
            $DISPLAY_ARG_A = 1;
            $DISPLAY_ARG_B = 0 if ($DISPLAY_ARG_B < 0);
            $DISPLAY_COMMON = 0 if ($DISPLAY_COMMON < 0);
        } elsif ($flag eq '-right') {
            $DISPLAY_ARG_B = 1;
            $DISPLAY_ARG_A = 0 if ($DISPLAY_ARG_A < 0);
            $DISPLAY_COMMON = 0 if ($DISPLAY_COMMON < 0);
        } elsif ($flag eq '-table') {
            $TABLE_FORMAT = 1;
        } elsif ($flag =~ '^-s') {
            $SLOPPY_DIFF = 1;
            printf STDERR "OPTION '-sloppy' selected\n" if ($VERBOSE);
        } elsif ($flag eq '-fdiff') {
            $FDIFF_FLAG = 1;
            printf STDERR "OPTION '-fdiff' selected\n" if ($VERBOSE);
        } elsif ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return &usage(0);
        } else {
            return &usage(1);
        }
    }

    #take remaining args as platforms:
    if ($#ARGV < 1) {
        return &usage(1);
    }

    $ARG_A = shift @ARGV;
    $ARG_B = shift @ARGV;

    #set -d & -f option if none specified
    if (!$DIRFLAG && !$FILEFLAG) {
        $DIRFLAG = $FILEFLAG = 1;
    }

    #set -left, -right, -comm defaults if none were specified:
    if ($DISPLAY_COMMON == -1 && $DISPLAY_ARG_A == -1 && $DISPLAY_ARG_B == -1) {
        #then none are set - use defaults:
        $DISPLAY_COMMON = 1;
        $DISPLAY_ARG_A = 1;
        $DISPLAY_ARG_B = 1;
    }

    if (&iscrcfile($ARG_A)) {
        $A_TYPE= "CRC FILE";
        if (!$CRCLOG_DIFF) {
            $CRCLOG_DIFF= 1; 
            print STDERR "Assuming -csl option...\n";
        }
    } else {
        $A_TYPE= "DIRECTORY";
    }   

    if (&iscrcfile($ARG_B)) {
        $B_TYPE= "CRC FILE";
        if (!$CRCLOG_DIFF) {
            $CRCLOG_DIFF= 1; 
            print STDERR "Assuming -csl option...\n";
        }
    } else {
        $B_TYPE= "DIRECTORY";
    }   

    printf STDERR "%s A is '%s'\n",$A_TYPE, $ARG_A if ($VERBOSE);
    printf STDERR "%s B is '%s'\n",$B_TYPE, $ARG_B if ($VERBOSE);

#printf "DISPLAY_ARG_A=%d DISPLAY_ARG_A=%d DISPLAY_COMMON=%d FDIFF_FLAG=%d SLOPPY_DIFF=%d\n", $DISPLAY_ARG_A, $DISPLAY_ARG_A, $DISPLAY_COMMON, $FDIFF_FLAG, $SLOPPY_DIFF;
    return(0);
}

1;
