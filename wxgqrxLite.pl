#! /usr/bin/perl

# Name:			wxgqrxLite.pl - Simple gqrx SDR Scanner - wxPerl Version
# Author:		James M. Lynes, Jr.
# Created:		September 17, 2015
# Modified By:		James M. Lynes, Jr.
# Last Modified:	September 20, 2015
# Environment:		Ubuntu 14.04LTS / perl v5.18.2 / wxPerl 3.0.1 / HP 15 Quad Core
# Change Log:		9/17/2015 - Program Created
#			9/19/2015 - Added Title Text, Connection Error Popup, Sizers and Event Handlers
#				  - Scan and Listen Timers, Button Label Change as Status Indicator
#			9/20/2015 - Additional Comments, add additional error checking/processing
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
# 			Start gqrx and the gqrx Remote Control option before running this perl code.
#			An error window will popup if gqrx is not running with Remote Control enabled
#			when a connection request is made.
#

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
    my $frame = Frame->new();
    $frame->Show(1);
}

package Frame;
use strict;
use warnings;
use Wx qw(:everything);
use base qw(Wx::Frame);
use Data::Dumper;
use Net::Telnet;

sub new {
    my ($class, $parent) = @_;

    my $self = $class->SUPER::new($parent, -1, "gqrx Lite Scanner", wxDefaultPosition, wxDefaultSize);

# Defines
    $self->{ip} = "127.0.0.1";					# AKA Localhost Address
    $self->{port} = "7356";
    $self->{start} = 0;
    $self->{error} = 0;
    $self->{tnerror} = 0;
    $self->{connected} = 0;
 
# Create Title Text
    $self->{titletext} = Wx::StaticText->new($self, -1, "gqrx Lite Scanner", wxDefaultPosition, wxDefaultSize);

# Create Modulators Radio Box - First entry is the default
    my $modulators = ["FM", "AM", "WFM_ST", "WFM", "LSB", "USB", "CW", "CWL", "CWU"];
    $self->{modbox} = Wx::RadioBox->new($self, -1, "Modulators", wxDefaultPosition, wxDefaultSize,
                      $modulators, 3, wxRA_SPECIFY_COLS);    

# Create Buttons
    $self->{startbutton}      = Wx::Button->new($self, -1, "Start Scanning", wxDefaultPosition, wxDefaultSize);
    $self->{stopbutton}       = Wx::Button->new($self, -1, "Stop Scanning", wxDefaultPosition, wxDefaultSize);
    $self->{connectbutton}    = Wx::Button->new($self, -1, "Connect", wxDefaultPosition, wxDefaultSize);
    $self->{disconnectbutton} = Wx::Button->new($self, -1, "Disconnect", wxDefaultPosition, wxDefaultSize);
    $self->{quitbutton}       = Wx::Button->new($self, -1, "Quit", wxDefaultPosition, wxDefaultSize);

# Create Data Entry Prompts and Boxes
    $self->{bflabel} = Wx::StaticText->new($self, -1, "Beginning Frequency", wxDefaultPosition, wxDefaultSize);
    $self->{bftext} = Wx::TextCtrl->new($self, -1, "144000000", wxDefaultPosition, wxDefaultSize);

    $self->{eflabel} = Wx::StaticText->new($self, -1, "Ending Frequency", wxDefaultPosition, wxDefaultSize);
    $self->{eftext} = Wx::TextCtrl->new($self, -1, "144100000", wxDefaultPosition, wxDefaultSize);

    $self->{fslabel} = Wx::StaticText->new($self, -1, "Frequency Step", wxDefaultPosition, wxDefaultSize);
    $self->{fstext} = Wx::TextCtrl->new($self, -1, "1000", wxDefaultPosition, wxDefaultSize);

    $self->{sllabel} = Wx::StaticText->new($self, -1, "Squelch Level", wxDefaultPosition, wxDefaultSize);
    $self->{sltext} = Wx::TextCtrl->new($self, -1, "-60.0", wxDefaultPosition, wxDefaultSize);

    $self->{splabel} = Wx::StaticText->new($self, -1, "Scan Pause, ms", wxDefaultPosition, wxDefaultSize);
    $self->{sptext} = Wx::TextCtrl->new($self, -1, "20", wxDefaultPosition, wxDefaultSize);

    $self->{lplabel} = Wx::StaticText->new($self, -1, "Listen Pause, ms", wxDefaultPosition, wxDefaultSize);
    $self->{lptext} = Wx::TextCtrl->new($self, -1, "1000", wxDefaultPosition, wxDefaultSize);

    $self->{rssilabel} = Wx::StaticText->new($self, -1, "RSSI", wxDefaultPosition, wxDefaultSize);
    $self->{rssitext} = Wx::TextCtrl->new($self, -1, "0", wxDefaultPosition, wxDefaultSize);

# Sizer Structure
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

# Create Timers - Used to flip between scan and listen modes
    $self->{ptimer} = Wx::Timer->new($self);			# Sets the scan cycle time
    $self->{ltimer} = Wx::Timer->new($self);			# Sets the signal listen time

# Define Event Handlers

    Wx::Event::EVT_BUTTON($self, $self->{startbutton}, sub {
			  my ($self, $event) = @_;
			  if(!$self->{connected}) {				# Can't start scaning if not connected
			      Wx::MessageBox("Telnet is not connected\nCannot start scanning",
			      "Telnet Connection Error", wxICON_ERROR, $self);
			  } else {
			  $self->{started} = 1;
			  $self->{beginf} = $self->{bftext}->GetValue;		# Copy in working data
			  $self->{endf} = $self->{eftext}->GetValue;
			  $self->{step} = $self->{fstext}->GetValue;
			  $self->{squelch} = $self->{sltext}->GetValue;
			  $self->{pause} = $self->{sptext}->GetValue;
			  $self->{listen} = $self->{lptext}->GetValue;
			  $self->{mode} = $self->{modbox}->GetStringSelection;
			  $self->{start} = $self->{beginf};
			  $self->{startbutton}->SetLabel("Scanning");		# Change button label to indicate status
			  $self->{ptimer}->Start($self->{pause});		# Start the scan cycle
			  }});

    Wx::Event::EVT_BUTTON($self, $self->{stopbutton}, sub {
			  my ($self, $event) = @_;
			  if(!$self->{connected}) {				# Can't stop scanning if not connected
			      Wx::MessageBox("Telnet is not connected\nCannot stop scanning",
			      "Telnet Connection Error", wxICON_ERROR, $self);
			  } else {
			  $self->{started} = 0;
			  $self->{startbutton}->SetLabel("Start Scanning");	# Restore button label
			  $self->{ptimer}->Stop;				# Stop scan cycle
			  $self->{ltimer}->Stop;				# Stop listen cycle
			  }});

    Wx::Event::EVT_BUTTON($self, $self->{connectbutton}, sub {
			  my ($self, $event) = @_;
print Dumper $self->{tnerror};
			  $self->{telnetsession} = Net::Telnet->new(Timeout => 2, port => $self->{port},
			  Errmode => sub { $self->{tnerror} = 1; });
print Dumper $self->{tnerror};
sleep(5);
			  if($self->{tnerror}) {$self->{error} = Wx::MessageBox(
			  "gqrx is probably not running\nStart gqrx then restart wxgqrxLite",
			  "Telnet Connection Error", wxICON_ERROR, $self);}
			  if(! $self->{tnerror}) {					# Can't complete connection sequence
print Dumper $self->{tnerror};
			  $self->{telnetsession}->open($self->{ip});
			  $self->{connectbutton}->SetLabel("Connected");	# Change button label to indicate status
			  $self->{connected} = 1;
			  }
print Dumper $self;
			  });

    Wx::Event::EVT_BUTTON($self, $self->{disconnectbutton}, sub {
			  my ($self, $event) = @_;
print "D\n";
			  if(!$self->{connected}) {
			     $self->{error} = Wx::MessageBox("Telnet is not connected\nCannot disconnect",
			      "Telnet Connection Error", wxICON_ERROR, $self);
			  } else {						# Can't complete disconnection sequence
			  $self->{telnetsession}->print("c");
			  $self->{connectbutton}->SetLabel("Connect");		# Restore button label
			  $self->{connected} = 0;
			#  $self->{error} = 0;
			  }});

    Wx::Event::EVT_BUTTON($self, $self->{quitbutton}, sub {
			  my ($self, $event) = @_;
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

    Wx::Event::EVT_TIMER($self, $self->{ptimer}, sub {				# Scan Mode 
			my ($self, $event) = @_;
			$self->{telnetsession}->print("F $self->{start}");	# Set frequency
			$self->{telnetsession}->waitfor(Match => 'RPRT', Timeout => 5, Errmode => "return");

			$self->{telnetsession}->print("l");			# Get RSSI -##.#
			my ($prematch, $rssi) = $self->{telnetsession}->waitfor(Match => '/-{0,1}\d+\.\d/',
						 Timeout => 5, Errmode => "return");

			if(!defined($rssi)) {$event->Skip()};			# Occasional bad read
			if($rssi >= $self->{squelch}) {				# Got a strong signal
			    $self->{ptimer}->Stop;				# Stop scan
			    $self->{ltimer}->Start($self->{listen});		# Start listen
			    $self->{rssitext}->SetValue($rssi);			# Display RSSI value
			    }
			$self->{start} = $self->{start} + $self->{step};	# Increment the frequency
			if($self->{start} >= $self->{endf}) {$self->{start} = $self->{beginf}}; # Wrap back around
			});

    Wx::Event::EVT_TIMER($self, $self->{ltimer}, sub {				# Listen mode - Runs once per RSSI trigger
			my ($self, $event) = @_;
			$self->{ltimer}->Stop;					# Stop listen mode
			$self->{ptimer}->Start($self->{pause});			# Restart scan mode
			});
# Assign mainSizer to the Frame and trigger layout

    $mainSizer->Fit($self);
    $mainSizer->Layout();



    return $self;
}
1;

