package prlskel;

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
# @(#)prlskel.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

$p = $'p;

sub main
{
	local(*ARGV, *ENV) = @_;

	&init;
	return (1) if (&parse_args);
	return (0) if ($HELPMODE);

	if ($inputFile eq "-") {
		printf("%s:\n\tPERL_LIBPATH=%s\n\n", $p, $ENV{'PERL_LIBPATH'}) unless ($QUIET);
	}

	return(&NetworkEvalMode) if ($NETEVALMODE);
	return(&evalmode) if ($EVALMODE);
	return(&test) if ($TESTMODE);

	return 0;
}

&init;
sub init
{
	$HELPMODE = 0;
	$TESTMODE = 0;
	$EVALMODE = 0;
	$NETEVALMODE = 0;
	$QUIET = 0;

	$PROFMODE = 0;
	$inputFile = "-";
	$outputFile = "-";
	$promptIsLineNumber = 0;
	$echoLine = 0;
	$filterOutput = "";
	$firstCmd = "";
}

sub cleanup
{
	return unless $TESTMODE;

	printf STDERR ("%s:  called cleanup routine\n", $p) unless $QUIET;
	&::dump_inc unless ($QUIET);
}

sub test
	# a test function to verify the correctness of prlskel.prl
{
	local($prog) = shift @TESTARGS;
	local(@argList) = @TESTARGS;
	local($status);

	$p = $prog;
	$'p = $prog;
	$status = &'run_pkg($prog, *argList, *ENV);
	printf STDERR ("program %s returned %d\n", $prog, $status) unless ($QUIET);
	if ($PROFMODE) {
		&main'print_prof;
	}
	return $status;
}

sub NetworkEvalMode
{
	$EOT = "End Of Transmission In Pipe\n";
	$port = 5022;
	$platform = $ENV{"FORTE_PORT"} || `whatport`;
	if ($platform eq "solsparc") {
		# for solsparc
		$AF_INET = 2;
		$SOCK_STREAM = 2;
		$WNOHANG = 64;
	} else {
		# for linux:
		$AF_INET = 2;
		$SOCK_STREAM = 1;
		$WNOHANG = 1;
	}
	$sockaddr = 'S n a4 x8';
	($name, $aliases, $proto) = getprotobyname('tcp');
	if ($port !~ /^\d+$/) {
		($name, $aliases, $port) = getservbyport($port, 'tcp');
	}
	
	print "Port = $port\n";
	
	$this = pack($sockaddr, $AF_INET, $port, "\0\0\0\0");
	
	select(NS); $| = 1;
	
	socket(S, $AF_INET, $SOCK_STREAM, $proto) || die "socket: $!";
	bind(S,$this) || die "bind: $!";
	listen(S,5) || die "connect: $!";
	
	select(S); $| = 1;

	$NetworkMode = 1;
	while ($NetworkMode) {
		($addr = accept(NS,S)) || die $!;
		select(NS); $| = 1;
		&evalmode;
	}
}

sub evalmode
{
	local($lineInterp, $lastline, $result, $lineNumber, %lineHistory, $likeCsh);
	$lastline = "";
	$lineNumber = 0;
	$likeCsh = 1;
	%lineHistory = ();
	
	while (1) {
		if ($promptIsLineNumber) {
			print "$lineNumber> ";
		} else {
			print "perl ($lineNumber)> ";
		}
		if ($firstCmd ne "") {
			$lineInterp = $firstCmd . "\n";
			if (! $echoLine) {
				print $lineInterp;
			}
			$firstCmd = "";
		} else {
			if ($NetworkMode) {
				$lineInterp = <NS>;
			} else {
				$lineInterp = <STDIN>;
			}
			if (!defined($lineInterp)) {
				print "Received EOF on stdin.\n";
				last;
			}
		}
		if ($echoLine) {
			print $lineInterp;
		}
		chop($lineInterp);
		if ($likeCsh) {
			if ($lineInterp =~ /!!/) {
				$lineInterp =~ s/!!/$lastline/g;
				print "$lineInterp\n";
			}
			if ($lineInterp =~ /(![0-9]+)/) {
				local($match, $num);
				$match = $1;
				$num = $match;
				$num =~ s/!//;
				$match = eval "quotemeta \"$match\"";
				$lineInterp =~ s/$match/$lineHistory{$num}/;
				print "$lineInterp\n";
			}
			if ($lineInterp =~ /^(!.+)/) {
				local($match, $str, $i);
				$match = $1;
				$str = $match;
				$str =~ s/!//;
				$match = eval "quotemeta \"$match\"";
				for ($i = $lineNumber - 1; $i >= 0; --$i) {
					if (substr($lineHistory{$i}, 0, length($str)) eq $str) {
						$lineInterp =~ s/$match/$lineHistory{$i}/;
						print "$lineInterp\n";
						last;
					}
				}
			}
		}
		next if ($lineInterp eq "");
		if ($lineInterp eq "exit" || $lineInterp eq "exit;") {
			last;
		}
		$lineHistory{$lineNumber} = $lineInterp;
		$lastline = $lineInterp;
		++$lineNumber;
		if ($lineInterp eq "history") {
			local($i) = 0;
			for (; $i < $lineNumber - 1; ++$i) {
				printf("%2d %s\n", $i, $lineHistory{$i});
			}
			next;
		}
		# print "just about to eval '$lineInterp'\n";
		$result = eval $lineInterp;
		# print "finished evaling\n";
		if ($@ ne "") {
			$theOutput = "ERROR: $@\n";
		} elsif (!defined($result)) {
			$theOutput = " -> (undef)\n";
		} else {
			$theOutput = " -> $result\n";
		}
		if ($filterOutput ne "") {
			# print "filterOutput = $filterOutput output = '$theOutput'\n";
			# print "\$theOutput =~ $filterOutput ;\n";
			eval "\$theOutput =~ $filterOutput ;";
		}
		print $theOutput;
		if ($NetworkMode) {
			print $EOT;
		}
	}
	return 0;
}

sub STDERR2STDOUT
{
	open(REAL_STDERR, ">&STDERR");
	open(STDERR, ">&STDOUT");
}

sub NoBufferOutput
{
	select(STDERR); $| = 1;
	select(STDOUT); $| = 1;
}

########################### USAGE SUBROUTINES ###############################

sub usage
{
	local($status) = @_;

    print STDERR <<"!";
Usage:  $'p [-help] [-eval] [-neteval] [-iinput script] [-ooutput script] [-test program args]
            [-require plfile] [-firstcmd <cmd>]

Shows PERL_LIBPATH environment and exits.

Options:
-help   show this usage message
-test   show environment, run <program> with <args>  to verify installation.
-run    (same as -test)
-eval   Run a perl read-eval-loop.
-neteval   Run a perl read-eval-loop over a network connection.

eg:
	% prlskel -eval
	% prlskel -run wfbuild.pl -e
!
    return($status);
}

sub parse_args
#proccess command-line aguments
{
	local ($flag);

    #eat up flag args:
    while ($#ARGV+1 > 0 && $ARGV[0] =~ /^-/) {
		$flag = shift(@ARGV);

		if ($flag eq '-test' || $flag eq "-run") {
			$TESTMODE = 1;
		} elsif ($flag eq "-prof") {
			$TESTMODE = 1;
			$PROFMODE = 1;
		} elsif ($flag =~ '^-h') {
			$HELPMODE = 1;
			return(&usage(0));
		} elsif ($flag eq "-q") {
			$QUIET = 1;
		} elsif ($flag eq "-noq") {
			$QUIET = 0;
		} elsif ($flag eq "-eval") {
			$EVALMODE = 1;
		} elsif ($flag eq "-neteval") {
			$NETEVALMODE = 1;
		} elsif ($flag eq "-inc") {
			unshift(@INC, shift @ARGV);
		} elsif ($flag eq "-require") {
			$plFile = shift @ARGV;
			print "require $plFile\n";
			require $plFile;
		} elsif ($flag eq "-load") {
			$pkg = shift @ARGV;
			print "&main::load_pkg($pkg)\n";
			&'load_pkg($pkg);
		} elsif ($flag eq "-firstcmd") {
			$firstCmd = shift @ARGV;
		} elsif ($flag =~ /^-i(.*)/) {
			$inputFile = $1;
			$promptIsLineNumber = 1;
			$echoLine = 1;
		} elsif ($flag =~ /^-o(.*)/) {
			$outputFile = $1;
		} else {
			print "Bad argument: $flag\n";
			return(&usage(1));
		}
    }

    if ($TESTMODE) {
		if ($#ARGV >= 0) {
			@TESTARGS = @ARGV;
		} else {
			return(&usage(1));
		}
	} elsif ($#ARGV >= 0) {
		return(&usage(1));
	}
	if ($outputFile ne "-") {
		open(REAL_STDOUT, ">&STDOUT");
		open(STDOUT, ">$outputFile") || die "Failed to open $outputFile for write: $!\n";
		select(STDOUT);
	}
	if ($inputFile ne "-") {
		# open(REAL_STDIN, "<&STDIN");
		# open(STDIN, $inputFile) || die "Failed to open $inputFile for read: $!\n";
		&'require_os;
		$perl_lib = &os'TempFile;
		&ConvertPerlFile($inputFile, $perl_lib);
		require $perl_lib;
		&'cleanup;
		exit(0);
	}

	return(0);
}

sub ConvertPerlFile
{
	local($inFile, $outFile) = @_;
	local($line, $printableLine);
	local($lineNumber) = 0;
	
	open(IN, $inFile) || die "Failed to open $inFile for read: $!\n";
	open(OUT, ">$outFile") || die "Failed to open $outFile for write: $!\n";

	while (defined($line = <IN>)) {
		chop($line);
		eval "\$printableLine = quotemeta(\$line)";
		++$lineNumber;
		printf OUT ("print \"(%d) CMD: %s\\n\";\n", $lineNumber, $printableLine);
		if ($line =~ /^\s*#/ || $line =~ /^\s*$/ || $line =~ /^\s*sub/ || $line =~ /^\s*for/ || $line =~ /^\s*}/) {
			print OUT "$line\n";
		} else {
			print OUT "\$rrr = $line\n";
			print OUT "print \" -> \" . \$rrr . \"\\n\\n\";\n";
		}
	}
	
	close(OUT);
	close(IN);
}

#############################################################################

sub PrintList
{
	local(@lst) = @_;
	local($pos) = 1;
	print "(";
	if ($#lst+1 > 0) {
		local($el, $len, $firstel);
		$firstel = shift @lst;
		print $firstel;
		$pos += length($firstel);
		foreach $el (@lst) {
			print ", ";
			$pos += 2;
			$len = length($el);
			if ($len + $pos > 75) {
				print "\n";
				$pos = 0;
			}
			print $el;
			$pos += $len;
		}
	}
	print ")\n";
	return $#lst+2;
}

sub run_pskel_cmd
## Called &run_pskel_cmd("localtxt -os unix foofile");
{
    local($argvstr) = @_;

    print "CMD_RUN_PSKEL $argvstr\n";

    @argarr=split(' ',$argvstr);
    push(@fullargs,@argarr);

    &'main(*fullargs, \@ENV);
    return 1;
}

1;
