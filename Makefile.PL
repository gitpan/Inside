use ExtUtils::MakeMaker;

# This is part of the 'inside' program, and covered by the same license.
# Copyright (C) 2000 Tom Phoenix <rootbeer@redcat.com>
# http://www.cpan.org/authors/id/P/PH/PHOENIX/

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# We can't automate installation of a CGI program, so...
sub MY::install { '' }
sub MY::installbin { '' }

# The inside.PL file should be re-run on the target system,
# so we'll touch it at the start of distdir.
sub MY::dist_dir {
    package MY;
    local $_ = shift->SUPER::dist_dir(@_);
    s/(^distdir\s*:.*)/$1\n\t\$(TOUCH) inside.PL/m;
    $_;
}

WriteMakefile(
    'NAME'	=> 'Inside',
    'VERSION_FROM' => 'inside.PL', # finds $VERSION
    'dist'      => { 'COMPRESS' => 'gzip', 'SUFFIX' => 'gz' },
);

print "### After running 'make', install the file\n";
print "### 'inside' as a CGI program.\n";
