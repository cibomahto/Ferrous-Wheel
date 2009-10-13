#!/bin/bash

# Start the screensaver blocker (otherwise it blanks after 2 hours)
/home/ferrous/sketchbook/ferrous_wheel/stop_screensaver.sh &

# Launch the synthesizer (zynaddsubfx)
zynaddsubfx -r 22050 -b 1024 -o 1024 -A &

# Launch the ferrous wheel program
cd /home/ferrous/sketchbook/ferrous_wheel/application.linux/
./ferrous_wheel &

# Sleep for a bit to let everything start up
sleep 10

# Then route the midi output from the ferrous wheel to the synth
aconnect `aconnect -ol | grep 'Virtual Raw MIDI' | cut -d\  -f 2 | cut -d\: -f 1` 128

