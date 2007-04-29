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
# @(#)recordreader.pl - ver 1.1 - 01/04/2006
#
# Copyright 2004-2006 Sun Microsystems, Inc. All Rights Reserved.
# 
# END_HEADER - DO NOT EDIT
#

# this is a library to create an array of records managed by a user class.
# this library will read in a file of newline-separated records,
# and call your class to initialize each array element.  You must
# supply a class and pass it in.  You can model your class after
# the genericRecordParser package in this file.
#
# see main() for a full example of how to use it.

#use strict;

####################
package recordreader;
####################

my $p = $main::p;

sub main()
#test program for recordreader class, using genericRecordParser to
#parse and display individual records.  This library can be tested
#as follows:
#
#   ln -s `fwhich prlskel` recordreader
#   create a file named "foo.dat"
#   ./recordreader
#
#the data file needs to have at least 2 records per line
{
    #this will fail and return undef if foo.dat is not readable:
    my $recs = new recordreader("foo.dat", "genericRecordParser", \&genericRecordParser::new);
    if (!defined($recs)) {
        printf "%s: failed to create new recordreader: %s\n", $p, $recs->error;
        return 1;
    }

    if (!$recs->readrecords()) {
        printf "%s: cannot read records: %s\n", $p, $recs->error;
        return 1;
    }

    printf "%s: read %d records from %s\n", $p, $recs->nRecords, $recs->filename;

    my ($ii, $recptr);
    for ($ii = 0; $ii < $recs->nRecords; $ii++) {
        $recptr = $recs->getRecord($ii);
        printf "NF=%d field1='%s' fullrecord=(%s)\n",
            $recptr->NF(),
            $recptr->field1(),
            join(',', $recptr->fullRecord());
    }

    #this is an alternate way to do the iteration:
    foreach $recptr ($recs->allRecords) {
        printf "NF=%d field1='%s' field2='%s'\n",
            $recptr->NF(),
            $recptr->field1(),
            $recptr->field2()
            ;
    }

    #example of how to call "class" methods of the genericRecordParser

    printf "field1Str='%s' nfield1=%d\n",
        genericRecordParser->field1Str,
        genericRecordParser->nfield1
        ;

    #this is an example of how to iterate thru all the records of field1.
    #it depends on the record parser having a method named "fullRecord",
    #which returns a list of all fields for a given record.
    #this list can then be searched via grep(), etc.

    my (@allfield1) = $recs->nthRecords(genericRecordParser->nfield1);
    printf "allfield1=(%s)\n", join(',', @allfield1);

    return 0;
}

#############################
#Class implementation follows.
#############################

sub new
{
    my ($invocant, $filename, $recordClassName, $recordCreator) = @_;
    my $class = ref($invocant) || $invocant;    # allows this constructer to be invoked by a sub-class

#printf "T4 invocant is '%s' class is '%s'\n", $invocant, $class;;

    if (!defined($filename)) {
        printf STDERR "recordreader constructor ERROR:  you must provide a filename (caller='%s').\n", $invocant;
        return undef;
    }

    if (!defined($recordClassName)) {
        printf STDERR "recordreader constructor ERROR:  you must provide the name of your record parser class (caller='%s').\n", $invocant;
        return undef;
    }

    if (!defined($recordCreator)) {
        printf STDERR "recordreader constructor ERROR:  you must pass your record parser new() method (caller='%s').\n", $invocant;
        return undef;
    }

    #set up my class attributes:
    my $self = {
        'filename' => $filename,
        'recordClassName' => $recordClassName,
        'recordCreator' => $recordCreator,  #this is a reference to the new method of <recordClassName>
        'fieldsPer' => 0,
        'nRecords' => 0,
        'badRecords' => 0,
        'emptyRecords' => 0,
        'FS' => "\t",
        'error' => "",
        'recordStorage' => undef,
    };

    bless($self, $class);       # "declare" this package as a class
    return $self;
}

sub readrecords     ## PUBLIC BOOLEAN
{
    my ($self) = @_;
    my $filename = $self->{'filename'};
    my $recordCreator = $self->{'recordCreator'};
    my $recordClassName = $self->{'recordClassName'};

    if (!open(INFILE, $self->{'filename'})) {
        $self->{'error'} = sprintf("cannot open file '%s', %s", $filename, $!);
        return 0;
    }

    my ($goodcnt, $badcnt, $emptycnt) = (0,0,0);
    my @allrecs = ();
    my $line;
    my $record_ref = undef;
    while ($line = <INFILE>) {
        #########
        #allocate an new object for this record:
        #########

        #
        #This is what we are trying to do:
        #       $record_ref = record->new($line);
        #We accomplish this by passing our record-handling class name
        #to its constructor, so it is "blessed" into the correct class.
        #this allows us to call any of the class's methods later
        #through this object reference.

        $record_ref = &{$recordCreator}($recordClassName, $line);

        #if our recordCreator says it is a good record...
        if (defined($record_ref)) {
            #...then add it to our list
            push @allrecs, $record_ref;
            $goodcnt++;
        } else {
            if ($line =~ /^\s*$/) {
                $emptycnt++;
            } else {
                #...otherwise, just up the bad count
                $badcnt++;
            }
        }
    }

    $self->{'nRecords'} = $goodcnt;
    $self->{'emptyRecords'} = $emptycnt;
    $self->{'badRecords'} = $badcnt;
    $self->{'recordStorage'} = \@allrecs;   #this prevents the array from being garbage collected.

    close INFILE;

    if ($badcnt > 0) {
        $self->{'error'} = sprintf("File '%s' contained (%d/%d/%d) (GOOD/BAD/EMPTY) records",
                                    $filename, $goodcnt, $badcnt, $emptycnt);
    }

    return ($badcnt == 0);

}

sub filename
{
    my ($self) = @_;
    return $self->{'filename'};
}

sub error
{
    my ($self) = @_;
    return $self->{'error'};
}

sub nRecords
{
    my ($self) = @_;
    return $self->{'nRecords'};
}

sub badRecords
{
    my ($self) = @_;
    return $self->{'badRecords'};
}

sub emptyRecords
{
    my ($self) = @_;
    return $self->{'emptyRecords'};
}

sub allRecords
#return the list of records (could take a lot of memory!)
{
    my ($self) = @_;
    return @{$self->{'recordStorage'}};
}

sub nthRecords
#return the nth field of ALL records
{
    my ($self, $nn) = @_;
    my @result = ();

    my $rec;
    my @tmp;
    foreach $rec ($self->allRecords) {
        @tmp = $rec->fullRecord;
        push @result, $tmp[$nn];
    }

    return @result;
}

sub getRecord
{
    my ($self, $ii) = @_;

#my (@list) = @{$self->{'recordStorage'}};
#printf "getRecord ii=%d NF=%d recordStorage=(%s)\n", $ii, $#list, join(',', @list); 

    return ${$self->{'recordStorage'}}[$ii];
}

###########################
package genericRecordParser;
###########################

#this is an example of a class that can be used to parse a flat-file
#record with field separators.  The default field separator is tab.
#you can use this as an example of how to implement a record parser
#class.  For efficiency, it doesn't make much sense to sub-class this
#parser, but you can if you want.
#
#you will want to change the "field1, field2 methods to something more
#appropriate to the data you are parsing.  That is the whole point
#of this class, you want to be able to say:  myrec->LastName instead
#of $myrec[22] or something similar.  Of course, $myrec[22] is much
#more efficient, so if you are doing some serious i/o, you may have
#to revert to the old methods.
#
#In order to use your record-parsing class, you have to tell the recordreader
#class about it, e.g.:
#
#   my $reader = new recordreader("foo.dat", "genericRecordParser", \&genericRecordParser::new);
#
#See recordreader::main() for a simple example.
#

#class variables:
my $FS = "\t";

sub new
{
    my ($invocant, $text) = @_;

    my $class = ref($invocant) || $invocant;    # allows this constructer to be invoked by a sub-class
#printf "in record::new() invocant is '%s' class is '%s' text='%s'\n", $invocant, $class, $text;

    chomp $text;    #eliminate newlines

    #set up my class attributes:
    my $self = {
        'fields' => undef,
    };
    bless($self, $class);       # "declare" this package as a class


#this is the long-winded way:
#   my @list = split($FS, $text);
#   $self->{'fields'} = \@list;

    #allocate an array to hold the fields:
    $self->{'fields'} = [split($FS, $text)];

#printf "list=(%s)\n", join(',', @{$self->{'fields'}});

    return $self;
}

sub field1
{
    my ($self) = @_;
    return ${$self->{'fields'}}[0];
}

sub field2
{
    my ($self) = @_;
    return ${$self->{'fields'}}[1];
}

sub nfield1
#return the field number of the "field1" record
{
    return 0;
}

sub nfield2
#return the field number of the "field2" record
{
    return 1;
}

sub field1Str
#return the name of the "field1" record
{
    return "field1";
}

sub field2Str
#return the name of the "field2" record
{
    return "field2";
}

sub fullRecord
{
    my ($self) = @_;
    return (@{$self->{'fields'}});
}

sub NF
{
    my ($self) = @_;
    return $#{$self->{'fields'}};
}

sub FS
{
    return($FS);
}
1;
