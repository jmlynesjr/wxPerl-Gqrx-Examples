#! /usr/bin/perl

# Name:			w1awCode.pl - Tune gqrx to W1AW Code Practice Frequencies
#			              Cloned from threadedgqrxLite.pl
# Author:		James M. Lynes, Jr.
# Created:		October 27, 2015
# Modified By:		James M. Lynes, Jr.
# Last Modified:	October 27, 2015
# Environment:		Ubuntu 14.04LTS / perl v5.18.2 / wxPerl 3.0.1 / HP 15 Quad Core
# Change Log:		10/27/2015 - Program Cloned
#
# Description:		Tune gqrx via push buttons to the W1AW code practice frequencies.
#			Frequency update is sent to gqrx each time the Tune button is pushed.
#			(uses the remote control feature of gqrx,
#			a small subset of the amateur radio rigctrl protocol)
#
# 			gqrx is a software defined receiver powered by GNU-Radio and QT
#    			Developed by Alex Csete - gqrx.dk
#			The latest version is at sudo add-apt-repository ppa:gqrx/snapshots
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
# Notes:		

package main;
use strict;
use warnings;
use Net::Telnet;
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
    $common{tune} = 0;			# Command
    $common{f} = 0;	        	# Receive Frequency
    $common{squelch} = 0;		# Minimum RSSI(Recieved Signal Strength Indicator)
    $common{rssi} = 0;			# Latest RSSI
    $common{rssiupdate} = 0;		# RSSI Update Command
    $common{mode} = "CW";		# Demodulator Type - CW for code practice
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

        if($common{tune}) {						# Process Tune Command

                $common{tune} = 0;
                $telnetsession->print("F $common{f}");			# Update frequency
                $telnetsession->waitfor(Match => 'RPRT', Timeout => 5, Errmode => "return");
                $telnetsession->print("l");				# Get RSSI
                my ($prematch, $rssi) = $telnetsession->waitfor(Match => '/-{0,1}\d+\.\d/',
                                        Timeout => 5, Errmode => "return");

                if(defined($rssi)) {
                    if($rssi >= $common{squelch}) {			# Update the RSSI display
                        $common{rssi} = $rssi;
                        $common{rssiupdate} = 1;
                    }
                }
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
    my $self = $class->SUPER::new($parent, -1, "W1AW Code Practice Tuner", wxDefaultPosition, wxDefaultSize);
 
# Create Title Text
    $self->{titletext} = Wx::StaticText->new($self, -1, "W1AW Code Practice Tuner\n\n4pm, 7pm, 10pm EST",
                                             wxDefaultPosition, wxDefaultSize);

# Create Buttons
    $self->{button80m}        = Wx::Button->new($self, -1, "80 Meters", wxDefaultPosition, wxDefaultSize);
    $self->{button40m}        = Wx::Button->new($self, -1, "40 Meters", wxDefaultPosition, wxDefaultSize);
    $self->{button20m}        = Wx::Button->new($self, -1, "20 Meters", wxDefaultPosition, wxDefaultSize);
    $self->{button17m}        = Wx::Button->new($self, -1, "17 Meters", wxDefaultPosition, wxDefaultSize);
    $self->{button15m}        = Wx::Button->new($self, -1, "15 Meters", wxDefaultPosition, wxDefaultSize);
    $self->{button10m}        = Wx::Button->new($self, -1, "10 Meters", wxDefaultPosition, wxDefaultSize);
    $self->{tunebutton}       = Wx::Button->new($self, -1, "Tune", wxDefaultPosition, wxDefaultSize);
    $self->{connectbutton}    = Wx::Button->new($self, -1, "Connect", wxDefaultPosition, wxDefaultSize);
    $self->{disconnectbutton} = Wx::Button->new($self, -1, "Disconnect", wxDefaultPosition, wxDefaultSize);
    $self->{quitbutton}       = Wx::Button->new($self, -1, "Quit", wxDefaultPosition, wxDefaultSize);

# Create Data Entry Prompts and Boxes
    $self->{flabel} = Wx::StaticText->new($self, -1, "Frequency, KHz", wxDefaultPosition, wxDefaultSize);
    $self->{ftext} = Wx::TextCtrl->new($self, -1, "0", wxDefaultPosition, wxDefaultSize);

    $self->{sllabel} = Wx::StaticText->new($self, -1, "Squelch Level", wxDefaultPosition, wxDefaultSize);
    $self->{sltext} = Wx::TextCtrl->new($self, -1, "-60.0", wxDefaultPosition, wxDefaultSize);

    $self->{rssilabel} = Wx::StaticText->new($self, -1, "RSSI", wxDefaultPosition, wxDefaultSize);
    $self->{rssitext} = Wx::TextCtrl->new($self, -1, "0", wxDefaultPosition, wxDefaultSize);

# Define Sizer Structure - My "Standard" Layout
# Assumes: One Main Sizer(Horizontal)
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
    $headerSizer->AddSpacer(50);
    $headerSizer->Add($self->{titletext},0,0,0);

# Layout Body Sizer
    $bodySizer->Add($leftbodySizer,0,0,0);
    $bodySizer->AddSpacer(50);
    $bodySizer->Add($rightbodySizer,0,0,0);

# Layout Right and Left Body Sizers
    $leftbodySizer->Add($self->{flabel},0,0,0);
    $leftbodySizer->Add($self->{ftext},0,0,0);
    $leftbodySizer->Add($self->{sllabel},0,0,0);
    $leftbodySizer->Add($self->{sltext},0,0,0);
    $leftbodySizer->Add($self->{rssilabel},0,0,0);
    $leftbodySizer->Add($self->{rssitext},0,0,0);

    $rightbodySizer->Add($self->{button80m},0,0,0);
    $rightbodySizer->AddSpacer(10);
    $rightbodySizer->Add($self->{button40m},0,0,0);
    $rightbodySizer->AddSpacer(10);
    $rightbodySizer->Add($self->{button20m},0,0,0);
    $rightbodySizer->AddSpacer(10);
    $rightbodySizer->Add($self->{button17m},0,0,0);
    $rightbodySizer->AddSpacer(10);
    $rightbodySizer->Add($self->{button15m},0,0,0);
    $rightbodySizer->AddSpacer(10);
    $rightbodySizer->Add($self->{button10m},0,0,0);

# Layout Footer Sizers
    $footer1Sizer->Add($self->{tunebutton},0,0,0);

    $footer2Sizer->Add($self->{connectbutton},0,0,0);
    $footer2Sizer->AddSpacer(10);
    $footer2Sizer->Add($self->{disconnectbutton},0,0,0);

    $footer3Sizer->Add($self->{quitbutton},0,0,0);

# Define Messaging Timer to schedule checking flags and displaying errors from the threads
    $self->{msgtimer} = Wx::Timer->new($self);

# Define Event Handlers
    Wx::Event::EVT_BUTTON($self, $self->{tunebutton}, sub {
			  my ($self, $event) = @_;
			  if(!$common{connected}) {				# Can't start scaning if not connected
			      Wx::MessageBox("Telnet is not connected\nCannot tune",
			      "Telnet Connection Error", wxICON_ERROR, $self);
			  } else {
			      $common{f} = $self->{ftext}->GetValue*1000;		# Scale KHz to Hz
			      $common{squelch} = $self->{sltext}->GetValue;
			      $common{tune} = 1;
			  }});

    Wx::Event::EVT_BUTTON($self, $self->{connectbutton}, sub {
			  my ($self, $event) = @_;
			  if(!$common{connected}) {
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
			  }});

    Wx::Event::EVT_BUTTON($self, $self->{quitbutton}, sub {
			  my ($self, $event) = @_;
			  $common{stopthreads} = 1;
			  $self->Close;
			  });

    Wx::Event::EVT_BUTTON($self, $self->{button80m}, sub {
			  my ($self, $event) = @_;
			  $self->{ftext}->SetValue(3581.5);
			  });

    Wx::Event::EVT_BUTTON($self, $self->{button40m}, sub {
			  my ($self, $event) = @_;
			  $self->{ftext}->SetValue(7047.5);
			  });

    Wx::Event::EVT_BUTTON($self, $self->{button20m}, sub {
			  my ($self, $event) = @_;
			  $self->{ftext}->SetValue(14047.5);
			  });

    Wx::Event::EVT_BUTTON($self, $self->{button17m}, sub {
			  my ($self, $event) = @_;
			  $self->{ftext}->SetValue(18097.5);
			  });

    Wx::Event::EVT_BUTTON($self, $self->{button15m}, sub {
			  my ($self, $event) = @_;
			  $self->{ftext}->SetValue(21067.5);
			  });

    Wx::Event::EVT_BUTTON($self, $self->{button10m}, sub {
			  my ($self, $event) = @_;
			  $self->{ftext}->SetValue(28067.5);
			  });

    Wx::Event::EVT_TEXT($self, $self->{ftext}, sub {
			my ($self, $event) = @_;
			$self->{f} = $self->{ftext}->GetValue;
			});

    Wx::Event::EVT_TEXT($self, $self->{sltext}, sub {
			my ($self, $event) = @_;
			$self->{squelch} = $self->{sltext}->GetValue;
			});


    Wx::Event::EVT_TEXT($self, $self->{rssitext}, sub {
			my ($self, $event) = @_;
			$self->{rssi} = $self->{rssitext}->GetValue;
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

