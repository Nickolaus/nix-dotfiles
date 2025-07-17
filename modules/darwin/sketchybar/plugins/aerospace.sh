#!/bin/bash

# AeroSpace integration plugin for SketchyBar
# Shows current workspace and handles workspace changes

# Get current focused workspace from AeroSpace
CURRENT_WORKSPACE=$(aerospace list-workspaces --focused)

# Update workspace indicators
for i in {1..9}; do
    if [ "$i" = "$CURRENT_WORKSPACE" ]; then
        # Highlight active workspace
        sketchybar --set space.$i background.drawing=on \
                                  background.color=0xff8aadf4 \
                                  label.color=0xff1e2030
    else
        # Inactive workspace
        sketchybar --set space.$i background.drawing=off \
                                  label.color=0xff6e738d
    fi
done 