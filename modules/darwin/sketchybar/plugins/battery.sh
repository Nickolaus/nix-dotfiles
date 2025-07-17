#!/bin/bash

# Battery plugin for SketchyBar
# Shows current battery level and charging status

# Get battery information
BATTERY_INFO=$(pmset -g batt | grep "Internal")

# Extract battery percentage
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -o "[0-9]*%" | sed 's/%//')

# Check if charging
if echo "$BATTERY_INFO" | grep -q "AC Power"; then
    CHARGING=true
    ICON=""  # Charging icon
elif echo "$BATTERY_INFO" | grep -q "charging"; then
    CHARGING=true
    ICON=""  # Charging icon
else
    CHARGING=false
    # Battery level icons
    if [ "$PERCENTAGE" -gt 90 ]; then
        ICON=""
    elif [ "$PERCENTAGE" -gt 75 ]; then
        ICON=""
    elif [ "$PERCENTAGE" -gt 50 ]; then
        ICON=""
    elif [ "$PERCENTAGE" -gt 25 ]; then
        ICON=""
    else
        ICON=""
    fi
fi

# Set color based on battery level
if [ "$PERCENTAGE" -lt 20 ] && [ "$CHARGING" = false ]; then
    COLOR="0xffed8796"  # Red for low battery
elif [ "$PERCENTAGE" -lt 40 ] && [ "$CHARGING" = false ]; then
    COLOR="0xfff5a97f"  # Orange for medium-low battery
else
    COLOR="0xffa6da95"  # Green for good battery
fi

# Update the display
sketchybar --set "$NAME" icon="$ICON" \
                         label="$PERCENTAGE%" \
                         icon.color="$COLOR" 