#!/usr/bin/env bash
# This is free and unencumbered software released into the public domain.
# Author: NotAlexNoyle (admin@true-og.net)

# Moves all plugin JARs that start with a letter greater than an alphabetically specified boundary letter into a "disabled" folder.

# Example usage:
#   ./plugin-triage.sh M
#   => Moves any plugin that starts with N or higher into the disabled/ folder.

# The letter boundary, passed as the first argument to the script
BOUNDARY="$1"

# The folder containing your plugins (adjust if different)
PLUGIN_DIR="plugins"

# Create the disabled folder if it doesn't already exist
mkdir -p "$PLUGIN_DIR/disabled"

# Loop over all .jar files in the plugin directory
for plugin in "$PLUGIN_DIR"/*.jar; do
  # Ignore if no jars found
  [ -e "$plugin" ] || continue

  # Extract just the filename from the path
  plugin_name="$(basename "$plugin")"

  # Get the first character of the filename
  first_letter="${plugin_name:0:1}"

  # Compare letters (in ASCII order)
  # If the first_letter is "greater" than the BOUNDARY, move the file
  if [[ "$first_letter" > "$BOUNDARY" ]]; then
    echo "Moving $plugin_name to disabled folder."
    mv "$plugin" "$PLUGIN_DIR/disabled/"
  fi
done
