#!/usr/bin/perl -w

# This is NOT the CGI program 'inside'! Don't install this!

# Prepare the program 'inside' to be run on this system.

# This is part of the 'inside' program, and covered by the same license. 
# Copyright (C) 2000 Tom Phoenix <rootbeer@redcat.com>
# http://www.cpan.org/authors/id/P/PH/PHOENIX/

use strict;
use Config;

# It's gonna happen someday; you know it will...
if ($ENV{REQUEST_METHOD} or $ENV{MOD_PERL}) {
    print "Content-type: text/plain\x0d\x0a\x0d\x0a";
    print "You silly goose! This is the configuration program,\n";
    print "not the _actual_ program! Try again.\n";
    exit;
}

chmod 0644, 'inside';	# just in case it's unwritable; ignore if it fails

open STDOUT, ">inside"
    or die "Can't write to 'inside': $!";

chmod 0755, 'inside'
    or warn "Can't chmod 'inside': $!";

my $magic = q{#!$perlpath

    # Do not read this magic spell
    eval '(exit $?0)' && eval 'exec $perlpath -S $0 ${1+"$@"}'
        && eval 'exec $perlpath -S $0 $argv:q'
            if $running_under_some_shell;
    $running_under_some_shell = undef;
};

my $perlpath = $Config{perlpath} || '/usr/bin/perl';

$magic =~ s/\$perlpath/$perlpath/g;
print $magic;
print while <DATA>;
exit;

__END__

# See the POD documentation at the end of the program for
# copyright notice and other important information. It may
# be easier to read if you use the perldoc command or
# another POD viewer.

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# For those who need to tweak things, the configuration section
# follows this next section of code.

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# First off, we have to catch any antiques
if ($] < 5) {
    if ($ENV{"REQUEST_METHOD"}) {
	print "HTTP/1.0 200 OK\x0d\x0a" if $0 =~ /nph-/;
	print "Content-type: text/plain\x0d\x0a\x0d\x0a";
    }
    print "Ancient Perl detected! Upgrade at once!\n";
    print "Version info: $]\n";
}

# Black magic to prevent perl4 from parsing any further
$#_=${#_};  __END__
"%"}-1;
# end of black magic

# I want to 'use strict', but if the @INC is hosed, I can't.
BEGIN { $^H |= 0x602 } # Probably not forward-compatible!

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Configuration:

# Dirs mentioned here are added to @INC much as the 'lib' pragma does.
# For security reasons, this must be hard-coded in the script - we can't
# get this from an HTML form, for example, without potentially
# compromising security. These should be absolute pathnames, not
# relative, for CGI programming.
my @extra_dirs = qw{
};

# These are subdirs of the search dirs which shouldn't be searched any
# further. They may be absolute or relative paths. This option is
# typically used to exclude "libraries" which are really programs with
# the ".pl" extension.
my @prune_dirs = qw{
    Tk/demos
};

# This is used to catch loops in symlinks. It shouldn't need to be
# changed. (Let me know if you have to change it.)
my $max_path_len = 255;

# This is used to set up an alarm (on systems which support that) in
# case this program runs too long. It shouldn't need to be changed. (Let
# me know if you have to change it.)
my $time_out = 300;	# seconds

# These modules should be present on any machine with Perl. If one is
# missing, we'll complain. (There are lots of others that are part of
# the core, but if these are found, the others are probably there as
# well.)
my @core_modules = qw{
    strict vars lib Carp CGI
};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# No user-serviceable parts after this point

my $Id = q$Id: inside.PL,v 0.6 2001/03/22 00:16:41 rootbeer Exp rootbeer $;
my # Fooling MakeMaker
$VERSION = '1.01';

# We're not compatible with Apache::Registry, so let's keep from
# leaving mod_perl hosed. Nevertheless, it may already be too late.
BEGIN {
    if ($ENV{MOD_PERL}) {
	print "HTTP/1.0 501 Not Implemented\x0d\x0a",
	    "Content-type: text/plain\x0d\x0a\x0d\x0a",
	    "This program can't run under this Apache module.\n",
	    "Please disable it right away!\n\n";
	eval 'CORE::exit(1)';	# in case exit is redefined
	exit(1);	# in case the first didn't work
    }
}

# We'll keep an array of warnings and a hash of their explanations.
my(@warnings, %explanations);

BEGIN {
    $| = 1;

    if ($ENV{REQUEST_METHOD}) {
	print "HTTP/1.0 200 OK\x0d\x0a" if $0 =~ /nph-/;
	print "Content-type: text/plain\x0d\x0a\x0d\x0a";
    }
    print "This is the program 'Inside'.\n";
    print "    http://www.cpan.org/authors/id/P/PH/PHOENIX/\n\n";

    # I don't want warnings to screw up the output. But if they're
    # emitted at compile time, it would be wrong to hide them!
    BEGIN { $^W = 0 }  # needed for 5.004_03
    $SIG{'__WARN__'} = sub { push @warnings, "Internal warning: @_" };
    $^W = 1;

    my $all_okay;
    sub all_okay { $all_okay = 1 }
    END {
	print map "$_\n", "Warnings were:", @warnings
	    if @warnings and not $all_okay;
    }
}

my $taint_checking;
BEGIN {
    # Let's see whether taint checking is on
    my $taint = "$0$^X@ENV{ keys %ENV }@ARGV";
    return if eval {
	unlink "\0DoeS\n Not\r ExIsT\t\\\e/:.'!\0$taint";
	1;
    };
    $taint_checking = 1;
    push @warnings, q{Taint checking is turned on.};
    $explanations{taint} = q{
	Perl's taint checking feature is turned on. Either this
	program is running set-id, or someone has turned on the taint
	checks in some other way. Because of that, this program may
	(in a few cases) report some version numbers incorrectly.
    };
}

# We'll try to use File::Spec and ExtUtils::MakeMaker. But what if
# they're not available? Or not complete, in the available
# implementation?  Well, we'll set up some fake subs to take over.
# (Maybe I should be doing this for 'use strict' as well. Hmmm.)
BEGIN {
    package Fake;

    my @modules = qw/ File::Spec ExtUtils::MakeMaker /;

    my $code = q{
	sub parse_version { "unknown" }
	sub file_name_is_absolute {
	    if (($^O || '') eq 'MacOS') {
		$_[1] !~ /^:/;
	    } else {
		$_[1] =~ m#^/#;
	    }
	}
	sub no_upwards { grep !/^\.\.?(?!\n)$/, @_[1..$#_] }
	sub catfile {
	    if (($^O || '') eq 'MacOS') {
		# I hope this will still work under MacOS X
	        my @items = @_[1..$#_];
		for (@items) { s/:(?!\n)$// }
		return join ':', @items;
	    }
	    join '/', @_[1..$#_];
	}
	sub canonpath {
	    # Similar to the (buggy?) code from 5.6.0's File::Spec::Unix
	    local($_) = $_[1];
	    1 while s#(?:/\.?)+/#/#g;		# xx//./xx -> xx/xx
	    s#^\./(?=[\d\D])##;			# ./xx      -> xx
	    s#/\.(?!\n)$##;			# xx/.      -> xx
	    s#/(?!\n)$## unless $_ eq "/";	# xx/       -> xx
	    $_;
	}
    };

    sub DESTROY {
	# Don't autoload this!
    }

    # This one wasn't added to File::Spec until recently (after
    # 5.005_02), so we'll try to make our own. Should probably complain
    # about it, but that would upset too many people whose perl isn't
    # _really_ that old.  But someday we can put this in with the
    # others....
    sub case_tolerant {
	if (!$^O) {
	    # Pre-$^O antique Perl!
	    return 0;
	}
	# Is this everybody?
	my %ct_systems = map +($_,1), qw{
	    dos os2 MSWin32 cygwin MacOS VMS
	};
	$ct_systems{$^O};
    }

    for (@modules) {
	eval qq{ use $_; };
	if ($@) {
	    push @warnings, "Couldn't load vital module $_:", $@, '';
	    $explanations{vital} = q{
		A "vital" module is one which this program wants to use
		to do its work. Without it, the program will try to
		substitute its own code - but if you're missing one of
		these "vital" modules, you should probably ask that Perl
		be re-installed, since it's either an old version or not
		correctly installed. Also, of course, you're going to be
		missing some functionality in many cases.
	    };
	    # May as well avoid the AUTOLOAD
	    eval $code;
	    if ($@) {
		push @warnings, "Unexpected eval error: $@";
	    }
	    $code = '';
	}
    }

    # Set up the @ISA's
    my $pack = ref bless {}; # __PACKAGE__
    for (\@File::Spec::ISA, \@MM::ISA) {
	push @$_, $pack
	    unless grep $_ eq $pack, @$_;
    }

    sub AUTOLOAD {
	# Dang; something's not supported
	my $func_name = eval {
	    BEGIN { $^H &= ~0x0400 }	# no strict 'vars'
	    $AUTOLOAD;
	};
	$func_name =~ s#.*::##;
	if ($code) {
	    eval $code;
	    if ($@) {
		push @warnings, "Unexpected eval error: $@";
	    }
	    $code = '';
	    unless (defined &$func_name) {
		# Well, we're in an eval, right?
		die "Missing emulated function $func_name";
	    }
	    unless (
		$explanations{vital} or $explanations{missing_func}
	    ) {
		push @warnings, "Missing functionality " .
		    "($func_name) in vital module";
		$explanations{missing_func} = q{
		    When a "vital" module is missing functionality, you
		    generally have an older (or buggy) installation of
		    Perl. This program will substitute its own code, but
		    the replacement routines may not be correct on your
		    system. You should get a recent version of Perl
		    installed (or properly installed) to correct this
		    problem.
		};
	    }
	    goto &$func_name;
	} else {
	    die "Missing function $func_name";
	}
    }

}

# pretty(STRING) will be a bareword if that'll be clear; otherwise
# it's wrapped in perlish quotes as needed.
sub # This works around a bug in 5.004_01
BEGIN {
    my %dq;	# How to encode a given char in double quotes
    $dq{'"'} = '\\"';
    $dq{'$'} = '\\$';
    $dq{'@'} = '\\@';
    $dq{'\\'} = '\\\\';
    $dq{"\t"} = '\\t';
    $dq{"\r"} = '\\r';
    $dq{"\n"} = '\\n';
    $dq{"\f"} = '\\f';
    $dq{"\e"} = '\\e';
    $dq{"\b"} = '\\b';
    $dq{"\a"} = '\\a';

    sub pretty {
	local $_ = shift;
	return "the undefined value" unless defined;
	return "''" unless length;
	return $_ unless tr{A-Za-z0-9_}{}c;
	return $_ if 	# it's just a number
	    /^[+-]?(?=\d|\.\d)\d*(?:\.\d*)?(?:[Ee][+-]?\d+)?(?!\n)$/;
	if (tr/\0-\x1f\x7f-\xff// or (tr/'// and not tr/"//)) {
	    # It's got a single quote, control character, or
	    # other special character - better use double quotes
	    # I hope I don't have to worry about Unicode or EBCDIC!
	    s{([\\"\$\@\0-\x1f\x7f-\xff])}{
		$dq{$1} ||= "\\x" . unpack "H2", $1;
	    }ge;
	    qq{"$_"};
	} else {
	    # It's simple - use single quotes
	    s{(['\\])}{\\$1}g;
	    qq{'$_'};
	}
    }
}

sub indent {
    # Poor man's q&d word wrapping
    local $_ = join "\n", @_;
    s/\s+/ /g;
    s/^\s+//;
    s/\s+$//;
    s{\G(?!.{1,65}$)(.{1,65})\s+}{$1\n}g;
    s/^/    /mg;
    $_;
}

BEGIN {
    my $time = time;
    my $update_gap;

    sub update {
	# Periodically inform the user of progress
	return if $time == time;
	my $ref = shift;
	my $count = keys %$ref;
	return if $count < 50;	# arbitrary lower bound
	printf "%5d modules found, continuing...\n", $count;
	$time = time;
	$update_gap = 1;
    }

    sub update_gap {
	print "\n" if $update_gap;
    }
}

my $is_unix;
BEGIN {
    # Is this a Unix system? Or enough like one that we'll be able to
    # use permission bits?
    if ($^O) {
	for (qw/
	    dos os2 MSWin32 cygwin MacOS VMS VOS
	    os390 os400 posix-bc vmesa riscos
	    amigaos mpeix
	/) {
	    return if $^O eq $_;
	}
    }

    return unless eval {
	local $^W = 0;	# no warnings if any of these are undef

	return		# fix bug in some perls
	-d '/dev' and
	(stat _)[2] & 0557 == 0555 and	# all can read and exec /dev, 
					# others can't write to it
	!-f '/dev/null' and
	-z _ and
	(stat _)[2] & 0777 == 0666 and	# it's r/w (no x) for everyone

	-s '/bin/sh' and 
	(stat _)[2] & 0113 == 0111 and	# x by all, not w by others

	kill 0, $$;
    };
    # Okay, that looks Unixish
    $is_unix = 1;
}

{
    my %memo; # Cache for the already-seen paths

    sub has_safe_path {
	# Check that every piece of the path is writable only by root.
	# This is called only on Unix systems.
	return unless my $full_path = shift;
	my @pieces = grep length, split '/', $full_path;
	my $path_so_far = '/';
	while (1) {
	    next if $memo{$path_so_far};
	    return if exists $memo{$path_so_far};
	    my($dev, $ino, $mode, $nlink, $uid, $gid)
		= stat $path_so_far;
	    my $reason;
	    if (!defined $uid) {
		$reason = "Can't stat: $!";
	    } elsif ($uid) {
		my $uname = eval { $uid . '/' . getpwuid $uid } || $uid;
		$reason = "Owned by non-root user $uname";
	    } elsif ($gid and $mode & 020) {
		my $gname = eval { $gid . '/' . getgrgid $gid } || $gid;
		$reason = "Writable by non-root group $gname";
	    } elsif ($mode & 002) {
		$reason = "World-writable";
	    }
	    if ($reason) {
		push @warnings,
		    "Possibly unsafe path found for " .
		    "'$path_so_far' ($reason)";
		$explanations{unsafe_path} = q{
		    An unsafe path to a file or directory means that the
		    item could potentially be modified by another user on
		    your system than the system administrator. This
		    shouldn't happen except in regard to your own private
		    module directories, in which case it's harmless. But
		    it is a potential security hole if an untrusted user
		    could modify these modules or install new ones. Check
		    with your local expert if you're not sure.
		};
		return $memo{$path_so_far} = undef;
	    }
	    $memo{$path_so_far} = 1;
	} continue {
	    return 1 unless @pieces;
	    if ($path_so_far eq '/') {
		$path_so_far = '/' . shift @pieces;
	    } else {
		$path_so_far .= '/' . shift @pieces;
	    }
	}
    }
}

sub match {
    # Returns the middle of a string whose beginning and end
    # are given. If there's no match, returns false. The end
    # may be omitted.
    my($string, $start, $end) = @_;
    $end = '' unless defined $end;
    my $start_len = length $start;
    return unless substr($string, 0, $start_len) eq $start;
    return substr $string, $start_len
	unless my $end_len = length $end;
    return unless substr($string, -$end_len) eq $end;
    return substr $string, $start_len, -$end_len;
}

sub extract_version {
    # Report a module's version number
    my $file_name = shift;
    my $version;
    if ($is_unix and not $taint_checking) {
	# we only check for a safe path if it's unix without taint
	if (has_safe_path($file_name)) {
	    $version = eval {
		MM->parse_version($file_name);
	    } || 'unknown';
	};
    }

    # Non-unix or taint-checking or not safe path - do it the hard way
    unless (open FILE, "<$file_name") {
	push @warnings, "Can't open module '$file_name': $!";
	$explanations{cant_open_module} = q{
	    When you can't open a module to determine its version
	    number, this usually means that the permission bits
	    aren't set correctly. That will generally prevent you
	    from being able to use the module as well. Often, your
	    system administrator will need to fix this.
	};
	return;
    }

    my($code, $inpod);
    while (<FILE>) {
	$inpod = /^=(?!cut\b)/ ? 1 : /^=cut\b/ ? 0 : $inpod;
	next if $inpod;
	chomp;
	if (/^(.*?)([\$*][\w:']*\bVERSION\b)(?:\s*=\s*\2\s*)?(.*=.*)/) {
	    my($skipped, $value) = ($1, $3);
	    if ($skipped =~ /^\s*#/) {
		# It's a comment, not a version
	    } else {
		# The substr() keeps the taintedness on $code, in case
		# we're (unadvisedly) using taint checking.
		$code = $value . substr($_, 0, 0);
	    }
	    last;
	}
    }
    close FILE;
    return unless defined $code;

    local $_ = $code;
    # Strip unneeded spaces (to simplify matches below)
    # This algorithm isn't perfect, so we may need to
    # detect some exceptions by matching on $code before
    # doing the main tests on $_
    s/\s+([][#;\$={}(),]\S*)\s*/$1/g;
    s/([][={}(),])\s+/$1/g;
    s/\s+/ /g;	# Condense any remaining spaces

    if (/^=(["']?)([\d[_\d]*(?:\.[_\d]*)?)\1(?:[#;]|$)/) {
	# $VERSION = 1.234;
	if ($1) {
	    # Quoted, so it's a string (keep trailing zeroes!)
	    $version = $2;
	} else {
	    # Not quoted, so it ought to be a number
		$version = eval {
		    local $^W = 0;	# No warn on bad num-to-str
		    (my $num = $2) =~ tr/_//d;	# strip underscores
		    0 + $num;
		};
	}
    } elsif (/^=(["'])[^"']+\1;/) {
	# $Pg::VERSION = '1.8.0';
	# But maybe we've mangled it, so get it from the original
	if ($code =~ /^\s*=\s*(["'])([^"']+)\1;/) {
	    $version = $2;
	}
    } elsif (/=substr[ (]q\$\x52evision: 0.3 \$,10\)?(\+0)?;/) {
	# I have to write 'Revision:' that way, so that RCS doesn't keep
	# "fixing" my code every time I check in these sources.
	# $VERSION = substr q$\x52evision: 0.3 $, 10;
	if ($2) {
	    # Force numeric
	    $version = eval {
		local $^W = 0;	# No warning on bad numbers
		$1 + 0;
	    };
	} else {
	    $version = $1;
	}
    } elsif (/=substr\(q\$[^\$]+\$,(\d+)(?:,(-?\d+))?\)(-\d+)?;/) {
	# $VERSION = substr(q$\x52evision: 5.3 $, 9,-1) -1;
	my($start, $len, $offset) = ($1, $2, $3);
	$len = 9999 unless defined $len;
	$offset = 0 unless defined $offset;
	if ($code =~ /q\$([^\$]+)\$/) {
	    $version = eval {
		local $^W = 0;	# No warning on bad numbers
		substr($1, $start, $len) + $offset;
	    };
	}
    } elsif (
	m#^=sprintf[ (](["'])[^"']+\1,q\$[^\$]+\$=~ ?/([^/]+)/\);#
    ) {
	# $VERSION = sprintf("%d.%02d", 
	# q$\x52evision: 0.3 $ =~ /(\d+)\.(\d+)/);
	my $pattern = $2;
	if (
	    $code =~ /sprintf[\s(]*(["'])([\w%.]+)\1,\s*q\$([^\$]+)\$/
	) {
	    my($format, $ver) = ($2, $3);
	    if ($pattern eq '(\\d+)\\.(\\d+)') {
		$version = sprintf $format, $ver =~ /(\d+)\.(\d+)/;
	    } elsif ($pattern eq '(\\d+\\.\\d+)') {
		$version = sprintf $format, $ver =~ /(\d+\.\d+)/;
	    }
	}
    } elsif (
	/=do\{my ?\@\w+=\(?q\$[^\$]+\$=~ ?\/\\d\+\/g\)?;(.*)/
    ) { # \}
	# Original was one line, of course....
	# $VERSION = do { my @a=q$\x4Eame: foobar 1.5 $ =~ /\d+/g;
	# sprintf "%d." . ("%02d" x $#a ),@a };
	my $rest = $1;
	if (
	    $rest =~ /(["'])%(\d*)d\.\1 ?\. ?\(?(["'])%02d\3\s*x\$#\w+/
	) {
	    my $width = $2;
	    if ($code =~ /q\$([^\$]+)\$/) {
		my @d = $1 =~ /\d+/g;
		$version = sprintf "%${width}d." . "%02d" x $#d, @d;
	    }
	}
    } elsif (/^=\(qw\$[^\$]+\$\)\[(\d+)\];/) {
	# $VERSION = (qw$\x52evision: 0.3 $)[1];
	# clever...
	my $which = $1;
	if ($code =~ /qw\$([^\$]+)\$/) {
	    $version = (split /\s+/, $1)[$which];
	}
    } else {
	# Okay, these are the weird ones:
	my $middle;
	if (
	    $middle = match($code,
		q{ = (split (' ', },
		q{))[1]) =~ s/\.(\d)$/.0$1/;} )
	) {
	    # ($VERSION = (split (' ', q$\x52evision: 0.3 $
	    # ))[1]) =~ s/\.(\d)$/.0$1/;
	    # Like that's not gonna break
	    if ($middle =~ /q\$([^\$]+)\$/) {
		my $ver = $1;
		($version = (split(' ', $ver))[1]) =~ s/\.(\d)$/.0$1/;
	    }
	} elsif (
	    $code eq q{ = sprintf '%5.3f', (1 * 100 + (22))/1000;}
	) {
	    # $VERSION = sprintf '%5.3f', (1 * 100 + (22))/1000;
	    # When good programmers do drugs...
	    $version = 0.122;
	} elsif ($code eq q{ = $Net::DNS::VERSION;}) {
	    # It really says that!
	    $version = 'undef';		# That's what you get.
	} elsif ($code eq q{ = $Revision) =~ s/.*(\d+\.\d+).*/$1/;}) {
	    # They did it again
	    $version = 'undef';
	} elsif ($code eq q{=$revision)=~s/.*(\d+\.\d+).*/$1/;}) {
	    # A little variety
	    $version = 'undef';
	} elsif (
	    $code eq q{) = $rcs =~ /Id: LTU\\.pm.* ([\\d\\.]+) /;}
	) {
	    # That's useless
	    $version = 'undef';
	}
    }

    # Strip leading and trailing spaces from the version
    if ($version) {
	$version =~ s/^\s+//;
	$version =~ s/\s+$//;
    }

    $version;
}

# The main program starts here
my @info;
eval {
    # Let's be safe, and set up an alarm. If it's not implemented,
    # oh well! But this could keep us from hanging in an infinite
    # loop, if there's a bug somewhere....
    eval q{
	$SIG{ALRM} = sub { die "Alarm clock" };
	alarm $time_out;
    };

    # Are our filesystems case sensitive?
    my $case_insensitive = File::Spec->case_tolerant;
    # This is for use in patterns
    my $opt_i = $case_insensitive ? '(?i)' : '';

    push @info, "Basic information about this system:";
    push @info, "    Perl version: $]";
    push @info, "    Binary location: " . ($^X || "unknown");
    push @info, "    OS-name: " . ($^O || "unknown");
    push @info, "    Unix system: " . 
	($is_unix ? 'yes' : 'no');
    push @info, "    Case-tolerant filenames: " .
	($case_insensitive ? 'yes' : 'no');
    push @info, "    Current local time: " . localtime $^T;
    push @info, "        Universal time: " . gmtime $^T;
    push @info, "    This program's version: $VERSION";
    push @info, "    This program's name on this system: " .
	($0 || "unknown");
    push @info, "    Taint checking: " .
	($taint_checking ? 'on' : 'off');
    push @info, '';

    if ($] < 5.004) {
	push @warnings, "Perl version $] has security problems";
	$explanations{very_old_perl} = q{
	    Perl releases prior to version 5.004 all have known security
	    problems, and should no longer be used on machines connected
	    to the Internet. In particular, remote users may be able to 
	    crash your system, read all of your files, and use your
	    machinery to attack other systems. Tell your administrator
	    to replace this old Perl version at once. See www.cert.org
	    for more information.
	};
    }

    {
	# We use "'unknown'" in quotes here so as to distinguish it
	# from a username/groupname of "unknown". It could happen!
	my $uid = eval q{ getpwuid $< } || "'unknown'";
	my $euid = eval q{ getpwuid $> } || "'unknown'";
	my $gid = $(;
	my $egid = $);
	for ($gid, $egid) {
	    s{(\d+)}{ eval q{ getgrgid $1 } || "'unknown'" }ge;
	}
	push @info, "User and group info for this process:";
	push @info, "     UID: $uid ($<)";
	push @info, "    EUID: $euid ($>)";
	push @info, "     GID: $gid ($()";
	push @info, "    EGID: $egid ($))";
	push @info, '';
    }

    push @info, "Current environment variables:";
    push @info, map "    $_: " . pretty($ENV{$_}), sort keys %ENV;
    push @info, '';

    push @info, "\@INC contains:", map "    $_", @INC;
    push @info, '';

    if (@extra_dirs) {
	push @info, "User-supplied extra dirs are:",
	    map "    $_", @extra_dirs;
	push @info, '';
    }

    # Now let's find the modules and libraries
    my @search_dirs;

    {
	my @omitting;
	for (@extra_dirs, @INC) {
	    if (File::Spec->file_name_is_absolute($_)) {
		push @search_dirs, $_;
	    } else {
		push @omitting, $_;
	    }
	}
	last unless @omitting;
	push @warnings,
	    "Relative paths can't be used reliably for CGI programs.";
	$explanations{relatives} = q{
	    The CGI specification doesn't tell which directory will be
	    the current working directory when a CGI program is
	    executed.  Because of that, CGI programs shouldn't use
	    relative paths for finding modules; use absolute paths
	    instead. It's normal (and generally harmless) to see that
	    the relative path for the current directory ('.') is
	    included in the @INC list.
	};
	if ($ENV{REQUEST_METHOD}) {
	    push @warnings,
		"The following relative paths were ignored:",
		    map "    $_", @omitting;
	} else {
	    push @warnings, "Nevertheless, the following " .
		"relative paths were checked:",
		    map "    $_", @omitting;
	    # We're not really omitting them, then, are we?
	    @search_dirs = (@extra_dirs, @INC);
	}
	push @warnings, '';
    }

    # At this point, by all logic, net.wisdom, and common sense, I
    # should be using File::Find. Why am I not? I've got two reasons:
    #
    # 1. Until quite recently (2000), File::Find couldn't follow
    # symlinks, but if you have a symlink in one of the @INC paths, it
    # still works for finding the libraries and modules. Plenty of
    # systems will have the older File::Find for the near future.
    #
    # 2. Okay. That was my only reason. But it's still a good one.

    my(%seen, %module, @libraries, %lc_module);

    # Keys of %seen are either $dev/$ino pairs (on systems which use
    # distinct such pairs) or the canonical filename (on other systems).
    # Note that using a filename like this could potentially cause an
    # infinite loop if the canonicalization routine is messed up. :-P
    # Thus the need for $max_path_len.
    my $use_filenames = 1;

    # We should fix %seen so that we don't follow
    # prunable directories
    {
	my @which_dirs = @search_dirs;
	my $prune;
	for $prune (@prune_dirs) {
	    if (File::Spec->file_name_is_absolute($prune)) {
		push @which_dirs, $prune;
	    } else {
		push @which_dirs,
		    map File::Spec->catfile($_, $prune),
			@search_dirs;
	    }
	}

	# Do we have distinct dev/ino values? If we find two different
	# non-zero inodes, we'll say yes... Note that we're searching in
	# other places besides the expected dirs, which should reduce
	# the chance of mistakes.
	my $orig_ino;
	for (@which_dirs, '/dev/null', '/dev/zero', $^X, $0) {
	    next unless defined and length;
	    my($dev, $ino) = stat or next;
	    if ($orig_ino) {
		next if $ino == $orig_ino;
		$use_filenames = 0;
		last;
	    } else {
		# Stash it for later comparison
		$orig_ino = $ino;
	    }
	}

	for (@which_dirs) {
	    next unless my($dev, $ino) = stat;
	    my $id = $use_filenames
		? File::Spec->canonpath($_)
		: (($dev || 0) . ',' . ($ino || 0));
	    $seen{$id} = -10000;
	}
    }

    # This sub searches recursively (following symlinks and all) for
    # whatever modules and libraries it can find. For each one, it
    # stores some info into the %module hash. Naturally, it also files
    # away libraries, warnings, and explanations as needed.
    sub do_search {
	my($current_dir, $base_dir, @pieces) = @_;
	local $_;	# Just in case
	$base_dir ||= $current_dir;
	my $shortcut = $base_dir;	# for now...
	unless (opendir DIR, $current_dir) {
	    push @warnings, "Can't opendir '$current_dir': $!";
	    $explanations{'opendir'} = q{
		When you can't open a directory with opendir, this
		generally means that you have given the wrong name or
		that the directory has incorrect permissions set. This
		can generally be fixed by the owner of the directory or
		the system administrator.  Of course, if you don't need
		what's inside, it's probably harmless.
	    };
	    return;
	}

	# Why is this called 'no_upwards'? That's a lousy name.
	# In fact, all of the File::Spec names are bad.
	my @children = File::Spec->no_upwards(readdir DIR);
	closedir DIR;
	my $child;
	for $child (@children) {
	    my $full_name = File::Spec->catfile($current_dir, $child);
	    my($dev, $ino) = stat $full_name;
	    my $id = $use_filenames
		? File::Spec->canonpath($full_name)
		: (($dev || 0) . ',' . ($ino || 0));

	    if (not defined $dev) {
		push @warnings, "Can't stat '$full_name': $!";
		$explanations{'stat'} = q{
		    When you can't stat something, that's often a
		    permissions problem. If you need what's inside,
		    you're hosed. Ask your local expert.
		};
	    } elsif ($seen{$id}++) {
		if ($seen{$id} < 0) {
		    # It's ignorable
		} else {
		    push @warnings,
			qq{Item seen $seen{$id} times: $full_name};
		    $explanations{seen} = q{
			When an item is seen more than once, that may mean
			that symbolic links have created a loop. That
			should be fixed, probably by your admin. But it's
			more likely that you have multiple paths to the
			same item, which is generally harmless.
		    };
		}
	    } elsif (
		$use_filenames and length($full_name) > $max_path_len
	    ) {
		# What do we do about loops in symlinks? Well, if we can
		# get a dev/ino, that'll solve that. But, on other
		# systems, if the total path is too long, we'll
		# complain. Since it's monotonically increasing, either
		# we or the system have to catch it.
		push @warnings, "Path too long: $full_name";
		$explanations{too_long} = q{
		    When a path is too long, that may mean that symbolic
		    links (or your system's equivalent) have formed a
		    loop.  If you simply have very long filenames, well,
		    you probably shouldn't.
		};
	    } elsif (-d _) {
		do_search($full_name, $base_dir, @pieces, $child);
	    } elsif (-f _ and $child =~ /$opt_i\.(p[ml])(?!\n)$/o) {
		# it's a module (or library)!
		if (lc($1) eq 'pm') {
		    # Module
		    my $mod_name = join "::", @pieces, $child;
		    $mod_name =~ s/\.pm$//i;
		    if ($module{$mod_name}) {
			push @warnings, 
			    "Extra copy of module $mod_name " .
				"found in $shortcut";
			$explanations{extra_copy} = q{
			    When there's an extra copy of a module, only
			    the first one (along the @INC paths at compile
			    time) is usable. This is harmless unless you
			    want a different one than you're getting. You
			    can use the 'lib' pragma to change the @INC
			    path at compile time.
			};
		    } else {
			# Determine the version.
			my $version = extract_version($full_name)
				|| "unknown";
			$module{$mod_name} = 
			    qq{$mod_name (version $version) } .
				qq{found in $shortcut};
			update(\%module);
			if ($lc_module{lc $mod_name}++) {
			    push @warnings,
				"Same-named module $mod_name found " .
				    "in $shortcut";
			    $explanations{same_name} = q{
			        A "same-named" module is one whose name is
				identical to another, except for
				capitalization. In most cases, this means
				that at least one of them is
				mis-installed. On at least some systems,
				only the first of these modules will be
				usable, if it works at all.
			    };
			}
		    }
		} else {
		    # Library
		    my $lib_name =
			File::Spec->catfile(@pieces, $child);
		    push @libraries,
			qq{Library "$lib_name" found in $shortcut};
		}
	    } else {
		# Ignore any non-module files, sockets, pipes, etc.
	    }
	}
    }

    # Do the search
    for (@search_dirs) {
	do_search($_);
    }

    push @info, "Number of unique modules and pragmas: " . keys %module;
    push @info, "Number of libraries: " . @libraries;
    push @info, '';

    push @info, "Pragmas:";
    for (sort grep substr($_, 0, 1) =~ tr/a-z//, keys %module) {
	push @info, $module{$_};
    }
    push @info, '';

    push @info, "Modules:";
    for (sort grep substr($_, 0, 1) !~ tr/a-z//, keys %module) {
	push @info, $module{$_};
    }
    push @info, '';

    push @info, "Libraries:";
    push @info, @libraries;
    push @info, '';

    {
	my @missing = grep !$module{$_}, @core_modules;
	last unless @missing;
	$explanations{core_missing} = q{
	    When a core module is missing, your Perl installation is
	    either old or damaged. Many programs and other modules will
	    not be able to work properly. You should ask your admin to
	    (re)install a recent version of Perl.
	};
	if (@missing > 1) {
	    push @warnings, '', "Some core modules are missing:",
		map "    $_", @missing;
	} else {
	    push @warnings, '', "The @missing core module is missing.";
	}
    }

    push @info, '', "Some warnings were produced:",
	map "    $_", @warnings
	    if @warnings;

    push @info, '', "Notes about the warnings:",
	map +('', indent($_)), values %explanations
	    if %explanations;

    eval { 0 };	# work around a bug in 5.005_02
};

if ($@) {
    print "An unexpected error occurred:\n$@\n";
    all_okay();		# don't print out the warnings
} else {
    update_gap();
    print map "$_\n", @info;
    all_okay();		# don't print out the warnings again
    print "\n";
    my $start;
    BEGIN { $start = time }
    my $real_seconds = time - $start;
    my($cpu_seconds) = eval { sprintf "%.1f", scalar times } || 'unknown';
    print "Done in $real_seconds seconds ($cpu_seconds CPU seconds).\n";
}

__END__
=for your information

This text is in POD format. You should be able to read it with the
perldoc command, or any other POD reader. 

=head1 NAME

Inside - Find out what's inside your Perl installation

=head1 DESCRIPTION

This program will try to report which Perl modules are available on
your machine, along with some other useful information. Although it's
especially made to be helpful to CGI programmers, it may be of use to
other Perl users as well.

Note that I've done more than a few weird things in this code in order
to make it work in some odd surroundings. The right thing to do in
general is to fix the broken environments, rather than to work around
them. But since the purpose of this program is to diagnose some of
those broken environments, I'm breaking the rules. In short: Don't Do
As This Code Does! Use the accepted techniques, instead.

You should be able to run this program on nearly any machine which has
Perl, either as a CGI program or stand-alone, although not under
Apache/mod_perl's non-CGI environments, like Apache::Registry or
Apache::PerlRun. (The ordinary Apache CGI environment is fine, whether
mod_perl is installed or not.) The only(?) thing which should B<need>
changing in the program text is the location of perl in the #!-line, the
first line of the program. There's also a small Configuration section
near the top of the source, if you really need to have something to
fiddle with.

Of course, if you're installing this program on a webserver, your local
expert may need to help you to get it running. Don't ask me to do it!
:-)

=head1 FAQ

=over 4

=item * I can't get it to work! What's wrong?

This program tries hard to work in any normal environment, but it may be
damaged or misinstalled. If you can run it in a shell (as opposed to
running it as a CGI program) you may get more information about what is
happening. Check the perldiag manpage for the meaning of any diagnostic
messages from perl.

If you get an error about an "Illegal character", you probably didn't
use text mode ("ASCII mode") to transfer the source from one machine to
another. Try again, see the perldiag manpage for more help, or ask your
local expert.

If the error message says that "Setting locale failed", check what the
perllocale manpage tells you to do to fix your setup.

If it seems to run and produces no output from the command line, check
that you didn't run the configuration program 'B<inside.PL>' rather than
the real program 'B<inside>'.

If the error message in MacPerl complains that it "Can't emulate
-{symbol} on #! line", or if the program mysteriously doesn't run at
all, you probably didn't use text mode ("ASCII mode") to transfer the
source to the Mac. Try again or ask your local expert.

When you're having trouble with a CGI program in Perl, here's a handy
troubleshooting guide to get you back on track. 

    http://www.smithrenaud.com/public/troubleshooting_CGI.html

If you're running the most recent version of this program and you're
still stuck after using the CGI troubleshooting guide (if appropriate),
working with your local expert, and thinking about it overnight, then
you may try asking about it in the newsgroup comp.lang.perl.modules
B<or> writing to me. B<Don't> send me this entire program or its output
unless I ask for it! If you've got something long you wish for me to
see, put it on the web and send me B<just> the URL.

=item * Where can I get the most recent version of this program?

It should be available on CPAN.

    http://www.cpan.org/authors/id/P/PH/PHOENIX/

=item * Why doesn't this program work with Apache/mod_perl?

It does. But this is a CGI program, and Apache::Registry and similar
modules don't really use CGI. They're a little different, so as to give
certain benefits to some programs. This program couldn't use any of
those benefits, even if it could be made compatible with those modules.
In particular, it wouldn't run any faster, since nearly all of its time
is spent in doing I/O. And are you going to call this program hundreds
of times every second? I hope not!

Simply run this as a normal CGI program, and Apache/mod_perl will be
happy with it. If you're not sure how to do that on your machine, check
with your local expert.

=item * Why did you write this program?

There are other solutions to this problem. I didn't like them.  Finding
the installed modules is actually a complex problem.  Most proposed
solutions have a number of false positives or false negatives (this one
has both; see the rest of this FAQ for details). Some proposed solutions
use obfuscated or incorrect code, or don't work on the web with all
standard web servers and browsers. This program also has the advantage
of this FAQ and (I hope) clear diagnostic messages about problems it
may encounter.

=item * Why can't I use module ____? This program says it's there.

This may be a "false positive".

This program can't tell whether a module is B<properly> installed. (The
only way to do that is to load and test the module. Figuring out how to
test an arbitrary piece of code for proper functioning is provably
impossible, so I decided not to try.)

Of course, maybe the module is properly installed, but you're simply
using it incorrectly. Stop doing that.

A proper module should be distributed with tests which you can (and
should) use before installing it. If your installed modules won't pass
the tests, you should almost certainly (ask your administrator to)
rebuild and reinstall that module, ensuring this time that it does pass
the tests.

One possible error is that you may have used the wrong capitalization in
the C<use> declaration. Check the module's documentation to see how to
use it. Neither C<use Cgi;> nor C<use cgi;> will properly start up the
CGI module.

=item * Why doesn't this program find all of my modules?

This may be a "false negative".

The "missing" module is not installed (or not B<properly> installed) in
one of the search directories. Those directories are the ones from
Perl's compiled-in @INC variable (possibly modified by an environment
variable) and the extra directories whose names are included in the
source of this program.

You probably want to add your private module/library directory to the
@extra_dirs list, in the Configuration section of this program. Also see
what the Perl FAQ says about keeping your own module/library directory.

=item * How can I include my own module/library directory?

Add them to the @extra_dirs list, in the Configuration section. There is
a similar question in the Perl FAQ, which is worth reading.

=item * Can't I specify search directories with a web form?

No. For security reasons, the directory list must be hard-coded. 

=item * But I want my users to be able to specify their own directories!

Why? They can look in their own directories any time they want, can't
they? If they want to install their own copy of this program, they can
configure it to their needs. 

If you still want this, you probably don't understand the security
implications. 

=item * How can I find out about module dependencies?

Determining which modules are needed by which other modules is B<far>
beyond the scope of this program.

There's no way to find module dependencies which always works. But any
good module should check for its own dependencies at installation time.
If you use the CPAN module to install and upgrade modules, it can help
you with this.

Similarly, if a program needs a module which isn't supplied with perl,
this should be made clear in the program's README file, or equivalent.

=item * How can I automate installing a bunch of modules?

Some folks want to find out which modules are installed so as to
automate installing those again on a new system, or with a new version
of Perl.  This program isn't intended to help with this. See the CPAN
module's C<autobundle> function, instead.

=item * I copied some of your code to my own program, but...

Don't do that! I break lots of rules in this program, because I have
good reasons and I know what I'm doing. You don't have good reasons, and
you don't know what you're doing. :-)

=item * Why does the version number for module ____ come out wrong?

For the same reason that so many version numbers are "unknown".

=item * Why do so many modules show the version number as "unknown"?

There are several possible reasons. But if you don't have a warning that
gives another reason, it may be because the module author hasn't
included the version number in the standard format. See the docs for
ExtUtils::MakeMaker, in the section on VERSION_FROM. But (for technical
reasons) this code can't be as smart as ExtUtils::MakeMaker, so it will
sometimes get the version number wrong or not get it at all. 

B<Technical note:> Okay, if you must know. ExtUtils::MakeMaker actually
runs some of each module's code in order to determine its version. That
could be a security hole, if the module might contain rogue code. I'm
not going to take the chance. Version numbers aren't that hard to find
out on your own. 

If you're a module author and this program doesn't do as well as 
ExtUtils::MakeMaker at determining your module's version number, please
cook up a fix. Preferably, to your module, rather than to this program.
:-)

=item * Why are so many programs listed as "Libraries"?

Your programs are using the file extension ".pl", which means "Perl
Library". On many systems, extensions for programs aren't needed and
shouldn't be used. If you B<must> have an extension on your program
names, it's best to set up your system to use ".plx", which means
"Perl Executable", then use that extension instead. 

This seems to be a losing battle, since ActiveState (and others?)
strongly encourage the use of the wrong extension.

If you wish to keep some of these from showing up, add a directory or
file path to the @prune_dirs array (in the Configuration section).
Unless you have both libraries and programs in the same directory (yet
another reason for different extensions!) you can simply list directory
names to exclude them and their contents. But listing a program won't
hurt you any, if you know it's not a library.

=item * Why does it take so long to run?

This program may take perhaps more than a minute to run, depending upon
your system's load, the number of modules installed, and so on. It's
gathering a lot of information about your system! If you're installing
it as a CGI program, you may be able to make it work as an NPH-program.
(This is no faster, but it does produce some output sooner, for the
benefit of you impatient folks.) Set it up just like any other CGI
program, but make sure that the first four characters of the file's name
are "nph-", adjust the URL accordingly, and it should work
automatically. If it doesn't make any difference, well, then you just
have to wait for the output, that's all.

=item * Why does it run faster after the first time?

Much of the overhead of running this program is I/O. Probably your
system has cached the information which it read off of your filesystem.
Try again after some time, and it will be like the first time again.

=item * Why do the "modules found" messages at the top always differ?

There are some things man was not meant to know.

=item * Is there any way to configure this program to ____?

Sometimes folks want to turn part of the output on or off. Maybe they
want to put their own URL into the output. Maybe they want to change
something else.

Well, you probably can't. This program is more like a stethoscope than
an ultrasound machine. It doesn't have a lot of dials and knobs.

See the intentionally-small "Configuration" section of the program,
though, if you really wish to tweak something.

Please, see the license and disclaimer before you change any code.

=item * Why doesn't it find modules relative to the current directory?

When it's run over the web (that is, as a CGI program) this program will
ignore relative paths. (These are directory paths which don't start with
a slash, on Unix. On other systems, there may be other kinds of relative
paths, but all relative paths start from the "current working
directory".)

The current working directory is not part of the CGI specification.
Since a CGI program can't rely upon it, it must always change to a
non-relative directory before it can safely use a relative path. (A
future version of the CGI spec may change this - but that won't help
existing programs and webservers.)

=item * But I use C<chdir> before I load modules!

You probably aren't doing that correctly. If you B<do> know enough to do
this correctly, I can instruct you no further here.

Anyone else, just use absolute paths in @INC, and in the @extra_dirs.

=item * Is this program vulnerable to any security problems?

Every program is. See the disclaimer elsewhere in the
documentation. 

One possible problem, which is beyond the scope of this program to
fix, is a Denial of Service ("DoS") attack. Briefly, this program
takes time to run. If someone were to set up other computers to call
this program over the web as frequently as possible, your webserver 
could become very slow for all legitimate users. But this can happen,
to some extent, with any program that remote users can run - even
with your webserver itself.

If you worry about DoS attacks using this program, simply disable 
it whenever you're not using it. On most Unix-type webservers, that's
easy to do by using chmod(1) to set the permissions to 0. On some
webservers, you may need to change the name or remove the program 
entirely. See your local expert for details. No, you can't enable
or disable it over the web - that would defeat the purpose, wouldn't
it?

=item * Why don't you use warnings and 'use strict' and....?

Because this program is purposefully written in a way which will work
around various system (mis)configurations. And actually, barring
quirks in some future version of perl, I am using warnings and 'use
strict'. You just might not be able to see how I'm doing it. :-)

=item * Why aren't you using taint checking?

This program shouldn't need that to be secure. A program without taint
checks can be secure, just as one with them can be unsafe. 

When taint checks aren't used, we may use Perl's eval() function on a
string from another module. Since we first check that the module is
owned and writable only by the system administrator, this doesn't open
up any new security hole. (If your installed modules aren't safe,
though, it opens up that existing security hole. :-)  That is to say,
this technique is no more insecure in general than B<using> the
modules installed on your system.

If you wish to use taint checking, it can be enabled in the usual way, 
by adding the '-T' option to the $# line at the top of the program. 
Just know that when taint checks are enabled, you may not be able to
determine the version numbers of some modules. Rarely, you may get
incorrect version numbers from a few modules.

=item * Why doesn't this work with perl4?

Do you remember when O. J. Simpson was known primarily as an ex-football
player who made TV commercials? Perl 4 is older than that. Give it up.
It's dead. Besides, such old perl can't use modules anyway!

=back

=head1 COPYRIGHT, DISCLAIMER, AND LICENSE

Copyright (C) 2000 by Tom Phoenix <rootbeer@redcat.com>. 

THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

This program is free software; you can distribute it under the same
terms as Perl itself. I don't recommend modifying it or distributing
variant versions. In fact, I discourage modifying it, unless you're sure
you know what you're doing. And if you do modify something, make sure
that you've clearly labeled whatever you've done. On the other hand, if
you come up with a cool or useful modification, let me know. And don't
forget to periodically check CPAN for updates.

    http://www.cpan.org/authors/id/P/PH/PHOENIX/

Be cautious that, if you modify this code in any way, you do not
introduce security holes. Although I have, to the best of my knowledge
and ability, made this program as safe as is practicable, it may have
flaws which could cause undesirable effects. Still, I don't think it's
too bad: I run it myself.

=head1 AUTHOR

Tom Phoenix <rootbeer@redcat.com> with plenty of help from other folks,
including (in no particular order) "Tolkin, Steve"
<Steve.Tolkin@fmr.com>, Mark Lybrand <markyesme@home.com>, Eric Cholet
<cholet@logilune.com>, Drew Simonis <care227@attglobal.net>, Tim Conrow
<tim@ipac.caltech.edu>, Richard Martin Woodward
<RichardWoodward@hotmail.com>, JohnShep <john@princenaseem.com>, Mike
Solomon <mike.solomon@eps.ltd.uk>, Anno Siegel
<anno4000@lublin.zrz.TU-Berlin.DE>, Randall Woodman
<rwoodman@verio.net>, Ken MacFarlane <ksm@dca.net>, Philip Newton
<pne@cpan.org>, and anyone whose name I've accidentally omitted.
It wouldn't have been possible without all this help.

