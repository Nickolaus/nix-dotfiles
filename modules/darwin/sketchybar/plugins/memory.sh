#!/bin/bash

# Memory usage plugin for SketchyBar
# Shows current memory utilization

# Get memory info using vm_stat
VM_STAT=$(vm_stat)

# Extract memory statistics
PAGES_FREE=$(echo "$VM_STAT" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
PAGES_ACTIVE=$(echo "$VM_STAT" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
PAGES_INACTIVE=$(echo "$VM_STAT" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
PAGES_SPECULATIVE=$(echo "$VM_STAT" | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')
PAGES_WIRED=$(echo "$VM_STAT" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')

# Calculate memory usage (4KB per page)
PAGE_SIZE=4096
TOTAL_PAGES=$((PAGES_FREE + PAGES_ACTIVE + PAGES_INACTIVE + PAGES_SPECULATIVE + PAGES_WIRED))
USED_PAGES=$((PAGES_ACTIVE + PAGES_INACTIVE + PAGES_SPECULATIVE + PAGES_WIRED))

# Convert to GB
TOTAL_GB=$((TOTAL_PAGES * PAGE_SIZE / 1024 / 1024 / 1024))
USED_GB=$((USED_PAGES * PAGE_SIZE / 1024 / 1024 / 1024))

# Calculate percentage
if [ "$TOTAL_GB" -gt 0 ]; then
    PERCENTAGE=$((USED_GB * 100 / TOTAL_GB))
else
    PERCENTAGE=0
fi

# Set color based on usage
if [ "$PERCENTAGE" -gt 80 ]; then
    COLOR="0xffed8796"  # Red for high usage
elif [ "$PERCENTAGE" -gt 60 ]; then
    COLOR="0xfff5a97f"  # Orange for medium usage
else
    COLOR="0xffa6da95"  # Green for low usage
fi

# Update the display
sketchybar --set "$NAME" icon= \
                         label="${USED_GB}G/${TOTAL_GB}G" \
                         icon.color="$COLOR" 