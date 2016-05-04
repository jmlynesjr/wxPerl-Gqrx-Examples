#! /usr/bin/perl

# Name:			threadedgqrxLite.pl - Simple gqrx SDR Scanner - wxPerl Version
# Author:		James M. Lynes, Jr.
# Created:		September 17, 2015
# Modified By:		James M. Lynes, Jr.
# Last Modified:	January 6, 2016
# Environment:		Ubuntu 14.04LTS / perl v5.18.2 / wxPerl 3.0.1 / HP 15 Quad Core
# Change Log:		9/17/2015 - Program Created
#			9/19/2015 - Added Title Text, Connection Error Popup, Sizers and Event Handlers
#				  - Scan and Listen Timers, Button Label Change as Status Indicator
#			9/20/2015 - Additional Comments, add additional error checking/processing
#			9/26/2015 - Restructure to a threaded implementation
#			9/28/2015 - Stubbed threaded structure working, flesh out thread code,
#				  - modify event code
#				  - Test thread commands and button interlocking flags
#				  - Add error message timer/event
#			9/29/2015 - Set error message timer to 1 sec
#				  - Redesign threads, collapse to 1 Telnet Server thread
#				  - Object sharing not easily supported by Thread implementation
#			10/19/2015- Fixed scanning loop in Telnet Thread
#				  - Scaled {pause} and {listen} to be in msecs
#                                 - Scaled frequency values to KHz from Hz
#				  - Added Modulation Mode setting
#                       1/6/2016  - Fixed comment in error concerning the Main Sizer(Vertical not Horizontal)
#                                 - Fixed comment in error concerning installation of Gqrx package
# Description:		"Simple" interface to gqrx to implement a Software Defined Radio(SDR)
#			scanner function using the remote control feature of gqrx
#			(a small subset of the amateur radio rigctrl protocol)
#
# 			gqrx is a software defined receiver powered by GNU-Radio and QT
#    			Developed by Alex Csete - gqrx.dk
#			The latest version(2.4) is at:
#                           sudo apt-get purge --auto-remove gqrx                # Remove 2.3x
#                           sudo add-apt-repository --remove ppa:gqrx/snapshots  # Remove old ppa
#                           sudo add-apt-repository -y ppa:bladerf/bladerf       # Add new ppa
#                           sudo add-apt-repository -y ppa:myriadrf/drivers      # Add new ppa
#                           sudo add-apt-repository -y ppa:myriadrf/gnuradio     # Add new ppa
#                           sudo add-apt-repository -y ppa:gqrx/gqrx-sdr         # Add new ppa
#                           sudo apt-get update
#                           sudo apt-get install gqrx-sdr
#                           sudo apt-get install libvolk1-bin                    # Install profiler
#                           volk_profile                                         # Profile PC Performance - Runs +/- 15mins
#
#			gqrx uses inexpensive($12 USD) DVB-T USB Dongles to provide I and Q signals for DSP
#			DVB-T is the EU standard for Digital Video Broadcast
#			See Alex's website for a list of supported dongles
#
# 			This code is inspired by "Controlling gqrx from a Remote Host" by Alex Csete
# 			and gqrx-scan by Khaytsus - github.com/khaytsus/gqrx-scan
#
#			Net::Telnet is not in the perl core and was installed from cpan
#			sudo cpanm Net::Telnet
#
# 			Start gqrx and the gqrx remote control option before running this perl code.
#			Also, check that the gqrx LNA and audio gains are set.
#			An error window will popup if gqrx is not running with Remote Control enabled,
#			or if the dongle is not plugged in, when a Telnet connection request is made.
#
# Notes:		To change parameters: Stop Scanning, Change Parameters, Start Scanning. The
#			previous frequency range will complete scanning before the new range takes effect.
#			Modulation Mode change requires disconnect/reconnect.
#

package main;
use strict;
use warnings;
use Net::Telnet;
use Time::HiRes qw(sleep);
use threads;
use threads::shared;
use Data::Dumper;

# ----------------------------------- Thread setup must occur before Wx GUI setup ---------------------------
# Define the Thread shared data area
my  %common : shared;
    $common{ip} = "127.0.0.1";		# Localhost
    $common{port} = "7356";		# Local Port as defined in gqrx
    $common{tnerror} = 0;		# Status, Telnet Error
    $common{connect} = 0;		# Command
    $common{connected} = 0;		# Status
    $common{disconnect} = 0;		# Command
    $common{scanstart} = 0;		# Command
    $common{scanstarted} = 0;		# Status
    $common{beginf} = 0;		# Scan - Beginning Frequency
    $common{endf} = 0;			# Scan - Ending Frequency
    $common{nextf} = 0;			# Scan - Variable Frequency(loop counter)
    $common{step} = 0;			# Scan - Frequency Step
    $common{squelch} = 0;		# Scan - Minimum RSSI(Recieved Signal Strength Indicator)
    $common{rssi} = 0;			# Scan - Latest RSSI
    $common{rssiupdate} = 0;		# Scan - RSSI Update Command
    $common{pause} = 0;			# Scan - Time between scan cycles - msec
    $common{listen} = 0;		# Scan - Time to Listen to a strong signal - msec
    $common{mode} = 0;			# Scan - Demodulator Type
    $common{stopthreads} = 0;		# Command

# Create Threads and Detach
my $thconnect = threads->create(\&TelnetServer);
   $thconnect->detach();

# Define Telnet Server Thread Processing
sub TelnetServer {
    my $telnetsession;
    print "\nTelnet Server Thread Started\n";
    print "   Check that gqrx Remote Control is enabled\n   and that LNA and Audio gains are set.\n";
    while(1) {

        if($common{stopthreads}) {print "\nTelnet Server Thread Terminated\n"; return};

        if($common{connect}) {						# Process Connect Command
            if(!$common{connected}) {
               print "Open Telnet Connection to gqrx\n";
               $telnetsession = Net::Telnet->new(Timeout => 2, port => $common{port},
                                        Errmode => sub {$common{tnerror} = 1;});
               $telnetsession->open($common{ip});

               $telnetsession->print("M $common{mode}");		# Set the demodulator type
               $telnetsession->waitfor(Match=> '/RPRT', Timeout=>5, Errmode=>"return");

               $common{connected} = 1;
               $common{connect} = 0;
            }
        }

        if($common{disconnect}) {					# Process Disconnect Command
           if($common{connected}) {
               print "Close Telnet Connection to gqrx\n";
               $telnetsession->print("c");
               $common{disconnect} = 0;
               $common{connected} = 0;
            }
         }

        if($common{scanstart}) {					# Process Scan Command

                $common{scanstarted} = 1;
                $telnetsession->print("F $common{nextf}");		# Update frequency
                $telnetsession->waitfor(Match => 'RPRT', Timeout => 5, Errmode => "return");
                $telnetsession->print("l");				# Get RSSI
                my ($prematch, $rssi) = $telnetsession->waitfor(Match => '/-{0,1}\d+\.\d/',
                                        Timeout => 5, Errmode => "return");

                if(defined($rssi)) {
                    if($rssi >= $common{squelch}) {			# Found a strong signal
                        $common{rssi} = $rssi;
                        $common{rssiupdate} = 1;
                        Time::HiRes::sleep($common{listen});		# Pause and listen awhile
                    }
                }

                $common{nextf} = $common{nextf} + $common{step};	# Loop for next frequency
                if($common{nextf} >= $common{endf}) {$common{nextf} = $common{beginf}};
                Time::HiRes::sleep($common{pause});
        }
        threads->yield();
    }
}


# ------------ Start up the Wx GUI Processing, must happen after the threads are started ------------
my $app = App->new();
$app->MainLoop;

package App;
use strict;
use warnings;
use base 'Wx::App';
sub OnInit {
    my $frame = Frame->new();
    $frame->Show(1);
}

package Frame;
use strict;
use warnings;
use Wx qw(:everything);
use base qw(Wx::Frame);

sub new {
    my ($class, $parent) = @_;

# Create top level frame
    my $self = $class->SUPER::new($parent, -1, "gqrx Lite Scanner", wxDefaultPosition, wxDefaultSize);
 
# Create Title Text
    $self->{titletext} = Wx::StaticText->new($self, -1, "Threaded gqrx Lite Scanner", wxDefaultPosition, wxDefaultSize);

# Create Modulation Radio Box - First entry is the default
    my $modulators = ["FM", "AM", "WFM_ST", "WFM", "LSB", "USB", "CW", "CWL", "CWU"];
    $self->{modbox} = Wx::RadioBox->new($self, -1, "Modulation", wxDefaultPosition, wxDefaultSize,
                      $modulators, 3, wxRA_SPECIFY_COLS);    

# Create Buttons
    $self->{startbutton}      = Wx::Button->new($self, -1, "Start Scanning", wxDefaultPosition, wxDefaultSize);
    $self->{stopbutton}       = Wx::Button->new($self, -1, "Stop Scanning", wxDefaultPosition, wxDefaultSize);
    $self->{connectbutton}    = Wx::Button->new($self, -1, "Connect", wxDefaultPosition, wxDefaultSize);
    $self->{disconnectbutton} = Wx::Button->new($self, -1, "Disconnect", wxDefaultPosition, wxDefaultSize);
    $self->{quitbutton}       = Wx::Button->new($self, -1, "Quit", wxDefaultPosition, wxDefaultSize);

# Create Data Entry Prompts and Boxes
    $self->{bflabel} = Wx::StaticText->new($self, -1, "Beginning Frequency, KHz", wxDefaultPosition, wxDefaultSize);
    $self->{bftext} = Wx::TextCtrl->new($self, -1, "144000", wxDefaultPosition, wxDefaultSize);

    $self->{eflabel} = Wx::StaticText->new($self, -1, "Ending Frequency, KHz", wxDefaultPosition, wxDefaultSize);
    $self->{eftext} = Wx::TextCtrl->new($self, -1, "144100", wxDefaultPosition, wxDefaultSize);

    $self->{fslabel} = Wx::StaticText->new($self, -1, "Frequency Step, Hz", wxDefaultPosition, wxDefaultSize);
    $self->{fstext} = Wx::TextCtrl->new($self, -1, "1000", wxDefaultPosition, wxDefaultSize);

    $self->{sllabel} = Wx::StaticText->new($self, -1, "Squelch Level", wxDefaultPosition, wxDefaultSize);
    $self->{sltext} = Wx::TextCtrl->new($self, -1, "-60.0", wxDefaultPosition, wxDefaultSize);

    $self->{splabel} = Wx::StaticText->new($self, -1, "Scan Pause, ms", wxDefaultPosition, wxDefaultSize);
    $self->{sptext} = Wx::TextCtrl->new($self, -1, "20", wxDefaultPosition, wxDefaultSize);

    $self->{lplabel} = Wx::StaticText->new($self, -1, "Listen Pause, ms", wxDefaultPosition, wxDefaultSize);
    $self->{lptext} = Wx::TextCtrl->new($self, -1, "1000", wxDefaultPosition, wxDefaultSize);

    $self->{rssilabel} = Wx::StaticText->new($self, -1, "RSSI", wxDefaultPosition, wxDefaultSize);
    $self->{rssitext} = Wx::TextCtrl->new($self, -1, "0", wxDefaultPosition, wxDefaultSize);

# Define Sizer Structure - My "Standard" Layout
# Assumes: One Main Sizer(Vertical)
#          One Header Sizer(Horizontal)
#	   One Body Sizer(Horizontal) containing
#              Left Body Sizer(Vertical)
#              Right Body Sizer(Vertical)
#          Three Footer Sizers(horizontal)
#

# Create Sizers
    my $mainSizer = Wx::BoxSizer->new(wxVERTICAL);
    $self->SetSizer($mainSizer);

    my $headerSizer = Wx::BoxSizer->new(wxHORIZONTAL);
    my $bodySizer = Wx::BoxSizer->new(wxHORIZONTAL);
    my $leftbodySizer = Wx::BoxSizer->new(wxVERTICAL);
    my $rightbodySizer = Wx::BoxSizer->new(wxVERTICAL);
    my $footer1Sizer = Wx::BoxSizer->new(wxHORIZONTAL);
    my $footer2Sizer = Wx::BoxSizer->new(wxHORIZONTAL);
    my $footer3Sizer = Wx::BoxSizer->new(wxHORIZONTAL);

# Layout Main Sizer
    $mainSizer->Add($headerSizer,0,0,0);
    $mainSizer->AddSpacer(20);
    $mainSizer->Add($bodySizer,0,0,0);
    $mainSizer->AddSpacer(30);
    $mainSizer->Add($footer1Sizer,0,0,0);
    $mainSizer->AddSpacer(10);
    $mainSizer->Add($footer2Sizer,0,0,0);
    $mainSizer->AddSpacer(10);
    $mainSizer->Add($footer3Sizer,0,0,0);

# Layout Header Sizer
    $headerSizer->AddSpacer(150);
    $headerSizer->Add($self->{titletext},0,0,0);

# Layout Body Sizer
    $bodySizer->Add($leftbodySizer,0,0,0);
    $bodySizer->AddSpacer(50);
    $bodySizer->Add($rightbodySizer,0,0,0);

# Layout Right and Left Body Sizers
    $leftbodySizer->Add($self->{bflabel},0,0,0);
    $leftbodySizer->Add($self->{bftext},0,0,0);
    $leftbodySizer->Add($self->{eflabel},0,0,0);
    $leftbodySizer->Add($self->{eftext},0,0,0);
    $leftbodySizer->Add($self->{fslabel},0,0,0);
    $leftbodySizer->Add($self->{fstext},0,0,0);
    $leftbodySizer->Add($self->{sllabel},0,0,0);
    $leftbodySizer->Add($self->{sltext},0,0,0);
    $leftbodySizer->Add($self->{splabel},0,0,0);
    $leftbodySizer->Add($self->{sptext},0,0,0);
    $leftbodySizer->Add($self->{lplabel},0,0,0);
    $leftbodySizer->Add($self->{lptext},0,0,0);

    $rightbodySizer->Add($self->{modbox},0,0,0);
    $rightbodySizer->AddSpacer(10);
    $rightbodySizer->Add($self->{rssilabel},0,0,0);
    $rightbodySizer->AddSpacer(10);
    $rightbodySizer->Add($self->{rssitext},0,0,0);

# Layout Footer Sizers
    $footer1Sizer->Add($self->{startbutton},0,0,0);
    $footer1Sizer->AddSpacer(10);
    $footer1Sizer->Add($self->{stopbutton},0,0,0);

    $footer2Sizer->Add($self->{connectbutton},0,0,0);
    $footer2Sizer->AddSpacer(10);
    $footer2Sizer->Add($self->{disconnectbutton},0,0,0);

    $footer3Sizer->Add($self->{quitbutton},0,0,0);

# Define Messaging Timer to schedule checking flags and displaying errors from the threads
    $self->{msgtimer} = Wx::Timer->new($self);

# Define Event Handlers
    Wx::Event::EVT_BUTTON($self, $self->{startbutton}, sub {
			  my ($self, $event) = @_;
			  if(!$common{connected}) {				# Can't start scaning if not connected
			      Wx::MessageBox("Telnet is not connected\nCannot start scanning",
			      "Telnet Connection Error", wxICON_ERROR, $self);
			  } else {
			      $common{beginf} = $self->{bftext}->GetValue*1000;		# Scale KHz to Hz
			      $common{endf} = $self->{eftext}->GetValue*1000;		# Scale KHz to Hz
			      $common{nextf} = $common{beginf};
			      $common{step} = $self->{fstext}->GetValue;
			      $common{squelch} = $self->{sltext}->GetValue;
			      $common{pause} = $self->{sptext}->GetValue/1000;		# Scale to msec
			      $common{listen} = $self->{lptext}->GetValue/1000;		# Scale to msec
			      $common{scanstart} = 1;
			      $self->{startbutton}->SetLabel("Scanning");		# Change button label to indicate status
			  }});

    Wx::Event::EVT_BUTTON($self, $self->{stopbutton}, sub {
			  my ($self, $event) = @_;
			  if(!$common{connected}) {				# Can't stop scanning if not connected
			      Wx::MessageBox("Telnet is not connected\nCannot stop scanning",
			      "Telnet Connection Error", wxICON_ERROR, $self);
			  } else {

			      $common{scanstart} = 0;
                              $common{scanstarted} = 0;
			      $self->{startbutton}->SetLabel("Start Scanning");	# Restore button label
			  }});

    Wx::Event::EVT_BUTTON($self, $self->{connectbutton}, sub {
			  my ($self, $event) = @_;
			  if(!$common{connected}) {
			      $common{mode} = $self->{modbox}->GetStringSelection;
			      $common{connect} = 1;
			      $self->{connectbutton}->SetLabel("Connected");	# Change button label to indicate status
			  }
			  });

    Wx::Event::EVT_BUTTON($self, $self->{disconnectbutton}, sub {
			  my ($self, $event) = @_;
			  if(!$common{connected}) {					# Can't disconnect if not connected
			      Wx::MessageBox("Telnet is not connected\nCannot Disconnect",
			      "Telnet Connection Error", wxICON_ERROR, $self);}
			  else {
				 if($common{connected}) {
			             $common{disconnect} = 1;
			             $self->{connectbutton}->SetLabel("Connect");	# Restore button label
                                 }
			         if($common{scanstarted}) {
                                     $common{scanstart} = 0;
                                     $common{scanstarted} = 0;
			             $self->{startbutton}->SetLabel("Start Scanning");	# Restore button label
                          }
			  }});

    Wx::Event::EVT_BUTTON($self, $self->{quitbutton}, sub {
			  my ($self, $event) = @_;
			  $common{stopthreads} = 1;
			  $self->Close;
			  });

    Wx::Event::EVT_TEXT($self, $self->{bftext}, sub {
			my ($self, $event) = @_;
			$self->{beginf} = $self->{bftext}->GetValue;
			});

    Wx::Event::EVT_TEXT($self, $self->{eftext}, sub {
			my ($self, $event) = @_;
			$self->{endf} = $self->{eftext}->GetValue;
			});

    Wx::Event::EVT_TEXT($self, $self->{fstext}, sub {
			my ($self, $event) = @_;
			$self->{step} = $self->{fstext}->GetValue;
			});

    Wx::Event::EVT_TEXT($self, $self->{sltext}, sub {
			my ($self, $event) = @_;
			$self->{squelch} = $self->{sltext}->GetValue;
			});

    Wx::Event::EVT_TEXT($self, $self->{sptext}, sub {
			my ($self, $event) = @_;
			$self->{pause} = $self->{sptext}->GetValue;
			});

    Wx::Event::EVT_TEXT($self, $self->{lptext}, sub {
			my ($self, $event) = @_;
			$self->{listen} = $self->{lptext}->GetValue;
			});

    Wx::Event::EVT_TEXT($self, $self->{rssitext}, sub {
			my ($self, $event) = @_;
			$self->{rssi} = $self->{rssitext}->GetValue;
			});

    Wx::Event::EVT_RADIOBOX($self, $self->{modbox}, sub {
			my ($self, $event) = @_;
			$self->{mode} = $self->{modbox}->GetStringSelection;
			});

    Wx::Event::EVT_TIMER($self, $self->{msgtimer}, sub {			# Display Error messages 
			if($common{tnerror}) {					# Telnet Error
			    Wx::MessageBox("Telnet Connection Failed", "gqrx Lite Scanner Error", wxICON_ERROR, $self);
			    $self->{connectbutton}->SetLabel("Connect");	# Restore button label
			    $common{tnerror} = 0;
			}
                        if($common{rssiupdate}) {
                            $self->{rssitext}->SetValue($common{rssi});
                            $common{rssiupdate} = 0;
                        }
			});

# Start Error Message Timer
    $self->{msgtimer}->Start(1000);						# 1 second period

# Assign mainSizer to the Frame and trigger layout

    $mainSizer->Fit($self);
    $mainSizer->Layout();



    return $self;
}
1;

