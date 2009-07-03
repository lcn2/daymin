#!/usr/bin/perl -wT
#
# daymin - run a daily task a minute later each day
#
# @(#) $Revision$
# @(#) $Id$
# @(#) $Source$
#
# Copyright (c) 2009 by Landon Curt Noll.  All Rights Reserved.
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose and without fee is hereby granted,
# provided that the above copyright, this permission notice and text
# this comment, and the disclaimer below appear in all of the following:
#
#       supporting documentation
#       source copies
#       source works derived from this source
#       binaries derived from this source or from derived source
#
# LANDON CURT NOLL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
# INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
# EVENT SHALL LANDON CURT NOLL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
# USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
# chongo (Landon Curt Noll, http://www.isthe.com/chongo/index.html) /\oo/\
#
# Share and enjoy! :-)

# This utility allows commnad to be periodically executed where the
# command must not be executed more than once in 24 hours.  When this
# utility is executed via a crontab on at the same time each day:
#
#	0 0 * * * daymin /var/daymin/minfile shell_file
#
# The resulting command and args are executed a minute later each day.
# The actual command is delayed by the number of minutes as recorded
# in the /var/daymin/minfile contents.
#
# By default, it is an error if the minfile does not exist.  It may
# be created by giving the -c flag, in which case the previous value
# was assumed to be 0, the command is immediately executed, and the
# minfile is left with a value of 1 for next time.
#
# The minfile is assumed to contain a single line containing the
# number of minutes for which the command execution should be delated.
# All other minfile contents is ignored and removed when file is
# incremented.
#
# The following command is an equivalent way to reset the minfile
# (equiavlent to using -c):
#
#	echo 0 > /var/daymin/minfile
#
# If is an error if the minfile does not exit and -c is not used.  So
# this crontab line will ensure that the command will be evantually
# executed, regardless of the state or non-existence of the minfile:
#
#	0 0 * * * daymin -c /var/daymin/minfile shell_file
#
# A minfile should be used to control the execution time of just one
# command.  The effect of doing this:
#
#	0 0 * * * daymin /var/daymin/WRONG /AVOID/REUSING/one/minfile
#	0 0 * * * daymin /var/daymin/WRONG /for/multiple/commands!!!
#
# would be to execute the echo commands with a period longer then
# the usual day + 1 minute.
#
# The execution delay is acomplished by the at(1) command.  Therefore the
# user must be allowed to use at.  See the at(1) man page for details.


# requirements
#
use strict;
use bytes;
use vars qw($opt_v $opt_c $delay);
use Getopt::Long;
use Fcntl qw(:DEFAULT :flock);

# version - RCS style *and* usable by MakeMaker
#
my $VERSION = substr q$Revision: 1.1 $, 10;
$VERSION =~ s/\s+$//;

# my vars
#

# usage and help
#
my $usage = "$0 [-v lvl] [-c] minfile shell_file";
my $help = qq{$usage

	-c		create the minfile before incrementing it
	-v lvl		verbose / debug level
	minfile		contain number of mintes to delay next run
	shell_file	a file containing input for the at(1) command
};
my %optctl = (
    "c" => \$opt_c,
    "v=i" => \$opt_v
);


# function prototypes
#
sub inc_minfile($$);
sub error($@);
sub debug($@);


# setup
#
MAIN: {
    my $minfile;	# filename with number of minutes to delay action
    my $shell_file;	# the input to the at command
    my $delay;		# minutes to delay the next command execution

    # setup
    #
    select(STDOUT);
    $| = 1;
    $ENV{"PATH"} = "/bin:/usr/bin:/usr/local/bin";
    delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};

    # set the defaults
    #
    $opt_v = 0;
    $delay = 0;

    # parse args
    #
    if (!GetOptions(%optctl)) {
	error(1, "invalid command line\nusage: $help");
    }
    if ($#ARGV < 0) {
	error(2, "minfile argument required\nusage: $help");
    } elsif ($#ARGV == 0) {
	error(3, "shell_file arg required after minfile arg\nusage: $help");
    } elsif ($#ARGV > 1) {
	error(4, "extra arguments found\nusage: $help");
    }
    if ($ARGV[0] =~ m/^([-a-zA-Z0-9+_.@%\/]*)$/) {
    	$minfile = $1;
    } else {
	error(5, "minfile contains unusual characters");
    }
    if ($ARGV[1] =~ m/^([-a-zA-Z0-9+_.@%\/]*)$/) {
    	$shell_file = $1;
    } else {
	error(6, "shell_file contains unusual characters");
    }
    debug(1, "minfile: $minfile");
    debug(1, "shell_file: $shell_file");
    if (! -e $shell_file) {
	error(7, "shell_file does not exist: $shell_file");
    }
    if (! -r $shell_file) {
	error(8, "shell_file is not readable: $shell_file");
    }

    # obtain minutes to wait and update minfile
    #
    $delay = inc_minfile($minfile, $opt_c);

    # a wait if 1440 minutes means no command today, wait for tomorrow
    #
    if ($delay >= 1440) {
    	debug(1, "wait delay: $delay >= 1 day, nothing to do today");
	exit(0);
    }
    debug(1, "will wait $delay minutes before executin command");

    # issue the at command
    #
    debug(1, "/usr/bin/at -f $shell_file now + $delay minutes");
    exec("/usr/bin/at", "-f", $shell_file, "now", "+", $delay, "minutes") or
        error(9, "command failed:",
	    "/usr/bin/at -f $shell_file now + $delay minutes", "error: $!");
    exit(0);
}


# inc_minfile - increment, mod 1441, (and perhaps create it) the minute file
#
# given:
#	$minfile	filename of the minute file to increment
#	$create		if defined, create if it does not exist
#
# returns:
#	The previous value (mod 1441) of the $minfile, or 0 if created.
#
#	NOTE: Does not return on error.
#
# If the minfile exists, we increment, mod 1441, the contents of the
# given filename and return the previous value.  The first line of the
# minfile is assumed to be an integer followed by a return.  All other
# contents is ignored and removed after the increment.
#
# The reason we increment mod 1441 is that there are 1440 minutes in a day.
# This utility is advancing the execution of a command a minute each day.
# So the maximum number of minutes to delay a command is 1440.
#
# If the minfile does not exist and $create is defined, the $minfile
# is created and assumed to have previously held the value of 0.
#
# If the minfile does not exist and $create is undefined, an error is raised.
#
sub inc_minfile($$)
{
    my ($minfile, $create) = @_;
    my $orig_count;			# original count read from minfile
    my $next_count;			# next count value

    # attempt to open the minfile
    #
    if (defined $create) {
        # create minfile if needed
	sysopen(FH, $minfile, O_RDWR|O_CREAT, 0664) or
	    error(10, "cannot open/create: $minfile: $!");
    } else {
	sysopen(FH, $minfile, O_RDWR) or
	    error(11, "cannot open: $minfile: $!");
    }
    debug(5, "opened: $minfile");

    # attempt to lock the minfile
    #
    flock(FH, LOCK_EX) or
	error(12, "cannot lock: $minfile: $!");
    debug(5, "locked: $minfile");

    # read the first line
    #
    $orig_count = <FH> || 0;
    chomp $orig_count;
    if ($orig_count =~ m/^(\d+)$/) {
    	$orig_count = $1;
    } else {
	debug(1, "found non-digits in minfile: $orig_count");
	$orig_count = 0;
    }
    debug(3, "read: $orig_count");

    # increment mod 1441
    #
    $next_count = ($orig_count + 1) % 1441;

    # rewrite minfile
    #
    debug(5, "writing: $next_count");
    seek(FH, 0, 0) or error(13, "cannot rewind minfile: $!");
    truncate(FH, 0) or error(14, "cannot truncate minfile: $!");
    (print FH "$next_count\n") or error(15, "cannot update minfile: $!");
    debug(3, "wrote: $next_count");

    # unlock
    #
    flock(FH, LOCK_UN) or error(16, "cannot unlock minfile: $!");

    # close
    #
    close FH or error(17, "error in closing minfile: $!");

    # return orignal count
    #
    return $orig_count;
}


# error - report an error and exit
#
# given:
#       $exitval	exit code value
#       $msg ...	error debug message to print
#
sub error($@)
{
    my ($exitval) = shift @_;	# get args
    my $msg;			# error message to print

    # parse args
    #
    if (!defined $exitval) {
	$exitval = 254;
    }
    if ($#_ < 0) {
	$msg = "<<< no message supplied >>>";
    } else {
	$msg = join(' ', @_);
    }
    if ($exitval =~ /\D/) {
	$msg .= "<<< non-numeric exit code: $exitval >>>";
	$exitval = 253;
    }

    # issue the error message
    #
    print STDERR "$0: $msg\n";

    # issue an error message
    #
    exit($exitval);
}


# debug - print a debug message is debug level is high enough
#
# given:
#       $min_lvl	minimum debug level required to print
#       $msg ...	debug message to print
#
# NOTE: The DEBUG[$min_lvl]: header is printed for $min_lvl >= 0 only.
#
# NOTE: When $min_lvl <= 0, the message is always printed
#
sub debug($@)
{
    my ($min_lvl) = shift @_;	# get args
    my $msg;			# debug message to print

    # firewall
    #
    if (!defined $min_lvl) {
    	error(97, "debug called without a minimum debug level");
    }
    if ($min_lvl !~ /-?\d/) {
    	error(98, "debug called with non-numeric debug level: $min_lvl");
    }
    if ($opt_v < $min_lvl) {
	return;
    }
    if ($#_ < 0) {
	$msg = "<<< no message supplied >>>";
    } else {
	$msg = join(' ', @_);
    }

    # issue the debug message
    #
    if ($min_lvl < 0) {
	print STDERR "$msg\n";
    } else {
	print STDERR "DEBUG[$min_lvl]: $msg\n";
    }
}
