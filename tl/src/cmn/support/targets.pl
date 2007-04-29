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
# @(#)targets.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

#
# platforms.pl - routines to supply data and methods about platform targets.
#

package tg;

%PORT_DIRS = (
	"cmn", 1,
	"alphaosf", 1,
	"alphavms", 1,
	"axpnt", 1,
	"dgux88k", 1,
	"dos", 1,
	"hp9000", 1,
	"mac", 1,
	"macboot", 1,
	"nt", 1,
	"pcnt", 1,
	"rs6000", 1,
	"sequent", 1,
	"solaris5", 1,
	"solsparc", 1,
	"cygwin", 1,
	"sparc", 1,
	"vaxvms", 1,
	"w30", 1,
);

sub target_list
{
	local($TARGETS) = @_;

	return(split(/[,:]/, $TARGETS));
}

sub bad_targets
{
	local(*TARGETS) = @_;

	return(grep(!$PORT_DIRS{$_}, @TARGETS));
}

1;
