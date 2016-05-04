#! /usr/bin/perl

# Gqrx UDP Server Test Program - udpserver.pl
#    James M. Lynes, Jr. April 2,2016
#    Send test UDP packets to the GqrxRawAudioPlot.pl program
#        16bit signed, little endian
#
# To Run: ./udpserver.pl &						# Start the server
#         ./GqrxRawAudioServer.pl					# Display waveforms
#         kill %1							# Kill the server

use strict;
use warnings;
use IO::Socket;
use Time::HiRes qw(sleep);
use Data::Dumper;


# Application Initialization
my $oscope = {};							# Create a blank o-scope
$oscope->{waveform} = ();						# Create a blank waveform
$oscope->{socket} = IO::Socket::INET->new(				# Open udp socket to GqrxRawAudioPlot.pl
                    PeerAddr => 'localhost',
                    PeerPort => 7355,
                    Proto     => 'udp'
                    );
$oscope->{packet} = ();							# Create a blank UDP packet to send


#  Build and Send the transmit packets - a variety of wave types
for(my $i=0; $i<3000; $i++) {
    for(my $j=0; $j<1; $j++) {
        sinwaveform($oscope);						# Sin wave
        packpacket($oscope);
        sendpacket($oscope);
        sleep(.03);
    }
    for(my $j=0; $j<5; $j++) {
        clearwaveform($oscope);						# Zero wave
        packpacket($oscope);
        sendpacket($oscope);
        sleep(.03);
    }
    for(my $j=0; $j<1; $j++) {
        randomwaveform($oscope);					# Random wave
        packpacket($oscope);
        sendpacket($oscope);
        sleep(.03);
    }
    for(my $j=0; $j<5; $j++) {
        clearwaveform($oscope);						# Zero wave
        packpacket($oscope);
        sendpacket($oscope);
        sleep(.03);
    }
}

#exit
close($oscope->{socket});						# Close the UDP connection


# Subroutines ---------------------------------------------------------------------------------------------------

sub packpacket {
    my($oscope) = @_;
    $oscope->{packet} = pack('s<*', @{$oscope->{waveform}});		# Convert to 16bit "Network" format    
}

sub sendpacket {
    my($oscope) = @_;
    $oscope->{socket}->send($oscope->{packet});
}

sub sinwaveform {							# Build one cycle of a waveform
    my($oscope) = @_;

    for(my $i=0; $i<360; $i++) {
        my $rads = $i/57.32;
        my $s = (sin($rads) * 100) + rand(50);				# Sin wave plus noise
        $oscope->{waveform}[$i] = $s;
    }
}

sub clearwaveform {							# Zero out the waveform
    my($oscope) = @_;

    for(my $i=0; $i<360; $i++) {
        $oscope->{waveform}[$i] = 0;
    }
}

sub randomwaveform {							# Random waveform
    my ($oscope) = @_;

    for(my $i=0; $i<360; $i++) {
        $oscope->{waveform}[$i] = rand(100) - 50;
    }
}


