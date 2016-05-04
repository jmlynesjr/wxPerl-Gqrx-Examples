#! /usr/bin/perl

# Name:			lite.pl - Simple gqrx SDR Scanner
# Author:		James M. Lynes, Jr.
# Created:		September 17, 2015
# Modified By:		James M. Lynes, Jr.
# Last Modified:	September 17, 2015
# Change Log:		9/17/2015 - Program Created
# Description:		Simple interface to gqrx to implement a SDR scanner function using the
#				Remote Control feature of gqrx(small subset of rigctrl protocol)
#
# 			gqrx is a software defined receiver powered by GNU-Radio and QT
#    			Developed by Alex Csete - gqrx.dk
#
# 			This code is inspired by "Controlling gqrx from a Remote Host" by Alex Csete
# 			and the gqrx-scan scanner code by Khaytsus - github.com/khaytsus/gqrx-scan
#
#			Net::Telnet is not in the perl core and was installed from cpan
#				sudo cpanm Net::Telnet
#
# 			Start gqrx and the gqrx Remote Control option before running this perl code
#
#
use strict;
use warnings;
use Net::Telnet;
use Time::HiRes;

# Defines
my $ip = "127.0.0.1";
my $port = "7356";
my $step = 1000;
my $begin = 162400000;
my $end   = 162600000;
my $mode = "FM";
my $pause = .005;
my $listen = 1;
my $squelch = -60;

# Open Telnet connection to gqrx via localhost::7356
my $t = Net::Telnet->new(Timeout=>2, port=>$port);
$t->open($ip);

# Set the demodulator type
$t->print("M $mode");
$t->waitfor(Match=> '/RPRT', Timeout=>5, Errmode=>"return");

# Set up to run the scan cycle count times
my $count = 0;
while($count < 10) {
    my $start = $begin;

    while($start <= $end) {
        $t->print("F $start");						# Set Frequency
        $t->waitfor(Match=> '/RPRT', Timeout=>5, Errmode=>"return");

        $t->print("l");							# Get RSSI (-##.# format)
        my($prematch, $level) = $t->waitfor(Match => '/-{0,1}\d+\.\d/', Timeout => 5, Errmode => "return");
        if(!defined($level)) {next};
#       print $level;

        if($level > $squelch) {Time::HiRes::sleep($listen)};		# Pause scan when signal detected

        $start = $start + $step;
        Time::HiRes::sleep($pause);					# Pause before next frequency hop
    }

$count++;								# Loop for next scan cycle
}

# Close the Telnet connection
$t->print("c");

