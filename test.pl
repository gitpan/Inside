#!/usr/bin/perl -w

# This is part of the 'inside' program, and covered by the same license. 
# Copyright (C) 2000 Tom Phoenix <rootbeer@redcat.com>
# http://www.cpan.org/authors/id/P/PH/PHOENIX/

# Tests for the 'inside' program

use strict;

$|=1;
print "1..2\n";
print "# This may take a moment...\n";

open STDERR, ">ERRORS"
    or die "Can't create 'ERRORS' file: $!";

my @output = `perl inside`;

print "not " if $? or @output < 20;
print "ok 1\n";

print "not " if -s 'ERRORS';
print "ok 2\n";

unlink 'ERRORS'; # don't worry if it fails

exit;
# Not much to test, huh?
