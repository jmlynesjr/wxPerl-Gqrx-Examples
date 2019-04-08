#! /usr/bin/perl

# Name:			ListScanner.pl - Simple gqrx SDR Scanner(list of frequencies)
# Author:		James M. Lynes, Jr.
# Created:		April 6,2019
# Modified By:		James M. Lynes, Jr.
# Last Modified:	April 6,2019
# Change Log:		4/6/2019 - Program Created - cloned from Lite.pl
# Description:		Simple interface to gqrx to implement an SDR scanner function using the
#				Remote Control feature of gqrx(a small subset of rigctrl protocol).
#                               This version scans a list of frequencies, not a range of frequencies.
#                               Mode is set to AM to scan Sun N Fun aviation frequencies. The
#                               Sun N Fun Flyin and Airshow is held in Lakeland, FL each April.
#                               Also scanning Vero Beach and Lowell ARTCC frequencies.
#
# 			gqrx is a software defined receiver powered by GNU-Radio and QT
#    			Developed by Alex Csete - gqrx.dk
#
#                       It uses an inexpensive DVB-T dongle as the receiver hardware - rtl-sdr.com
#
# 			This code is inspired by "Controlling gqrx from a Remote Host" by Alex Csete
# 			and the gqrx-scan scanner code by Khaytsus - github.com/khaytsus/gqrx-scan
#
#			Net::Telnet is not in the Perl core and was installed from CPAN
#				sudo cpanm Net::Telnet
#
# 			Start gqrx, select IP address 127.0.0.1 Port 7356
#                               from the Tools->Remote control settings menu/button,
#                       select Tools->Remote Control menu/button to enable Remote Control
#                               before running this perl code!!!
#                       Open a Terminal window and enter ./ListScanner.pl
#                       Hit CTRL-C in the Terminal Window to stop scanning.
#
#
use strict;
use warnings;
use Net::Telnet;
use Time::HiRes;

# Defines
my $ip = "127.0.0.1";                                # Local Host
my $port = "7356";                                   # Port
my $mode = "AM";                                     # Demodulator 
my $pause = .05;                                     # Delay between frequency changes
my $listen = 4;                                      # Delay to allow listening to an active freq
my $squelch = -62;                                   # Minimum signal strength to break the squelch

# Specific frequencies to scan
my @freqs = ( 123428000, 123475000, 123573000, 124500000, 125075000, 125175000 );


# Open the Telnet connection to gqrx via localhost::7356
my $t = Net::Telnet->new(Timeout=>2, port=>$port);
$t->open($ip);

# Set the demodulator type
$t->print("M $mode");
$t->waitfor(Match=> '/RPRT', Timeout=>5, Errmode=>"return");

# Set up to run the scan cycle "count" times - 100 for now
my $count = 0;
while($count < 100) {

    foreach my $freq ( @freqs ) {
        $t->print("F $freq");						# Set Frequency
        $t->waitfor(Match=> '/RPRT', Timeout=>5, Errmode=>"return");

        $t->print("l");							# Get RSSI (-##.# format)
        my($prematch, $level) = $t->waitfor(Match => '/-{0,1}\d+\.\d/',
            Timeout => 5, Errmode => "return");
        if(!defined($level)) {next};                                    # Timed out, continue
        if($level == 0.0) {next};                                       # Bad level was returned, continue

        print ("Count: $count  freq: $freq  Level:  $level \n");        # Debug print
 
        if($level > $squelch) {Time::HiRes::sleep($listen)};		# Pause scan when signal detected

        Time::HiRes::sleep($pause);					# Pause before next frequency hop
    }

$count++;								# Loop for next scan cycle
}

# Close the Telnet connection and exit
$t->print("c");

