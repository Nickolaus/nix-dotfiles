#!/bin/bash

# Front application plugin for SketchyBar
# Shows the currently focused application

# Get the front application
FRONT_APP=$(aerospace list-windows --focused --format %{app-name})

# If no focused app, get from System Events
if [ -z "$FRONT_APP" ]; then
    FRONT_APP=$(osascript -e 'tell application "System Events" to get name of (processes where frontmost is true)')
fi

# Limit length for display
if [ ${#FRONT_APP} -gt 25 ]; then
    FRONT_APP="${FRONT_APP:0:22}..."
fi

# Update the front app display
sketchybar --set "$NAME" label="$FRONT_APP" 