#!/usr/bin/env bash
# This is free and unencumbered software released into the public domain.
# Author: NotAlexNoyle (admin@true-og.net)

# Prompt for MySQL username and password once.
read -rp "Enter your MySQL username: " DB_USER
read -srp "Enter your MySQL password: " DB_PASS
# Move to the next line after password input.
echo

# List of databases.
databases=(
  "bounty_hunters"
  "core_protect"
  "images"
  "luckperms"
  "quickshop"
  "tab"
  "gamemodeinventories"
  "unions"
  "playtimes"
)

# Drop & Create databases in a loop.
for db in "${databases[@]}"; do
  echo "Dropping database '$db' (if it exists)..."
  mysqladmin -u"$DB_USER" -p"$DB_PASS" -f drop "$db" 2>/dev/null

  echo "Creating database '$db'..."
  mysqladmin -u"$DB_USER" -p"$DB_PASS" create "$db"
done

# Import .txt files using pv for a progress bar.
echo "Starting import..."
for db in "${databases[@]}"; do
  # Confirm file exists before import.
  if [[ -f "${db}.txt" ]]; then
    echo "Importing data into '$db' from '${db}.txt'..."
    pv "${db}.txt" | mysql -u"$DB_USER" -p"$DB_PASS" "$db"
  else
    echo "Warning: '${db}.txt' not found. Skipping import for '$db'."
  fi
done

# Tell the user it is finished.
echo "All done!"
