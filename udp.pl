#! /usr/bin/perl

# Gqrx/UDP Test Program - udp.pl
#    Receive and decode variable length UDP packets from the Gqrx SDR program
#        Left Channel Value only
#        48KHz Sample Rate
#        16bit signed, little endian

use strict;
use warnings;
use IO::Socket;
use Data::Dumper;

print "\n\n";
print "Gqrx/UDP Test Program\n";
print "---------------------";
print "\n\n";
print "Opening Socket\n\n";

my $socket = IO::Socket::INET->new(					# Open udp socket to Gqrx
             LocalAddr => 'localhost',
             LocalPort => 7355,
             Proto     => 'udp'
             );

my $packet;								# Received UDP packet
my @audiosamples;							# packet unpacked into multiple samples

for (my $i = 1; $i<= 1500; $i++) {
    $socket->recv($packet,2000);					# Wait for a packet - maxlength 2000
    my $pktlength = length($packet);					# what's the length of the received packet?
    @audiosamples = unpack('s<*', $packet);				# Convert from 16bit "Network" format
    my $samplength = $#audiosamples;
#    print "$pktlength\n";						# Display only the packet length
    print "$pktlength / $samplength / @audiosamples\n";		# Display packet length & converted values
#     print "$i\n";
}
close($socket);								# Done, close the socket

