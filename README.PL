#!/usr/bin/perl -w

use strict;

# Writes the README file for inside

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

If you're unable to use the standard incantation, try running the command
'perl inside.PL' instead.

From the embedded documentation:

$manpage
};

exit;
