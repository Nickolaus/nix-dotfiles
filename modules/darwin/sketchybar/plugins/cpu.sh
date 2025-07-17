#!/bin/bash

# CPU usage plugin for SketchyBar
# Shows current CPU utilization percentage

# Get CPU usage using top command
CPU_USAGE=$(top -l 1 | grep -E "^CPU" | grep -Eo '[0-9]*\.[0-9]*%' | head -1 | sed 's/%//')

# Convert to integer for comparison
CPU_INT=${CPU_USAGE%.*}

# Set color based on usage
if [ "$CPU_INT" -gt 80 ]; then
    COLOR="0xffed8796"  # Red for high usage
elif [ "$CPU_INT" -gt 50 ]; then
    COLOR="0xfff5a97f"  # Orange for medium usage
else
    COLOR="0xffa6da95"  # Green for low usage
fi

# Update the display
sketchybar --set "$NAME" icon= \
                         label="${CPU_USAGE%.*}%" \
                         icon.color="$COLOR" 