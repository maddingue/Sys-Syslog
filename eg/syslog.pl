#!/usr/bin/perl

use strict;
use warnings;

use English '-no_match_vars';

use Sys::Syslog;

die "usage: $PROGRAM_NAME facility/priority message\n" unless @ARGV;

my ($facility, $priority) = split '/', shift;
my $message = join ' ', @ARGV;

openlog($PROGRAM_NAME, "ndelay,pid", $facility) or die "fatal: can't open syslog: $OS_ERROR\n";
syslog($priority, "%s", $message);
closelog();
