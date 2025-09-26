#!/usr/bin/env bash
# i3blocks meeting script with mise support

# Set up environment
export HOME=${HOME:-/home/$(whoami)}

# Activate mise - eval the activation script
eval "$(/usr/local/bin/mise activate bash)"


# Get current time and tomorrow
now=$(date '+%Y-%m-%d %H:%M')
tomorrow=$(date -v+1d '+%Y-%m-%d %H:%M')

# Handle mouse clicks
if [ -n "$BLOCK_BUTTON" ]; then
    # Get the next meeting with conference details
    meeting_details=$(gcalcli --calendar "yevhenii.kurtov@dyad.net" --nocolor agenda --details conference --tsv "$now" "$tomorrow" 2>/dev/null | \
        awk -F'\t' 'NR>1 && $2!="" {print; exit}')
    
    if [ -n "$meeting_details" ]; then
        # Extract conference URL (usually in column 6 for conference details)
        conference_url=$(echo "$meeting_details" | cut -f6)
        
        # If no URL in column 6, try to find Meet/Zoom/Teams URLs in description
        if [ -z "$conference_url" ] || [ "$conference_url" = "None" ]; then
            # Get full event details including description
            event_title=$(echo "$meeting_details" | cut -f5)
            
            # Use gcalcli to get full event text and search for meeting URLs
            full_details=$(gcalcli --calendar "yevhenii.kurtov@dyad.net" --nocolor agenda --details all "$now" "$tomorrow" 2>/dev/null | \
                grep -A 10 "$event_title")
            
            # Look for common meeting URL patterns
            conference_url=$(echo "$full_details" | grep -oE 'https://meet\.google\.com/[a-z-]+' | head -1)
            
            # If no Google Meet, check for Zoom
            if [ -z "$conference_url" ]; then
                conference_url=$(echo "$full_details" | grep -oE 'https://[a-z0-9]+\.zoom\.us/[^ ]+' | head -1)
            fi
            
            # If no Zoom, check for Teams
            if [ -z "$conference_url" ]; then
                conference_url=$(echo "$full_details" | grep -oE 'https://teams\.microsoft\.com/[^ ]+' | head -1)
            fi
        fi
        
        # Open the URL if found
        if [ -n "$conference_url" ] && [ "$conference_url" != "None" ]; then
            # Try different methods to open URL
            if command -v chrome >/dev/null 2>&1; then
                chrome "$conference_url" &
            elif command -v chromium >/dev/null 2>&1; then
                chromium "$conference_url" &
            elif command -v google-chrome >/dev/null 2>&1; then
                google-chrome "$conference_url" &
            elif command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$conference_url" &
            else
                # Fallback: copy to clipboard
                echo "$conference_url" | xclip -selection clipboard 2>/dev/null || \
                echo "$conference_url" | wl-copy 2>/dev/null
            fi
        else
            # No meeting URL found - open Google Calendar instead
            if command -v chrome >/dev/null 2>&1; then
                chrome "https://calendar.google.com" &
            elif command -v chromium >/dev/null 2>&1; then
                chromium "https://calendar.google.com" &
            elif command -v xdg-open >/dev/null 2>&1; then
                xdg-open "https://calendar.google.com" &
            fi
        fi
    fi
    
    # Exit after handling click to prevent normal output
    exit 0
fi

# Normal operation - show next meeting
meeting=$(gcalcli --calendar "yevhenii.kurtov@dyad.net" --nocolor agenda --tsv "$now" "$tomorrow" 2>/dev/null | \
    awk -F'\t' 'NR>1 && $2!="" {print $1"\t"$2"\t"$5; exit}')

if [ -z "$meeting" ]; then
    echo "📅 No meetings"
    echo "📅 Free"
    echo "#888888"
    exit 0
fi

# Parse meeting details
meeting_date=$(echo "$meeting" | cut -f1)
meeting_time=$(echo "$meeting" | cut -f2)
meeting_title=$(echo "$meeting" | cut -f3 | cut -c1-40)

# Calculate time difference
meeting_epoch=$(date -j -f "%Y-%m-%d %H:%M" "$meeting_date $meeting_time" "+%s" 2>/dev/null)
current_epoch=$(date "+%s")
diff=$((meeting_epoch - current_epoch))

# Format time remaining
if [ $diff -lt 0 ]; then
    time_str="NOW"
    color="#FF0000"
elif [ $diff -lt 300 ]; then  # < 5 min
    time_str="$((diff / 60))m"
    color="#FF0000"
elif [ $diff -lt 900 ]; then  # < 15 min
    time_str="$((diff / 60))m"
    color="#FFA500"  
elif [ $diff -lt 3600 ]; then  # < 1 hour
    time_str="$((diff / 60))m"
    color="#FFA500"
elif [ $diff -lt 86400 ]; then  # < 24 hours
    hours=$((diff / 3600))
    minutes=$(((diff % 3600) / 60))
    if [ $minutes -gt 0 ]; then
        time_str="${hours}h ${minutes}m"
    else
        time_str="${hours}h"
    fi
    color="#00FF00"
else
    time_str=">24h"
    color="#00FF00"
fi

# Check if next meeting has a conference URL for visual indicator
has_meet=$(gcalcli --calendar "yevhenii.kurtov@dyad.net" --nocolor agenda --details conference --tsv "$now" "$tomorrow" 2>/dev/null | \
    awk -F'\t' 'NR>1 && $2!="" {print $6; exit}' | grep -E 'meet\.google\.com|zoom\.us|teams\.microsoft')

if [ -n "$has_meet" ]; then
    # Add a video icon if there's a meeting link
    echo "📅🔗 $time_str: $meeting_title"  # full text with link indicator
else
    echo "📅 $time_str: $meeting_title"     # full text without link
fi
echo "📅 $time_str"                         # short text
echo "$color"                               # color
