#!/bin/bash

# Clock plugin for SketchyBar
# Shows current date and time

# Get current date and time
DATETIME=$(date '+%a %d %b %H:%M')

# Update the display
sketchybar --set "$NAME" icon= \
                         label="$DATETIME" \
                         icon.color=0xff8aadf4 