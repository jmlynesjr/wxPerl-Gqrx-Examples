#! /usr/bin/perl

# Name:			GqrxRawAudioPlot.pl Cloned from Wx-WaveForms2.pl(a simulated o-scope proof of concept)
# Author:		James M. Lynes, Jr.
# Created:		February 27, 2016
# Modified By:		James M. Lynes, Jr.
# Last Modified:	April 4, 2016
# Enviroment:		Perl 5.18.2, wxPerl .9924, wxWidgets 3.0.1, Ubuntu 14.04LTS 64bit, HP 15 Quad Core
# Change Log:		2/27/2016 - Program Created
#                       2/28/2016 - Remove all but random plot code, merge in socket code
#                       3/6/2016  - Create an array(fifo) to hold sample data values - 600 values
#			3/13/2016 - Implement updating of sample array and unpacking of complete packet
#			3/14/2016 - Add scale factor selection. Correct offset calculation.
#			3/23/2016 - Add writing of image updates to memory file instead of disk file
#			3/29/2016 - Add socket packet counter with display, fixed unpacking the complete packet
#			3/30/2016 - Add button to change scale factor(1, 10, 100)
#			3/31/2016 - Move a few variable assignments outside of loops,
#				    Add screen snapshot to diskfile function
#			4/2/2016  - Add display of received packet length
#			4/4/2016  - Add Connect & Plot button color highlighting
#
# Description:		wxPerl Proof of Concept for display of raw audio from Gqrx
#			Read & unpack the first 600 samples to fill the display array
#			    Read following packets, unpack, and update the display array
#                       One sample per UDP packet(localhost/port 7355)
#                           Left Channel Value
#                           48KHz Sample Rate
#                           16bit signed, little endian
#
# Notes:		There seems to be a 6-8 second delay between hearing the audio
#			    in Gqrx and seeing the curve on the O-scope.
#			App will hang up(go unresponsve) if Gqrx is not sending packets. 
#
# To Do:		Rewrite the o-scope specific code into module form.


package main;
use strict;
use warnings;
my $app = App->new();
$app->MainLoop;

package App;
use strict;
use warnings;
use base 'Wx::App';
sub OnInit {
    Wx::InitAllImageHandlers();
    my $frame = Frame->new();
    $frame->Show(1);
}

package Frame;
use strict;
use warnings;
use Wx qw(:everything);
use base qw(Wx::Frame);
use IO::Socket;
use GD;
use Data::Dumper;

sub new {
    my ($class, $parent) = @_;

    my $self = $class->SUPER::new($parent, -1, "Gqrx Raw Audio Display",
                                   wxDefaultPosition, [610, 680]); # Fit to o-scope size

    #   Application Initialization
    my $oscope = {};							# Blank oscope data structure

    $oscope->{maxw} = 600;						# width/x axis
    $oscope->{maxh} = 600;						# height/y axis
									# Must be square for appearance purposes

    $oscope->{packet} = 0;						# Blank received UDP packet
    $oscope->{fifo} = [];						# Blank sample array(display array)
    $oscope->{audiosamples} = ();					# Blank unpacked sample list
    $oscope->{fifostatus} = 0;						# 0->space available, 1->full 
    $oscope->{connectstatus} = 0;					# 0->disconnected, 1->connected
    $oscope->{plotstatus} = 0;						# 0->plot stopped, 1->plot started
    $oscope->{scalefactor} = 10;					# Sample scale factor(1, 10, 100)
    $oscope->{memoryfile} = [];						# Memory File to hold PNG image
    $oscope->{packetcounter} = 0;					# Received packet counter
    $oscope->{packetlength} = 0;					# Received packet length
    $oscope->{pctrlabel} = "Packet Counter:";				# Screen label
    $oscope->{plenlabel} = "Packet Length:";				# Screen label
    $oscope->{slabel} = "Scale Factor:";				# Screen label
    $oscope->{snapcounter} = 0;						# Screen snapshot counter

    # Create initial blank o-scope screen background
    oscopeinit($oscope);						# Draw a blank O-Scope screen
    saveaspngfile($oscope);						# Save image to a PNG disk file
    $self->{bmp} = Wx::Bitmap->new("rawaudio.png", wxBITMAP_TYPE_PNG);	# Reload disk file into a bitmap
    $self->{sbm} = Wx::StaticBitmap->new($self, wxID_ANY, $self->{bmp}, wxDefaultPosition, [600,600]); # Display bitmap

    # Create Buttons
    my $connectButton = Wx::Button->new($self, -1, "Connect to Gqrx", wxDefaultPosition, wxDefaultSize);
    my $disconnectButton = Wx::Button->new($self, -1, "Disconnect from Gqrx", wxDefaultPosition, wxDefaultSize);
    my $plotButton = Wx::Button->new($self, -1, "Plot UDP Data", wxDefaultPosition, wxDefaultSize);
    my $exitButton = Wx::Button->new($self, wxID_EXIT, "", wxDefaultPosition, wxDefaultSize);
    my $scaleButton = Wx::Button->new($self, -1, "Change Scale Factor", wxDefaultPosition, wxDefaultSize);
    my $snapButton = Wx::Button->new($self, -1, "Snapshot", wxDefaultPosition, wxDefaultSize);

    # Define Timer
    $self->{timer} = Wx::Timer->new($self);

    # Create sizers.
    my $verticalSizerFrame = Wx::BoxSizer->new(wxVERTICAL);
    $self->SetSizer($verticalSizerFrame);
    my $verticalSizerControls = Wx::BoxSizer->new(wxVERTICAL);
    my $horizontalSizerButtons1 = Wx::BoxSizer->new(wxHORIZONTAL);
    my $horizontalSizerButtons2 = Wx::BoxSizer->new(wxHORIZONTAL);

    # Layout Sizers
    $verticalSizerFrame->Add($verticalSizerControls,0,0,0);
    $verticalSizerFrame->Add($horizontalSizerButtons1,0,0,0);
    $verticalSizerFrame->Add($horizontalSizerButtons2,0,0,0);

    $verticalSizerControls->Add($self->{sbm},0,0,0);			# O-scope Screen Display
    $verticalSizerControls->AddSpacer(15);

    $horizontalSizerButtons1->Add($connectButton,0,0,0);
    $horizontalSizerButtons1->AddSpacer(10);
    $horizontalSizerButtons1->Add($disconnectButton,0,0,0);
    $horizontalSizerButtons1->AddSpacer(10);
    $horizontalSizerButtons1->Add($plotButton,0,0,0);
    $horizontalSizerButtons1->AddSpacer(10);
    $horizontalSizerButtons1->Add($scaleButton,0,0,0);

    $horizontalSizerButtons2->Add($snapButton,0,0,0);
    $horizontalSizerButtons2->AddSpacer(45);
    $horizontalSizerButtons2->Add($exitButton,0,0,0);

    # Event handlers
    Wx::Event::EVT_BUTTON($self, $connectButton, sub {
        my ($self, $event) = @_;
        if($oscope->{connectstatus} == 0) {				# Disconnected ?
            udpconnect($oscope);					# Connect to the Gqrx UDP port
            $oscope->{connectstatus} = 1;				# set Connected
            $connectButton->SetLabel("Connected");
            $connectButton->SetBackgroundColour(wxGREEN);
        } 
        });

    Wx::Event::EVT_BUTTON($self, $disconnectButton, sub {
        my ($self, $event) = @_;
        if($oscope->{connectstatus} == 1) {				# Connected ?
            $oscope->{plotstatus} = 0;					# Stop plotting
            $self->{timer}->Stop;					# Stop the screen update
            udpdisconnect($oscope);					# Disconnect from the Gqrx UDP port
            $oscope->{connectstatus} = 0;				# Set Disconnected
            $connectButton->SetLabel("Connect to Gqrx");
            $connectButton->SetBackgroundColour(wxWHITE);
            $plotButton->SetBackgroundColour(wxWHITE);
        }
        });

    Wx::Event::EVT_BUTTON($self, $plotButton, sub {			# Read/Plot first 600 samples
        my ($self, $event) = @_;					# (fill the fifo)

        $plotButton->SetBackgroundColour(wxGREEN);
        oscopeinit($oscope);  						# Redraw the screen background
        $oscope->{color} = $oscope->{blue};				# Plot data in blue
        $oscope->{fifostatus} = 0;					# Reset fifo status
        $oscope->{fifo} = [];						# Reset fifo array
        $oscope->{packetcounter} = 0;					# Reset packet counter
        fillqueue($oscope);						# Read 600 samples from the Gqrx UDP port 
        drawcurve($oscope);						# Plot the fifo array
                     
        saveaspngmemoryfile($oscope);					# Save GD Image as PNG memory file

        open my $fh, '<', \$oscope->{memoryfile};			# Rebuild the screen bitmap
        $self->{bmp} = Wx::Bitmap->new(Wx::Image->new($fh, wxBITMAP_TYPE_PNG));
        close $fh;

        $self->{sbm}->SetBitmap($self->{bmp});				# Refresh screen
        $oscope->{plotstatus} = 1;					# Set Plotting started
        $self->{timer}->Start(45);					# 45 msec refresh timer
        });

    Wx::Event::EVT_BUTTON($self, $scaleButton, sub {			# Change scale factor(1, 10, 100)
        my ($self, $event) = @_; 
        $oscope->{scalefactor} *= 10;
        if($oscope->{scalefactor} > 100) {
            $oscope->{scalefactor} = 1;
        }
        });

    Wx::Event::EVT_BUTTON($self, $snapButton, sub {			# Snapshot the screen to disk
        my ($self, $event) = @_; 
        snapaspngfile($oscope);
        });

    Wx::Event::EVT_BUTTON($self, $exitButton, sub {			# Exit script
        my ($self, $event) = @_; 
        $self->Close;
        });

    Wx::Event::EVT_TIMER($self, $self->{timer}, sub {			# Display update timer
        my ($self, $event) = @_;					# (all following packets)

        if($oscope->{plotstatus} == 1) {				# Ignore timer until fifo has been filled
            $oscope->{socket}->recv($oscope->{packet},2000);		# Wait for a packet - maxlength 2000
            @{$oscope->{audiosamples}} = unpack('s<*', $oscope->{packet});	# Convert from 16bit "Network" format
            $oscope->{packetcounter}++;					# Update received packet count
            $oscope->{packetlength} = length($oscope->{packet});	# Update received packet length

            foreach my $sample(@{$oscope->{audiosamples}}) {		# Move the samples to the fifo
               shiftqueue($oscope->{fifo}, $sample);			# Oldest sample out, newest sample in
            }

            oscopeinit($oscope);					# Redraw the screen background
            $oscope->{color} = $oscope->{blue};				# Plot data in blue
            drawcurve($oscope);						# Plot the fifo array

            saveaspngmemoryfile($oscope);				# Save GD Image as PNG memory file

            open my $fh, '<', \$oscope->{memoryfile};			# Rebuild the screen bitmap
            $self->{bmp} = Wx::Bitmap->new(Wx::Image->new($fh, wxBITMAP_TYPE_PNG));
            close $fh;

            $self->{sbm}->SetBitmap($self->{bmp});			# Refresh screen
        };
        });

    $verticalSizerFrame->Layout();

    return $self;

}

# ---------------------------------------------- Subroutines ---------------------------------------------------------------

#
# Initialize/redraw the O-Scope Image background
#
sub oscopeinit {
    my($oscope) = @_;
    $oscope->{image} = GD::Image->new($oscope->{maxw}, $oscope->{maxh}) || die;
    $oscope->{white} = $oscope->{image}->colorAllocate(255,255,255);	# 1st allocate defines the background color - White
#    $oscope->{black} = $oscope->{image}->colorAllocate(0,0,0);		# Unused color
    $oscope->{green} = $oscope->{image}->colorAllocate(0,255,0);
    $oscope->{blue} = $oscope->{image}->colorAllocate(0,0,255);
#    $oscope->{yellow} = $oscope->{image}->colorAllocate(255,255,0);	# Unused color
#    $oscope->{red} = $oscope->{image}->colorAllocate(255,0,0);		# Unused color
    $oscope->{color} = $oscope->{green};				# Set screen green on white
    drawgrid($oscope);
}

#
# Save the Image as a PNG Disk File(initial screen background)
#
sub saveaspngfile {
    my($oscope) = @_;
    my $png_data = $oscope->{image}->png;				# Write image to a file
    open OUTFILE, ">", "rawaudio.png" || die;
    binmode OUTFILE;
    print OUTFILE $png_data;
    close OUTFILE;
}

#
# Save the Image as a PNG Memory File(updated screen image)
#
sub saveaspngmemoryfile {
    my($oscope) = @_;
    $oscope->{memoryfile} = $oscope->{image}->png;			# Write image to memory
}

#
# Save the Image to a PNG Disk file with incrementing filename
#
sub snapaspngfile {
    my($oscope) = @_;
    my $png_data = $oscope->{image}->png;				# Write image to a disk file
    open OUTFILE, ">", "rawaudio$oscope->{snapcounter}.png" || die;	# Build the filename
    binmode OUTFILE;
    print OUTFILE $png_data;
    close OUTFILE;
    $oscope->{snapcounter}++;	 					# Increment filename
}

#
# Draw a simulated O-Scope Screen
#
sub drawgrid {
    my($oscope) = @_;

    my $maxw = $oscope->{maxw};
    my $maxh = $oscope->{maxh};
    my $color = $oscope->{color};

# Draw Border
    $oscope->{image}->setThickness(3);
    $oscope->{image}->rectangle(1, 2, $maxw-2, $maxh-3, $color);	# Fudge box coord for best appearance

# Draw horizontal lines
    $oscope->{image}->setThickness(1);
    for(my $i=0; $i<$maxw; $i=$i+50) {					# 50 pixels per major division
        $oscope->{image}->line(0, $i, $maxw, $i, $color);
    }

# Draw vertical lines
    for(my $i=0; $i<$maxh; $i=$i+50) {					# 50 pixels per major division
        $oscope->{image}->line($i, 0, $i, $maxh, $color);
    }

# Draw Axis
    $oscope->{image}->setThickness(3);

    $oscope->{image}->line($maxw/2, 0, $maxw/2, $maxh, $color);		# Vertical Axis

    $oscope->{image}->line(0, $maxh/2, $maxw, $maxh/2, $color);		# Horizontal Axis

# Draw Axis tic marks
    $oscope->{image}->setThickness(1);

# Vertical Axis tic marks
    for(my $i=0; $i<$maxh; $i=$i+10) {					# 10 pixels per minor division
        $oscope->{image}->line(($maxw/2)-3, $i, ($maxw/2)+3, $i, $color); # 6 pixel wide tic mark
    }

# Horizontal Axis tic marks
    for(my $i=0; $i<$maxw; $i=$i+10) {					# 10 pixels per minor division
        $oscope->{image}->line($i, ($maxh/2)+3, $i, ($maxh/2-3), $color); # 6 pixel wide tic mark
    }

# Screen Label(s) - Static text for now
    $oscope->{image}->string(gdSmallFont, 10,  10, $oscope->{pctrlabel},     $color);
    $oscope->{image}->string(gdSmallFont, 120, 10, $oscope->{packetcounter}, $color);
    $oscope->{image}->string(gdSmallFont, 10,  20, $oscope->{slabel},        $color);
    $oscope->{image}->string(gdSmallFont, 120, 20, $oscope->{scalefactor},   $color);
    $oscope->{image}->string(gdSmallFont, 10,  30, $oscope->{plenlabel},     $color);
    $oscope->{image}->string(gdSmallFont, 120, 30, $oscope->{packetlength},  $color);
}


sub drawcurve {								# Draw the current fifo
    my($oscope) = @_;

    my $maxw = $oscope->{maxw};
    my $maxh = $oscope->{maxh};
    my $color = $oscope->{color};

    $oscope->{image}->setThickness(1);

    my $lastx = 0;
    my $lasty = 0;
    my $y = 0;
    for(my $i=0; $i<$maxw; $i=$i+1) {					# 1 pixel sample width

        if($oscope->{fifo}[$i] > 0) {					# Scale/offset the sample
            $y = 300 - ($oscope->{fifo}[$i] / $oscope->{scalefactor});
        }
        elsif($oscope->{fifo}[$i] < 0) {
            $y = 300 + ((abs($oscope->{fifo}[$i])) / $oscope->{scalefactor});
        }
        else {
        $y = 300;							# Default to 300("zero" value)
        }
        
        $oscope->{image}->line($lastx, $lasty, $i, $y, $color);
        $lastx = $i;
        $lasty = $y;
    }
}

sub udpconnect {
    my ($oscope) = @_;
    $oscope->{socket} = IO::Socket::INET->new(				# Open udp socket to Gqrx
                           LocalAddr => 'localhost',
                           LocalPort => 7355,
                           Proto     => 'udp'
                           );
}

sub udpdisconnect {							# Disconnect udp socket from Gqrx
    my ($oscope) = @_;
    close($oscope->{socket});
}

# enqueue, shiftqueue and fillqueue implement a fifo that keeps the most recent 600 samples
#    enqueue and fillqueue fill the fifo for the first time(600 samples)
#    shiftqueue handles all following samples
#        topvalue is discarded and the new value is entered at the bottom
#
#    note: $#{$fifo} is the highest array index(runs 0-599)

sub enqueue {								# Insert a sample at the bottom of the array
    my ($fifo, $sample) = @_;
    if($#{$fifo} < 599) {
        push @$fifo, $sample;
        return 0;							# Space still available
    }
    return 1;								# Full
}

sub shiftqueue {							# Shift out oldest and push in newest
    my ($fifo, $sample) = @_;
    shift $fifo;
    push $fifo, $sample
}

sub fillqueue {								# Read packets until 600 slot fifo is filled
    my ($oscope) = @_;
    while (1) {

        $oscope->{socket}->recv($oscope->{packet},2000);		# Wait for a packet - maxlength 2000
        @{$oscope->{audiosamples}} = unpack('s<*', $oscope->{packet});	# Convert from 16bit "Network" format
        $oscope->{packetcounter}++;					# Update received packet counter
        $oscope->{packetlength} = length($oscope->{packet});		# Update received packet length

        foreach my $sample(@{$oscope->{audiosamples}}) {		# Move the samples to the fifo
            $oscope->{fifostatus} = enqueue($oscope->{fifo}, $sample);	# 0-not full, 1-full
            if($oscope->{fifostatus}) {return};				# Loop until 600 samples are queued
        }  
    }
}

1;

