use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# We can't automate installation of a CGI program, so...
sub MY::install { '' }
sub MY::installbin { '' }

WriteMakefile(
    'NAME'	=> 'Inside',
    'VERSION_FROM' => 'inside', # finds $VERSION
    'dist'      => { 'COMPRESS' => 'gzip', 'SUFFIX' => 'gz' },
);
