#!/usr/bin/perl -w

# Writes the README file for inside

# This is part of the 'inside' program, and covered by the same license. 
# Copyright (C) 2000 Tom Phoenix <rootbeer@redcat.com>
# http://www.cpan.org/authors/id/P/PH/PHOENIX/

use strict;

$ENV{COLUMNS} = 72;
my $manpage = `perldoc -t ./inside`;
die "Couldn't run perldoc; status was $?" if $? or !$manpage;

chmod 0644, "README";	# in case it's unwritable; ignore if it fails
open STDOUT, ">README"
    or die "Can't write 'README': $!";
chmod 0444, "README"
    or warn "Can't chmod README: $!";

print qq{
README file for inside

This program is available on CPAN:

    http://www.cpan.org/authors/id/P/PH/PHOENIX/

To prepare this program for your system, use a variation on the standard
incantation:

    perl Makefile.PL
    make
    make test		# this may take a moment to complete

Then, install the file 'inside' as needed for a CGI program on your
system. See your local expert if you're not sure how to do that.

If you're unable to use the standard incantation, try running the
command 'perl inside.PL' instead. Or you may need to manually fix up the
file 'inside' for use as a CGI program on your system.

From the embedded documentation:

$manpage
};

exit;
