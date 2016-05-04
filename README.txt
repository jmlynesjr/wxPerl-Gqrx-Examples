Perl and wxPerl "Plug-in" scripts for the Gqrx Software Defined Radio(SDR) Package

    Gqrx requires an RF input device like a DVB-T USB dongle(24-1700 MHz)
    Gqrx may require an upconverter to receive HF(1-30 MHz) depending on the chosen dongle
    Gqrx can be controlled via a Telnet connection using a subset of the RigControl Protocol
    Gqrx can output demodulated Raw Audio via UDP packets
    Gqrx distributes audio to Plug-in decoder applications like fldigi via Pulse Audio

James M. Lynes Jr. May 4, 2016

--------------------------------------------------------------------------------------------

Scanner Plug-ins(Telnet)
------------------------
lite.pl                     - Perl Scanner proof of concept - nonGUI
wxgqrxLite.pl               - wxPerl Scanner proof of concept - GUI
threadedgqrxLite.pl         - wxPerl Scanner - GUI - wxPerl with Perl Threads(good threads example)
w1awCode.pl                 - wxPerl Scanner that push button tunes to ARRL code practice frequencies

Raw Audio Plot Plug-ins(UDP)
----------------------------
udp.pl                      - Perl UDP packet receiver/decoder proof of concept
udpserver.pl                - Perl UDP packet builder/sender(for stand-alone testing of GqrxRawAudioPlot.pl)
GqrxRawAudioPlot.pl         - wxPerl Raw Audio Plotter
rawaudio4.png               - Sample Plot snapshot
README.txt                  - This File

