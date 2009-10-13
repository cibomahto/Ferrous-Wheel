#!/bin/bash

while true; do
  echo "Poking screensaver"
  gnome-screensaver-command -p
  sleep 1200
done
