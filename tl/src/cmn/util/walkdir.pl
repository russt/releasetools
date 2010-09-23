package walkdir;

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
# @(#)walkdir.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# Copyright 2009-2010 Russ Tremain. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


# walkdir - walk a directory hierarchy and print pathnames of directories only
#

require "path.pl";
require "pcrc.pl";
require "os.pl";

&init;

#################################### MAIN #####################################

sub main
{
    local(*ARGV, *ENV) = @_;
    local($dir,$fn,$type,$modestr,$crcstr,$textmode,$linkto,$linecnt);
    local(%DIRDB, @rec);

    #set global flags:
    return (1) if (&parse_args(*ARGV, *ENV) != 0);
    return (0) if ($HELPFLAG);

    local($cwd) = &path'pwd;

    if ($cwd eq "NULL" && $#DIRLIST > 0) {
        printf STDERR 
        ("%s: sorry, cannot process multiple dirs unless pwd function available\n", $p);
        return(1);
    } elsif ($cwd eq "NULL") {
        $cwd = $DOT;
    }

    %DIRDB = ();
    for $dir (@DIRLIST) {
        if (($error = &walkdir'dirTree(*DIRDB, $cwd, $dir)) != 0) {
            printf STDERR
            ("%s: WARNING:  dirTree failed with error %d while walking %s\n", $p, $error, $dir);
        }
    }

#printf "slice=%d treedepth=%d maxdepth=%d\n", $SHOWSLICE, $TREEDEPTH, $MAXDEPTH;

    if ($SHOWSLICE && $MAXDEPTH > $TREEDEPTH) {
        printf STDERR "%s:  WARNING:  no nodes at -slice -l %d, max tree depth is %d\n",
            $p, $MAXDEPTH, $TREEDEPTH;
        return 0;
    }

    return 0 if ($QQUIET);  #don't display tree.

    #Dir hierarchy is now in memory - dump it out:
    $modestr = $crcstr = $linkto = $textmode = "";
    local($showunits) = 1;
    for $kk (sort keys %DIRDB) {
        @rec = &unpack_wdkrec($kk);
        ($dir,$fn,$type) = ($rec[$WDK_DNAME], $rec[$WDK_FNAME], $rec[$WDK_TYPE]);

        @rec = &unpack_wdrec($DIRDB{$kk});

        next if ($SHOWSLICE && $rec[$WD_DEPTH] != $MAXDEPTH);
#printf "slice=%d depth=%d maxdepth=%d\n", $SHOWSLICE, $rec[$WD_DEPTH], $MAXDEPTH;

        #process options that impact display of files & dirs:
        if ($type eq 'D') {
            #if -leaf option, operate only on directories at lowest level of tree:
            next if ($LEAFONLY && $rec[$WD_NSUBDIRS] > 0); 

            #if -e option, display only empty directories. i.e., next if not empty:
            next if ($EMPTYDIR_FLAG && ($rec[$WD_NFILES] > 0 || $rec[$WD_NSUBDIRS] > 0) ); 

            #if -ne option, display only directories that contain at least one file:
            next if ($NONEMPTYDIR_FLAG && $rec[$WD_NFILES] == 0); 
        }

        $crcstr = sprintf("%08X ", $rec[$WD_CRC]) if ($DOCRC);
        $modestr = sprintf("%04o ", $rec[$WD_MODE] & 0x0fff) if ($DOMODES);

        $linecnt = "";
        $linecnt = sprintf("%8d ", -1) if ($COUNT_LINES);

#printf "TEXT_FILEFLAG=%d SAVE_TEXTMODE=%d SHOWTEXT=%d rec[WD_ISTEXT]=%d\n", $TEXT_FILEFLAG, $SAVE_TEXTMODE, $SHOWTEXT, $rec[$WD_ISTEXT];

        if ($DIRFLAG && $type eq 'D') {
            $textmode = "DIR " if ($SHOWTEXT);
            printf("%s%s%s%s%s%s\n",
                &du_str($rec[$WD_DIRTOTAL], $showunits),
                $textmode,
                $crcstr,
                $modestr,
                $linecnt,
                &quoteit($dir),
                );
            $showunits = 0 if ($showunits);     #display units on first line only
        } 
        
        if ($FILEFLAG && $type eq 'F') {
            ($textmode = (($rec[$WD_ISTEXT])?"TXT ":"BIN ")) if ($SHOWTEXT);

            next if ($TEXT_FILEFLAG && !$rec[$WD_ISTEXT]);  #don't show if -ftxt and not a text file.
            $linecnt = sprintf("%8d ", $rec[$WD_LINECNT]) if ($COUNT_LINES);

            printf("%s%s%s%s%s%s\n",
                &du_str($rec[$WD_SIZE], $showunits),
                $textmode,
                $crcstr,
                $modestr,
                $linecnt,
                &quoteit(&path'mkpathname($dir, $fn)),
                );
            $showunits = 0 if ($showunits);     #display units on first line only
        }

        if ($SYMLINKFLAG && $type eq 'L') {
            $textmode = "SYM " if ($SHOWTEXT);
            $linkto = $rec[$WD_LINKTO];
            printf("%s%s%s%s%s -> %s\n",
                &du_str($rec[$WD_SIZE], $showunits),
                $textmode,
                $crcstr,
                $modestr,
                &quoteit(&path'mkpathname($dir, $fn)),
                $linkto
                );
            $showunits = 0 if ($showunits);     #display units on first line only
        } 

    }

    return(0);
    &squawk_off;
}

sub quoteit
#add quotes if user specified -quote or -dquote
{
    my ($str) = @_;

    return $str unless ($SQUOTE || $DQUOTE);


    if ($DQUOTE_FIRST) {
        $str =  '"' . $str . '"'  if ($DQUOTE);
        $str =  "'" . $str . "'"  if ($SQUOTE);
    } else {
        $str =  "'" . $str . "'"  if ($SQUOTE);
        $str =  '"' . $str . '"'  if ($DQUOTE);
    }

    return $str;
}

sub du_str
#return a string with size in bytes, kilobytes, or megabytes
{
    local ($size, $showunits) = @_;

    return ("") if (!$DISKUSAGE);

    if ($DU_FORMAT == $DU_BYTES) {
        return ("$size\t");
    } elsif ($DU_FORMAT == $DU_KBYTES) {
        return (sprintf "%.1f%s\t", $size / 1024, $showunits? "k" : "");
    } elsif ($DU_FORMAT == $DU_MBYTES) {
        return (sprintf "%.2f%s\t", $size / 1048576, $showunits? "m" : "");
    } elsif ($DU_FORMAT == $DU_GBYTES) {
        return (sprintf "%.3f%s\t", $size / 1073741824, $showunits? "g" : "");
    }

    return ("<ERROR> ");
}

sub wdrec2str
{
    local(*rec) = @_;
    local(@strrec) = ();

    local($cnt) = -1;
    for (@rec) {
        ++$cnt;
        if ($cnt < $WD_CRC) {
            push(@strrec, $_);
        } else {
            push(@strrec, sprintf("%d", $_));
        }
    }

    return(@strrec);
}

########################### OPTION SETTING ROUTINES ############################

sub save_file_info
#if arg specified, then set option, else return option.
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $SAVE_FILE_INFO = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_crc requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_maxdepth
#returns true if okay, false if error
{
    local ($val) = @_;
    if (defined($val) && $val >= 0) {
        $MAXDEPTH = $val;
    } else {
        printf STDERR "%s:  ERROR: option_maxdepth requires positive value.\n", $p;
        return(0);
    }
    return(1);
}

sub option_leaf
#returns true if okay, false if error
{
    local ($val) = @_;
    if (defined($val) && $val >= 0) {
        $LEAFONLY = $val;
    } else {
        printf STDERR "%s:  ERROR: option_leaf requires positive value.\n", $p;
        return(0);
    }
    return(1);
}

sub option_diskusage
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $DISKUSAGE = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_crc requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_text
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $SAVE_TEXTMODE = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_text requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_countlines
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $COUNT_LINES = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_countlines requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_crc
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $DOCRC = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_crc requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_modes
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $DOMODES = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_modes requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_cvs_only
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $CVSONLY = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_cvs_only requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_sccs_only
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $SCCSONLY = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_sccs_only requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_skip_cvs
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $SKIPCVS = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_skip_cvs requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_unjar
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $DO_UNJAR = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_unjar requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_untar
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $DO_UNTAR = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_untar requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_ci
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $CREATE_RCSFILE = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_ci requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_slice
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $SHOWSLICE = $bool;
    } else {
        printf STDERR "%s:  ERROR: option_slice requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_squote
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $SQUOTE = $bool;
        $DQUOTE_FIRST = ($DQUOTE ? 1 : 0);
    } else {
        printf STDERR "%s:  ERROR: option_squote requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

sub option_dquote
#returns true if okay, false if error
{
    local ($bool) = @_;
    if (defined($bool) && $bool >= 0) {
        $DQUOTE = $bool;
        $DQUOTE_FIRST = ($SQUOTE ? 0 : 1);
    } else {
        printf STDERR "%s:  ERROR: option_dquote requires boolean value (0=false, 1=true).\n", $p;
        return(0);
    }
    return(1);
}

############################## CREATION ROUTINES ###############################

sub dirTree
#return non-zero if error
{
    local(*DIRDB, $cwd, $dir) = @_;
    local ($error) = 0;
    my ($DirTotal) = 0;

    if (chdir $dir) {
        $error = &dowalk($dir, 0, \$DirTotal, $dir eq "CVS", $dir eq "sccs" || $dir eq "SCCS");
    } else {
        printf STDERR "%s:  WARNING: cannot enter %s\n", $p, $dir;
    }

    chdir($cwd);
    return($error);
}

sub dowalk
#recursively cache directory & file info in <DIRDB> starting at <cwd>.
#we assume we are in $cwd.
#stop descent if errors
{
    local ($cwd, $level, *dirtotal, $incvs, $insccs) = @_;
    local (@lsout);
    local($ff, $nerrs) = ("",0);
    local($type, $crc, $linkto, @rec, $tmp);
    my $subtotal = 0;
    my $nfiles = 0;
    my $nsubdirs = 0;
    my $dontrecurse = 0;
    my $saverec = 1;        #optimization - don't save if -du and > max depth

#if (!defined($dirtotal)) {
#printf "dirtotal undefined - cwd='%s' level=%d\n", $cwd, $level;
#} else {
#printf "dirtotal IN =%s cwd='%s'\n", "$dirtotal", $cwd;
#}

    $TREEDEPTH = $level if ($level > $TREEDEPTH);

    if ($DISKUSAGE) {
        #calculate, but don't save info if below depth:
        $saverec = ($level <= $MAXDEPTH);

        #have to calculate full tree if -du option given:
        $dontrecurse = ($level+1 > $RIDICULOUSDEPTH);
    } else {
        $dontrecurse = ($level+1 > $MAXDEPTH);
    }

#printf "saverec=%d dontrecurse=%d SAVE_FILE_INFO=%d\n", $saverec, $dontrecurse, $SAVE_FILE_INFO;

    &path'ls(*lsout, $DOT);

    #now walk sub-directories:
    for $ff (@lsout) {
        $islink = -l $ff;
        if (!$islink && -d _ ) {
            next if ($dontrecurse); #don't call recursively - would be beyond max depth
            next if ($ff eq ".snapshot");   #don't go there - network appliance backup dirs.

            my ($iamcvs) = ($ff eq "CVS");
            my ($iamsccs) = ($ff eq "sccs" || $ff eq "SCCS");

#printf "dir=%s E=%d incvs=%d iamcvs=%d insccs=%d iamsccs=%d\n", &path'mkpathname($cwd, $ff), ($CVSONLY && !($iamcvs || $incvs || (-d "$ff/CVS"))), $incvs, $iamcvs, $insccs, $iamsccs, $ff;

            next if ( $CVSONLY && !( $iamcvs || $incvs || (-d "$ff/CVS") ) );
            next if ( $SCCSONLY && !( $iamsccs || $insccs || (-d "$ff/sccs") || (-d "$ff/SCCS") ) );
            next if ($SKIPCVS && ($iamcvs || $ff eq "RCS" || $iamsccs || $ff eq ".svn" || $ff eq ".git") );

            $nfiles = 0;    # count number of files just in this dir.
            ++$nsubdirs;    # count number of subdirs.
            if (chdir $ff) {
                #RECURSIVE CALL:
                $tmp = &path'mkpathname($cwd, $ff);
                $subtotal = 0;
                $nerrs += &dowalk($tmp, $level+1, \$subtotal, ($incvs || $iamcvs), ($insccs || $iamsccs));
                $dirtotal += $subtotal;
#printf "subdir=%s subdirtotal=%d\n", $tmp, $subtotal;
                chdir "$DOT$DOT";
            } else {
                printf STDERR ("%s:  WARNING: can't cd to '%s'\n", $p, &path'mkpathname($cwd, $ff));
                ++$nerrs;
            }
        } elsif ($islink) {
            $type = 'L';
            $crc = 0;
            $linkto = "";
            ++$nfiles;

            #stat the link, not what it points to:
            @rec = lstat(_);

            $crc = &pcrc'CalculateFileCRC($ff) if ($DOCRC);
            $linkto = readlink($ff);

            $dirtotal += $rec[$STAT_SIZE];

#printf "ff='%s' crc=%d dirtotal=%d SIZE=%d\n", $ff, $crc, $dirtotal,$rec[$STAT_SIZE];
#printf "stat=(%s)\n", join(',',@rec);

            $DIRDB{$cwd,$ff,'L'} = join($WD_FS, $linkto, "$crc", "0", @rec, "0");
        } elsif ( (!$CVSONLY && !$SCCSONLY) || ($CVSONLY && $incvs) || ($SCCSONLY && $insccs) ) {
#printf "ff='%s' CVSONLY=%d incvs=%d !E=%d\n", $ff, $CVSONLY, $incvs, !($CVSONLY && $incvs);
            $type = 'F';
            $crc = 0;
            $linkto = "";
            ++$nfiles;

            @rec = stat(_);
            $dirtotal = $dirtotal + $rec[$STAT_SIZE];

            $crc = &pcrc'CalculateFileCRC($ff) if ($DOCRC);

            my $linecnt = -1;
            my $istextfile = 0;

            #WARNING:  -T operator is expensive, especially for MKS/NT,
            #so avoid it unless needed.  RT 10/18/02
            $istextfile = 1 if ( ($SAVE_TEXTMODE || $COUNT_LINES) && (-T $ff) );

            if ($COUNT_LINES && $istextfile) {
                if (open(WCFILE, $ff) > 0) {
                    my(@wcout) = <WCFILE>;
                    $linecnt = $#wcout + 1;
                    close WCFILE;
                }
            }


#printf "ff='%s' crc='%s' dirtotal=%d SIZE=%d linecnt='%s'\n", $ff, "$crc", $dirtotal, $rec[$STAT_SIZE], $linecnt;
#printf "stat=(%s)\n", join(',',@rec);

            if ($SAVE_FILE_INFO && $saverec) {
                $DIRDB{$cwd,$ff,'F'} =
                    join($WD_FS, $linkto, "$crc", "$level", @rec, "$istextfile", "$linecnt");
            }

            if ($DO_UNTAR && $ff =~ /\.(tar|tgz|tar\.gz)$/) {
                &untar($ff, $cwd);
            }

            if ($DO_UNJAR && $ff =~ /\.(jar|zip|war)$/) {
                &unjar($ff, $cwd);
            }

            if ($CREATE_RCSFILE && $ff !~ /,v$/ && ! -f "$ff,v") {
                #checking $ff to $ff,v and do not leave $ff:
                &cvs_checkin($ff, $ff . ",v", 0);
            }
        } else {
            # -cvsonly and not in a cvs dir
            # -sccsonly and not in a sccs dir
        }
    }

    ###
    #add current directory to db.  note that we cannot stat a dir,
    #so the stat fields are missing from these records.
    ###
#printf "cwd='%s' dirtotal OUT =%d\n", $cwd, $dirtotal;
    $DIRDB{$cwd,"",'D'} = join($WD_FS, "", "0", "$level", "$nfiles", "$dirtotal", "$nsubdirs") if ($saverec);

    return($nerrs);
}

sub untar
#untar the file in the current working dir as root name of tar file
#also handles gzipped tars with .tar.gz or .tgz suffixes
{
    my ($fn, $cwd) = @_;
    #get root name of jar:

    my ($tardir, $tarsuffix) = ("", "");
    if ( $fn =~ /^(.+)\.(tar|tgz|tar\.gz)$/i ) {
        $tardir = $1;
        $tarsuffix = $2;
    }

    if (-d $tardir) {
        printf STDERR "%s: untar: dir '%s' already exists in %s - cannot untar '%s'.\n", $p, $tardir, $cwd, $ff
            unless($QUIET);
        return 0;
    }


    printf STDERR "%s:  untar %s -> %s in %s\n", $p, $ff, $tardir, $cwd
            unless($QUIET);

    my $taropts = "xf";
    $taropts .= "z" if ($tarsuffix =~ /gz/i);

    $taropts .= "v" if ($VERBOSE);

    my $cmd = sprintf("sh -c \"mkdir '%s'; cd %s; tar %s ../'%s'\"", $tardir, $tardir, $taropts, $ff);

#printf "untar(%s), cwd=%s tardir='%s' tarsuffix='%s' cmd=%s\n", $ff, $cwd, $tardir, $tarsuffix, $cmd;

    system($cmd);
    return $!;
}

sub unjar
#unjar the file in the current working dir as root name of jar/zip file
{
    my ($fn, $cwd) = @_;
    #get root name of jar:

    my $jardir = $fn;
    $jardir =~ s/\.(jar|zip|war)$//;

    if (-d $jardir) {
        printf STDERR "%s: unjar: dir '%s' already exists in %s - cannot unjar '%s'.\n", $p, $jardir, $cwd, $ff
            unless($QUIET);
        return 0;
    }


    printf STDERR "%s:  unjar %s -> %s in %s\n", $p, $ff, $jardir, $cwd
            unless($QUIET);

    my $jaropts = "xf";
    $jaropts = "xvf" if ($VERBOSE);

    my $cmd = sprintf("sh -c \"mkdir '%s'; cd %s; jar %s ../'%s'\"", $jardir, $jardir, $jaropts, $ff);

#printf "unjar(%s), cwd=%s cmd=%s\n", $ff, $cwd, $cmd;

    system($cmd);
    return $!;
}

sub cvs_checkin
# deposit a revision in the named rcs file. initialize the rcs
# file if it doesn't exist.
#
# returns non-zero and removes rcs file if errors.
# note that this is only used for distrubutions, so the ,v file is
# not precious.
#NOTE:  this code was taken from minstall.pl to implement -ci options.  RT 12/21/05
{
    my ($dstFile, $cvsdstFile, $leave_cleartxt) = @_;
    my ($kwarg) = "-ko";    #cvs default for text files

    if (!defined($dstFile) || !defined($cvsdstFile) || !defined($leave_cleartxt) ) {
        printf "Usage: %s[cvs_checkin](file, cvs_archive, leave_cleartext {1=yes, 0=no})\n", $p;
        return 1;
    }

    my ($cioptions) = "";
    $cioptions = "-u" if ($leave_cleartxt);

    $kwarg = "-kb" if (-B $dstFile);

    #initialize the ,v if it doesn't exist:
    if (!(-e $cvsdstFile)) {
        $cmd = "rcs -q -i -L -t-$p $kwarg $cvsdstFile";
        if (&os'run_cmd($cmd, $VERBOSE)) {
            print "\nBUILD_ERROR: $p: error creating rcs file, $cvsdstFile\n";
            unlink($cvsdstFile);
            return 1;
        }
    }

    #lock the file in preparation to checkin:
    $cmd = "rcs -q -l $cvsdstFile";
    if (&os'run_cmd($cmd, $VERBOSE)) {
        print "\nBUILD_ERROR: $p: error locking rcs file, $cvsdstFile\n";
        unlink($cvsdstFile);    #might work next time...
        return 1;
    }

    #TODO:  beef up log message.
    #check it in:
    $cmd = "ci -f -q $cioptions -m$p $dstFile $cvsdstFile";
    if (&os'run_cmd($cmd, $VERBOSE)) {
        print "\nBUILD_ERROR: $p: error checking in rcs file, $cvsdstFile\n";
        unlink($cvsdstFile);    #might work next time...
        return 1;
    }

    printf STDERR "%s:  %s -> %s\n", $p, $dstFile, $cvsdstFile unless($QUIET);

    return 0;
}

################################ ACCESS ROUTINES ###############################

sub pack_wdrec
#pack a wdrec DATA record into a string.
{
    return (join($WD_FS, @_));
}

sub unpack_wdrec
#return a list of the walkdir DATA elements
{
    local ($rectxt) = @_;

    return (split($WD_FS, $rectxt));
}

sub wdrec_file
    # given a file and a DIRDB, what's it wdrec
{
    local(*DIRDB, $file) = @_;

    return $DIRDB{&path'head($file),&path'tail($file),"F"};
}

sub pack_wdkrec
#pack a WD KEY list into a string.
{
    return (join($WDK_FS, @_));
}

sub unpack_wdkrec
#unpack a WD KEY string into a list.
{
    local ($rectxt) = @_;

    return (split($WDK_FS, $rectxt));
}


sub link_hash
{
    local(*DIRDB) = @_;
    my(%linkHash) = ();
    my($kk, @rec, $dir, $fn, $file, $type);
    
    for $kk (sort keys %DIRDB) {

        @rec = &unpack_wdkrec($kk);
        ($dir,$fn,$type) = ($rec[$WDK_DNAME], $rec[$WDK_FNAME], $rec[$WDK_TYPE]);
        if ($type eq "L") {
            $file = &path'mkpathname($dir, $fn);
            @rec = &unpack_wdrec($DIRDB{$kk});
            $linkHash{$file}= $rec[$WD_LINKTO];
        }
    }
    return %linkHash;
}

sub text_file_list
{
    local(*DIRDB) = @_;
    my(@fileList) = ();
    my($kk, @rec, $dir, $fn, $type);
    
    for $kk (sort keys %DIRDB) {
        @rec = &unpack_wdkrec($kk);
        ($dir,$fn,$type) = ($rec[$WDK_DNAME], $rec[$WDK_FNAME], $rec[$WDK_TYPE]);
        if ($type eq "F") {
            @rec = &unpack_wdrec($DIRDB{$kk});
            push(@fileList, &path'mkpathname($dir, $fn)) if ($rec[$WD_ISTEXT]);
        }
    }
    return @fileList;
}

sub bin_file_list
{
    local(*DIRDB) = @_;
    my(@fileList) = ();
    my($kk, @rec, $dir, $fn, $type);
    
    for $kk (sort keys %DIRDB) {
        @rec = &unpack_wdkrec($kk);
        ($dir,$fn,$type) = ($rec[$WDK_DNAME], $rec[$WDK_FNAME], $rec[$WDK_TYPE]);
        if ($type eq "F") {
            @rec = &unpack_wdrec($DIRDB{$kk});
            push(@fileList, &path'mkpathname($dir, $fn)) if (!$rec[$WD_ISTEXT]);
        }
    }
    return @fileList;
}

sub file_list
{
    local(*DIRDB) = @_;
    my(@fileList) = ();
    my($kk, @rec, $dir, $fn, $type);
    
    for $kk (sort keys %DIRDB) {
        @rec = &unpack_wdkrec($kk);
        ($dir,$fn,$type) = ($rec[$WDK_DNAME], $rec[$WDK_FNAME], $rec[$WDK_TYPE]);
        if ($type eq "F") {
            push(@fileList, &path'mkpathname($dir, $fn));
        }
    }
    return @fileList;
}

sub empty_dir_list
#return list of empty directories
{
    local(*DIRDB) = @_;
    my (@fileList) = ();
    my ($kk, @rec, $dir, $type);
    
    for $kk (sort keys %DIRDB) {
        @rec = &unpack_wdkrec($kk);
        ($dir,$type) = ($rec[$WDK_DNAME], $rec[$WDK_TYPE]);

        if ($type eq "D") {
            @rec = &unpack_wdrec($DIRDB{$kk});
            push(@fileList, $dir) if ($rec[$WD_NSUBDIRS] == 0 && $rec[$WD_NFILES] == 0);
        }
    }

    return @fileList;
}

sub dir_list
{
    local(*DIRDB) = @_;
    my (@fileList) = ();
    my ($kk, @rec, $dir, $type);
    
    for $kk (sort keys %DIRDB) {
        @rec = &unpack_wdkrec($kk);
        ($dir,$type) = ($rec[$WDK_DNAME], $rec[$WDK_TYPE]);

        if ($type eq "D") {
            if ($LEAFONLY || $EMPTYDIR_FLAG || $NONEMPTYDIR_FLAG) {
                #need to peek at the data:
                @rec = &unpack_wdrec($DIRDB{$kk});

                if ($LEAFONLY) {
                    #if -leaf option, only return leaf nodes:
                    push(@fileList, $dir) if ($rec[$WD_NSUBDIRS] == 0); 
                } elsif ($EMPTYDIR_FLAG) {
                    #if -e option, display only empty directories:
                    push(@fileList, $dir)  if ($rec[$WD_NFILES] == 0 && $rec[$WD_NSUBDIRS] == 0); 
                } elsif ($NONEMPTYDIR_FLAG) {
                    #if -ne option, display only directories that contain at least one file:
                    push(@fileList, $dir)  if ($rec[$WD_NFILES] > 0); 
                }


            } else {
                push(@fileList, $dir)
            }
        }
    }
    return @fileList;
}

sub insert_crcs
# add crcs for files in <keylist>
{
    local(*DIRDB, *keylist, $isBinary) = @_;
    local(@filelist);  #arg to CalculateFileListCRC()

    my(@crclist, $filecrc, $fullfn, $kk, $dir, $fn, $type);

    for $kk (@keylist) {
        next if (!defined($DIRDB{$kk}));
        ($dir, $fn, $type) = &unpack_wdkrec($kk);

        next unless ($type eq 'F' );

        #we have a non-dir entry - push on list we will pass to crc calculator:
        push(@filelist, &path'mkpathname($dir, $fn));
    }


    #check to see if we need to do ascii eol line translation:
    if ($isBinary) {
        &pcrc'SetForBinary();
    } else {
        &pcrc'SetForText();
    }

    #becasuse of file-system caching, it pays to have the list in directory order:
    #tests are macbook indicate we process about 110 files/sec with random list
    #(no crc calc) vs. 12,200 files/sec with sorted.

    @filelist = sort @filelist;

    @crclist= &pcrc'CalculateFileListCRC(@filelist);

    if ( $#filelist == $#crclist) {
        while( $fullfn = shift @filelist ) {
            $filecrc = shift @crclist;
            $dir= &path'head($fullfn);
            $fn= &path'tail($fullfn);
            if (defined($DIRDB{$dir, $fn, 'F'})) {
                @rec = &unpack_wdrec($DIRDB{$dir, $fn, 'F'});
                $rec[$WD_CRC] = hex($filecrc);
                $DIRDB{$dir, $fn, 'F'} = &pack_wdrec(@rec);
            }
            else {
                printf STDERR "%s:insert_crcs ERROR: undefined database entry %s \n", $p, join(',',($dir,$fn,'F'));
            }
        }
    }
    else {
        printf STDERR "ERROR: %s crc list: %s does not match file list: %s\n", $p, $#filelist, $#crclist;
    }
}

sub parse_crcfile
#
# CREATE a walkdir <DB> structure from <filename>,
# which is assumed to be the name of a checksum.log file
# as created by the "release" utility.
#
# a better name for this routine would be "cksumlog_to_walkdirDB".
#
# EXAMPLE INPUT DATA (solsparc):  
#   userapp/appletsu/cl0/apltsupp.pex CRC=c5408285
#   userapp/appletsu/cl0/projects.btd CRC=144cd7c9
#   userapp/appletsu/cl0/projects.btx CRC=2e7a8a31
#
# EXAMPLE INPUT DATA (NT):  
#
#   userapp\appletsu\cl0\apltsupp.pex CRC=c5408285
#   userapp\appletsu\cl0\projects.btd CRC=144cd7c9
#   userapp\appletsu\cl0\projects.btx CRC=2e7a8a31
#
# returns 1 if success else 0
{
    local($filename, *DB)= @_;
    my(@rec, $crc, $dir, $fn);

    if (open( CRC_FILE, $filename) > 0) {
        while(<CRC_FILE>) {
            chomp($_);
            @rec = split(/\s+CRC=/oi, $_);
            return 0 if ($#rec+1 != 2);     # ERROR IN INPUT DATA.

            ($dir, $fn, $crc) = (&path'head($rec[0]), &path'tail($rec[0]), $rec[1]);

            #### make pathname compatible with walkdir:
            $dir = &path'mkpathname( $DOT, $dir) if ($dir ne $DOT);

#printf "dir='%s' fn='%s' crc=%s\n", $dir, $fn, $crc;

            $DB{$dir, $fn, 'F'} = &walkdir'pack_wdrec( "", hex($crc), "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0");
        }
        close(CRC_FILE);
        return 1;
    }
    return 0;
}

sub crc_file
#returns the FIRST CRC matching a full pathname.
{
    local(*DIRDB, $file) = @_;
    local($crcstr) = 0;
    local(@rec);
    local($dir,$fn);

    $fn = &path'tail($file);
    return(undef) if (!defined($fn));

    $dir = &path'head($file);
    $dir = "" if (!defined($dir));  #dir can be empty string

    #look it up:
    $txt = $DIRDB{$dir,$fn,'F'};
    if (defined($txt)) {
        #FOUND file..
    } else {
        $txt = $DIRDB{$dir,$fn,'L'};
        if (!defined($txt)) {
            $txt = $DIRDB{$dir,$fn,'D'};
        }
    }

    return undef;
}
        
sub FindFiles
    # return a list of files underneath a directory that match a pattern
{
    local($dir, $pattern) = @_;

    local(%DIRDB);
    %DIRDB = ();
    print "walkdir of $dir with $pattern\n" if ($DEBUG);
    if (&dirTree(*DIRDB, &path'pwd, $dir)) {
        print "walkdir returned an error\n";
    }
    return grep(/$pattern/, &file_list(*DIRDB));
}

################################# INITIALIZATION ###############################

sub init
#copies of global vars from main package:
{
    $p = $'p;       #$main'p is the program name set by the skeleton
    $OS = $'OS;
    $UNIX = $'UNIX;
    $MACINTOSH = $'MACINTOSH;
    $NT = $'NT;
    $DOT = $'DOT;

    #default option settings:
    $HELPFLAG = 0;
    $FILEFLAG = 0;
    $QUIET = 0;
    $VERBOSE = 0;
    $TEXT_FILEFLAG = 0;
    $DIRFLAG = 0;
    $EMPTYDIR_FLAG = 0;     #display empty dirs
    $NONEMPTYDIR_FLAG = 0;  #display non-empty dirs
    $DOCRC = 0;
    $DOMODES = 0;
    $CVSONLY = 0;
    $SKIPCVS = 0;
    $CREATE_RCSFILE = 0;    #create RCS files in tree
    $DO_UNJAR = 0;
    $DO_UNTAR = 0;
    $SAVE_TEXTMODE = 0;
    $COUNT_LINES = 0;
    $SHOWTEXT = 0;
    $SHOWSLICE = 0;     #only show slice of tree at specified depth (requires -l opt)
    $LEAFONLY = 0;      #only show leaf nodes
    $SAVE_FILE_INFO = 1;        #default is to save file records in db
    $DISKUSAGE = 0;     #compute & display disk-usage totals in each directory.
    $SYMLINKFLAG = 0;
    $RIDICULOUSDEPTH = 500; #default to ridiculously high value
    $MAXDEPTH = $RIDICULOUSDEPTH;
    $SQUOTE = 0;            #wrap file/dir names in single-quotes
    $DQUOTE = 0;            #wrap file/dir names in double-quotes
    $DQUOTE_FIRST = 0;      #if -squote & -dquote, then do in order flags appear

    $TREEDEPTH = 0;     #keep track of actual max tree depth

    #output format options for -du option:
    $DU_BYTES = 100;
    $DU_KBYTES = 101;
    $DU_MBYTES = 102;
    $DU_GBYTES = 103;
    $DU_FORMAT = $DU_KBYTES;

    #record defs for dirTree DB:
    $WD_PFMT = 'L*';
    $WD_UFMT = 'L*';
    $WD_FS = $; ;
    $WD_NF = 19;
    (
        $WD_LINKTO,
        $WD_CRC,
        $WD_DEPTH,      #added 12/22/98 (russt)
        $WD_DEV,    #if directory, this is NFILES
        $WD_INO,    #if directory, this is DIRTOTAL
        $WD_MODE,   #if directory, this is NSUBDIRS
        $WD_NLINK,
        $WD_UID,
        $WD_GID,
        $WD_RDEV,
        $WD_SIZE,
        $WD_ATIME,
        $WD_MTIME,
        $WD_CTIME,
        $WD_BLKSIZE,
        $WD_BLOCKS,
        $WD_ISTEXT, #1 if text, otherwise 0
        $WD_LINECNT,
    )   = (0..$WD_NF-1);

    #aliases for directory record:
    $WD_NFILES = $WD_DEV;
    $WD_DIRTOTAL = $WD_INO;
    $WD_NSUBDIRS = $WD_MODE;

    #KEY defs for dirTree DB:
    $WDK_FS = $; ;
    $WDK_NF = 3;
    (
        $WDK_DNAME,     #dir name
        $WDK_FNAME,     #file name
        $WDK_TYPE,      #entry type:  {'F', 'D', 'L'} <==> (File, Dir, Link)
    )   = (0..$WDK_NF-1);

    #record defs for stat buf:
    #$N_STATBUF = 12;
    #($DEV, $INO, $MODE, $NLINK, $UID, $GID, $RDEV, $SIZE,
    # $ATIME, $MTIME, $CTIME, $BLKSIZE, $BLOCKS) =  (0..$N_STATBUF);

    $STAT_SIZE = 7;
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
Usage:  $p [options] [dirs...]

Options:
 -help     display this usage message
 -f        display file entries only.
 -ftxt     display text file entries only.
 -d        display directory entries.

 -v        display warnings or informational output.
 -q        don't display warnings or informational output.
 -qq       don't display dirtree (useful with -unjar/-untar options).

 -dq[uote] wrap file/dir names in double-quotes
 -sq[uote] wrap file/dir names in single-quotes

 -e        show only empty directories.
 -ne       only display directories that have plain files or symlinks.
 -s        display symbolic link entries only
 -l depth  descend to level <depth>, starting at level 0.
 -slice    only show slice of tree at depth specified with -l.
 -leaf     only show contents of leaf dirs (and the dirs themselves if -d).
 -crc      compute & display crc for each file and/or symlink.
 -modes    display permission bits for each file and/or symlink.
 -cvsonly  only enter directories that have CVS subdirectories
 -sccsonly only enter directories that have SCCS (or sccs) subdirectories
 -noscm    skip RCS, CVS, SCCS, SUBVERSION, and GIT meta-directories.
 -nocvs    alias for -noscm
 -norcs    alias for -noscm
 -nosccs   alias for -noscm
 -nosvn    alias for -noscm
 -nogit    alias for -noscm
 -ci       create RCS file for each file in path - useful for seeding a CVS repository
 -text     mark each file as "TXT" or "BIN"
 -lc       display line counts for each text file
 -du       display size totals for each directory & file
 -bytes    display disk usage totals in bytes.
 -kbytes   display disk usage totals in kilobytes (default).
 -mbytes   display disk usage totals in megabytes.
 -gbytes   display disk usage totals in gigabytes.
 -unjar    unjar file with a .zip, .jar, or .war suffix, in subdir with root archive name,
           e.g., ./foo.jar -> ./foo/ (skip if ./foo/ exists).  Implies -f.
 -untar    untar file with a .tar, .tgz, or .tar.gz suffix, in subdir with root archive name,
           e.g., ./foo.tar -> ./foo/ (skip if ./foo/ exists).  Implies -f.

Example:
 $p /tmp
 $p -unjar mykit

NOTE:  NO arguments defaults to:

 $p -d -f .
!
    return($status);
}

sub parse_args
#proccess command-line aguments
{
    local(*ARGV, *ENV) = @_;

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
        $flag = shift(@ARGV);

        if ($flag eq "-f") {
            $FILEFLAG = 1;
        } elsif ($flag eq "-d") {
            $DIRFLAG = 1;
        } elsif ($flag eq "-v") {
            $VERBOSE = 1;
            $QUIET = 0;
            $QQUIET = 0;
        } elsif ($flag eq "-qq") {
            $VERBOSE = 0;
            $QQUIET = 1;
            $QUIET = 1;
        } elsif ($flag eq "-q") {
            $VERBOSE = 0;
            $QUIET = 1;
        } elsif ($flag eq "-ftxt") {
            $TEXT_FILEFLAG = 1;
            $FILEFLAG = 1;
            &option_text(1);
        } elsif ($flag =~ "-[df][df]") {
            $DIRFLAG = 1;
            $FILEFLAG = 1;
        } elsif ($flag eq "-s") {
            $SYMLINKFLAG = 1;
        } elsif ($flag eq "-e") {
            $DIRFLAG = 1;
            $EMPTYDIR_FLAG = 1;
        } elsif ($flag eq "-ne") {
            $DIRFLAG = 1;
            $NONEMPTYDIR_FLAG = 1;
        } elsif ($flag eq "-bytes") {
            $DU_FORMAT = $DU_BYTES;
        } elsif ($flag eq "-kbytes") {
            $DU_FORMAT = $DU_KBYTES;
        } elsif ($flag eq "-mbytes") {
            $DU_FORMAT = $DU_MBYTES;
        } elsif ($flag eq "-gbytes") {
            $DU_FORMAT = $DU_GBYTES;
        } elsif ($flag eq "-crc") {
            &option_crc(1);
        } elsif ($flag eq "-modes") {
            &option_modes(1);
        } elsif ($flag eq "-cvsonly") {
            &option_cvs_only(1);
        } elsif ($flag eq "-sccsonly") {
            &option_sccs_only(1);
        } elsif ($flag eq "-noscm") {
            &option_skip_cvs(1);
        } elsif ($flag eq "-nocvs") {
            &option_skip_cvs(1);
        } elsif ($flag eq "-nogit") {
            &option_skip_cvs(1);
        } elsif ($flag eq "-norcs") {
            &option_skip_cvs(1);
        } elsif ($flag eq "-nosccs") {
            &option_skip_cvs(1);
        } elsif ($flag eq "-nosvn") {
            &option_skip_cvs(1);
        } elsif ($flag eq "-ci") {
            &option_ci(1);
            #option -ci => -norcs
            &option_skip_cvs(1);
        } elsif ($flag eq "-unjar") {
            &option_unjar(1);
            $FILEFLAG = 1;
        } elsif ($flag eq "-untar") {
            &option_untar(1);
            $FILEFLAG = 1;
        } elsif ($flag eq "-text") {
            $SHOWTEXT = 1;
            &option_text(1);
        } elsif ($flag eq "-du") {
            &option_diskusage(1);
        } elsif ($flag eq "-lc") {
            &option_countlines(1);
        } elsif ($flag eq "-leaf") {
            &option_leaf(1);
        } elsif ($flag eq "-l") {
            return &usage(1) if (!@ARGV);
            return &usage(1) if (!&option_maxdepth(shift(@ARGV)));
        } elsif ($flag eq "-slice") {
            &option_slice(1);
        } elsif ($flag =~ /^-sq(uote)?/ ) {
            &option_squote(1);
        } elsif ($flag =~ /^-dq(uote)?/ ) {
            &option_dquote(1);
        } elsif ($flag =~ '^-h') {
            $HELPFLAG = 1;
            return &usage(0);
        } else {
            printf STDERR "%s:  unrecognized option, '%s'\n", $p, $flag;
            return &usage(1);
        }
    }

    if ($SHOWSLICE && $MAXDEPTH >= $RIDICULOUSDEPTH) {
        printf STDERR "%s:  -slice option requires -l <depth> option.\n", $p;
        return &usage(1);
    }

    #set -d & -f & -s option if none specified
    if (!$DIRFLAG && !$FILEFLAG && !$SYMLINKFLAG) {
        $DIRFLAG = $FILEFLAG = $SYMLINKFLAG = 1;
#printf STDERR "-d & -f & -s set\n";
    }

    if ($NONEMPTYDIR_FLAG && $EMPTYDIR_FLAG) {
        #if both these options selected, then neither apply:
        $EMPTYDIR_FLAG = $NONEMPTYDIR_FLAG = 0;
    }

    $SAVE_FILE_INFO =  $FILEFLAG;

    #eliminate empty args (this happens on some platforms):
    @ARGV = grep(!/^$/, @ARGV);

    #take remaining args as directories to walk:
    if ($#ARGV < 0) {
        @DIRLIST = $DOT;
    } else {
        @DIRLIST = @ARGV;
    }

    return(0);
}

1;
