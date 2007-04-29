package tagBuild;
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
# @(#)tagBuild.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#


# tagBuild - add and manipulate tags associated with build.
# 
# Initial Revision  (ericag 2/2000)
#

 require "path.pl";
 require "walkdir.pl";
 require "bldmsg.pl";
 require "os.pl";

&init;

########### MAIN #################
sub main
{
	local(*ARGV, *ENV) = @_;
	
	return (1) if (&parse_args(*ARGV, *ENV) != 0);
	return (0) if ($HELPFLAG);
	  
	if (!open (LOGFILE, ">>$LOGFILE")) {
		printf STDERR "%s [main]:  ERROR:  cannot open '%s' for writing.\n", $p, $LOGFILE;
		return 1;
	}
	## By the time tagBuild is called, should 
	## already have FULLTAG and a valid repository.  
	## If not, quit. (REFREPO is NOT important).

	## &show_options;
	$er = 0;
	if ($DOTAG > 0 || $DELTAG > 0 ) {
		foreach $key (keys %CVSLIST) {
			$status = tag_by_dir($key);		
		}
	}
		if (@ERRORL-0 > 0) {
			@bldmsg = ("-warn", "-p", "$p", "[main] Error Summary:  Details should already have been provided.") ;
			&bldmsg'main(*bldmsg, *ENV);
			foreach $x (@ERRORL) {
				@bldmsg = ("-warn", "-p", "$p", "[main] Tag error at $x");
				&bldmsg'main(*bldmsg, *ENV);
				if ($FORCE == 0) {
					$er = $er + 1;
				}
			}
		}

	close(LOGFILE);
	return ($er);

}

sub walk
{
	my ($topdir) = @_;
	my (@dirlist) = ();
	my ($error) = 0;
	# @dirlist = `walkdir -d -leaf -l 1 $CVSLIST{$key}[$MOD]`;
	
	&walkdir::save_file_info(0);
	&walkdir::option_leaf(1);
	&walkdir::option_maxdepth(1);
	
	$cwd = &path'pwd;

	%DIRDB = ();
	$dir = $topdir;
	$error = &walkdir::dirTree(*DIRDB,$cwd,$dir);
	
	if ( $error == 0 ) {
		for $x (sort(keys %DIRDB)) {
				$dirname = $1;
					@dirlist = &walkdir::dir_list(*DIRDB);	
					return @dirlist;
		}
		return @dirlist;
	} else {
		@bldmsg = ("-error", "-p", "$p", "[walk] Cannot walkdirs.");
		&bldmsg'main(*bldmsg,*ENV);
		return 1;
	}
}

sub tag_by_dir 
{
	# By the time we get here, we know that the repository is otherwise accessible.
	# just tag.

	my ($key) = @_;
	$args = "";

	## Get a list of files for the named CVSROOT
	# print "IN TAG_BYDIR  $key $CVSLIST{$key}[$MOD]\n";
	
#	@dirlist = `walkdir -d -leaf -l 1 $CVSLIST{$key}[$MOD]`; #THIS WORKS
#   @dirlist = os'eval_cmd("walkdir -d -leaf -l 1 $CVSLIST{$key}[$MOD]"); #THIS WORKS
 	@dirlist = &walk($CVSLIST{$key}[$MOD]); 
	
	@dirlist = grep(!/\/CVS/, @dirlist); # unnecessary.

	if ($DELTAG) {
		$args = "-d";
	}
	if ($CHGTAG) {
		$args = "-F";
	}
	for $x (@dirlist) {
		if ($DEBUG) { print "X <$x>\n"; }
		if ($DEBUG) { print "cvs -d $CVSLIST{$key}[$ROOT] tag $args $FULLTAG $x) "; }
		@res = ();
		@out = &os'eval_cmd("cvs -d $CVSLIST{$key}[$ROOT] tag $args $FULLTAG $x",\$status,\@res,\$errmsg) ;
		for $result (@res) {
			print "$result\n";
			if ($DEBUG) { print "RES $result STAT$stat ERR$err ENDRES\n"; }
			if ( $result !~ /cvs server: Tagging/ ) {
				chomp($x);
				push(@ERRORL, $x ); 
				@bldmsg = ("-warn", "-p", "$p", "[tag_by_dir] cvs tag failed in $x, tagname=$FULLTAG, error message:$result");
				&bldmsg'main(*bldmsg, *ENV);

				if ( $FORCE == 0 ) {
					@bldmsg = ("-error", "-p", "$p", "[tag_by_dir] Tagging did not succeed in at least one directory.  \nPlease correct the errors, remove tags ($FULLTAG) to clean any files which were tagged prior to the error,\n and tag again.  (or, you may execute forcetag).");
					&bldmsg'main(*bldmsg, *ENV);
					return 1;
				} else {
					#I'm not sure I want to be that noisy with the errors.
					#I think I can do without this error message.
					# @bldmsg = ("-warn", "-p", "$p", "[tag_by_dir] Tagging did not succeed in at least one directory.");
					# &bldmsg'main(*bldmsg, *ENV);
				}
			}
		} #for
	} #for
	return 0;

}

############ USAGE ###########
sub usage 
{
	local($status) = @_;

	print STDERR <<"!";
Usage: $p -repo <REPO> -args 

Synopsis:
	This script will normally be called from a product specific wrapper script, but can also run independently after a build has been run to update tags.  When running this script by hand, you MUST specify the <tagname> and the CVS Repositor(ies) you wish to tag.

Options:  
 -help           Display this usage message
 -dotag <TAG>
                 Add the following tag to files.  
 -deltag <TAG>   Remove this tag.
 -chgtag <TAG>   Move a pre-existing tag to the current location.
 -forcetag       Force tagging to occur even if there are files which cannot be tagged.
 -repo	<INFO>   Repo information must be supplied between double quotes with a 
                 pipe (|) between each element in the following order.
                 NAME      This is a one-word name of convenience for your repository. Ex: FFJ
                 CVSROOT   The CVSROOT for this repository.  Ex: :pserver:cvsuser\@fortecvs:/mongoose
                           Note: if you are not passing this by variable, you need to escape the "@".
                 DIR       The directory in which files from this repository are located.  Ex:  m_all
                 NEEDSOCKS Boolean -does the repository needsocks on for you to connect? Ex: 0
                 TAGREF    Reference file to check that tag is not preexistant. Ex: m_all/tagref
                 Example: -repo "FFJ|:pserver:cvsuser\@fortecvs:/mongoose|f4j_all|0|m_all/tagref" 
				

Environment: This should be run only in a build environment.
RELEASE_BUILD=1
DEVELOPER_BUILD=0
PATHREF = root of buildpath. (e.g. /lathe1/cvs/egtest/forte4j )
LOGDIR	Where to put log file	
At least one -repo argument MUST be supplied, and must be valid.

Example:
$p Build1400a 
$p -repo "FFJ|:pserver:\$ENV{USER}\@fortecvs:/forte4j|f4j_all|0|f4j_all/f4jbuild/tagref" 
$p -deltag Build99-2 -repo "FFJ|\$CVSROOT|f4j_all|0|f4j_all/f4jbuild/tagref"
$p -chgtag Build99-1 -repo "FFJ|\$CVSROOT|f4j_all|0|f4j_all/f4jbuild/tagref"
$p -useprefix BenchmarkTag -repo "FFJ|\$CVSROOT|f4j_all|0|f4j_all/f4jbuild/tagref"

!
	return($status);
}

sub parse_args
{
	local(*ARGV, *ENV) = @_;
	# You must have a valid repository and tagname before you start
	# this script (or quit).

	$HELPFLAG = 0;

	while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flag = shift(@ARGV);
		$repocount = 1;

			if ($flag =~ '^-h' ) {
				$HELPFLAG = 1;
				return (&usage(1));
			} elsif ( $flag =~ '-dotag' ) {
				if ( $#ARGV < 0 || $ARGV[0] =~ /^\s*$/ ) {
					@bldmsg = ("-error", "-p", "$p", "[parse_args] -dotag requires an argument");
					&bldmsg'main(*bldmsg, *ENV);
					return (&usage(1));
				} else {
					$FULLTAG = shift(@ARGV);
					$DOTAG = 1;
				}
			} elsif ( $flag =~ '-test' ) {
				$DOTAG = 0;
			} elsif ( $flag =~ '-version' ) {
				print "Last updated 20 Feb 2001 by ericag\n";
			} elsif ( $flag =~ '-forcetag' ) {
				$FORCE = 1;
			} elsif ($flag =~ '-deltag' ) {
				if ( $#ARGV < 0 || $ARGV[0] =~ /^\s*$/ ) {
					@bldmsg = ("-error", "-p", "$p", "[parse_args] -deltag requires an argument");
					&bldmsg'main(*bldmsg, *ENV);
					return (&usage(1));
				} else {
					$DELTAG = 1;
					$FULLTAG = shift(@ARGV);
				}
			} elsif ($flag eq "-chgtag" ) {
				$CHGTAG = 1;
				$DOTAG = 1;
			} elsif ($flag eq "-puttag" ) {
				if ( $#ARGV < 0 || $ARGV[0] =~ /^\s*$/ ) {
					@bldmsg = ("-error", "-p", "$p", "[parse_args] -puttag requires an argument");
					&bldmsg'main(*bldmsg, *ENV);
					return (&usage(1));
				} else {
					$FULLTAG = shift(@ARGV);
					$DOTAG=1;
				}
			} elsif ($flag =~ '^-repo' ) {
				if ( $#ARGV < 0 || $ARGV[0] =~ /^\s*$/ ) {
					@bldmsg = ("-error", "-p", "$p", "[parse_args] -repo requires an argument");
					&bldmsg'main(*bldmsg, *ENV);
					return (&usage(1));
					## NEED TO add to usage -repo argument will be enclosed in quotes.
				} else {
					$tmp = shift(@ARGV);
					@tmp = split /\|/, $tmp;
					$repocount++;

						$CVSLIST{$tmp[0]}[$ROOT]=$tmp[$ARGROOT] ;
						$CVSLIST{$tmp[0]}[$MOD] = $tmp[$ARGMOD] ; 
						$CVSLIST{$tmp[0]}[$NEEDSOCKS]= $tmp[$ARGNEEDSOCKS];
						$CVSLIST{$tmp[0]}[$TAGREF]= $tmp[$ARGTAGREF];
					if ( ( defined $CVSLIST{$tmp[0]}[$ROOT] )  && ( defined $CVSLIST{$tmp[0]}[$MOD] )  && ( defined $CVSLIST{$tmp[0]}[$NEEDSOCKS] )  && ( defined  $CVSLIST{$tmp[0]}[$TAGREF] ) && ( $CVSLIST{$tmp[0]}[$ROOT] ne "" )  && ( $CVSLIST{$tmp[0]}[$MOD] ne "" )  && ( $CVSLIST{$tmp[0]}[$NEEDSOCKS] ne "" )  && (  $CVSLIST{$tmp[0]}[$TAGREF] ne "" ) ) {
					} else {
						@bldmsg = ("-error", "-p", "$p", "[parse_args] Invalid -repo argument");
						&bldmsg'main(*bldmsg, *ENV);
						return(&usage(1));
					}
				}

			} else {
				# printf SiTDERR "%s: unrecognized option, '%s'\n", $p, $flag;
				@bldmsg = ("-error", "-p", "$p", "[parse_args] Unrecognized option: $flag");
				&bldmsg'main(*bldmsg, *ENV);
				return &usage(1);
		} #if arg
	} # while

	if (keys(%CVSLIST)) {  #as long as there are some repos to test.

		## Check the validity of each cvsroot in the arguments.
		for $key (keys %CVSLIST) {
				#print "Checking $key for access\n";
			##first check that the variables exist & are not ""

			 #if (@x = cvs -d $CVSLIST{$key}[$ROOT] status $CVSLIST{$key}[$TAGREF]) {
			if (@x = os'eval_cmd("cvs -d $CVSLIST{$key}[$ROOT] status $CVSLIST{$key}[$TAGREF]",\$status,\@stderr,\$errmsg) ) {
				if ($x[1] =~ /no file/) { #this used to be $x[1]
					@bldmsg = ("-error", "-p", "$p", "[parse_args] Specified tagref file ($CVSLIST{$key}[$TAGREF]) does not exist.");
					&bldmsg'main(*bldmsg, *ENV);
					return (&usage(1));
				}
			} else {
				@bldmsg = ("-error", "-p", "$p", "[parse_args] Unable to access repository $key");
				&bldmsg'main(*bldmsg, *ENV);
				return (&usage(1));
			}
		} #for
	} else {
		@bldmsg = ("-error", "-p", "$p", "[parse_args] Invalid -repo argument.  There must be at least one repository to tag");
		&bldmsg'main(*bldmsg, *ENV);
		return (&usage(1));
	}
} # parse_args

sub show_options
{
	print "############ SHOWING OPTIONS ########## \n";
	print "CVS_BRANCH_NAME is $ENV{CVS_BRANCH_NAME}\n";
	print "LOGROOT is 	$ENV{LOGROOT}\n";

	print "DOTAG is	$DOTAG\n";
	print "CHGTAG is $CHGTAG\n";
	print "DELTAG is $DELTAG\n";
	print "FULLTAG is $FULLTAG\n";
	print "LOGFILE is $LOGFILE\n";

}

sub init 
{
	$p = $'p;
	$DOT = $'DOT;
	$HELPFLAG=0;
	$DEBUG=0;
	
	$DOTAG = 0;
	$DELTAG = 0;
	$CHGTAG = 0;
	$TAGNAME = "";
	$FORCE = 0;
	$RELEASE_BUILD = $ENV{RELEASE_BUILD};
	
	$FULLTAG = "";

	$stat = 0;
	$err = "";

	if ( defined( $ENV{TAGLOG} ) ) {
		$LOGFILE = $ENV{TAGLOG};
	} else {
		$x = os'eval_cmd("date '+%y%m%dtag.log'");
		$LOGFILE = "$ENV{LOGROOT}/$x";
	}

#	@NB=("$ENV{NB_CVSROOT}","nb_all", 1, "nb_all/nbbuild/build.xml");

	@resultlist=();
	@ERRORL=();
	%CVSLIST=();

	#COUNTERS
	$errorcount = 0;

	$ROOT = 0;
	$ARGROOT = 1;
	$MOD = 1;
	$ARGMOD = 2;
	$NEEDSOCKS = 2;
	$ARGNEEDSOCKS = 3;
	$TAGREF = 3;
	$ARGTAGREF = 4;


}

1;
