#!/usr/bin/env bash
# This is free and unencumbered software released into the public domain.
# Author: NotAlexNoyle (admin@true-og.net)

# Spinner function in pure bash
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep "$delay"
    printf "\b\b\b\b\b\b"
  done
  # Clean up spinner remains
  printf "    \b\b\b\b"
}

# Prompt whether to import or export
read -rp "Would you like to import or export? [import/export]: " ACTION

# Prompt for credentials
read -rp "Enter your MariaDB username: " DB_USER
read -srp "Enter your MariaDB password: " DB_PASS
echo

# List of databases to process
databases=(
  "bounty_hunters"
  #"core_protect"
  "cosmetics_og"
  "gamemodeinventories"
  #"luckperms"
  "playtimes"
  "quickshop"
  "unions"
)

# Perform the chosen action
case "$ACTION" in
  import)
    # Drop & Create databases
    for db in "${databases[@]}"; do
      echo "Dropping database '$db' (if it exists)..."
      mariadb-admin -u"$DB_USER" -p"$DB_PASS" -f drop "$db" 2>/dev/null

      echo "Creating database '$db'..."
      mariadb-admin -u"$DB_USER" -p"$DB_PASS" create "$db"
    done

    # Import .txt files (show a spinner for each import)
    echo "Starting import..."
    for db in "${databases[@]}"; do
      if [[ -f "${db}.txt" ]]; then
        echo "Importing data into '$db' from '${db}.txt'..."
        mariadb -u"$DB_USER" -p"$DB_PASS" "$db" < "${db}.txt" &
        import_pid=$!
        spinner "$import_pid"
        wait "$import_pid"
        echo " Imported '$db' successfully."
      else
        echo "Warning: '${db}.txt' not found. Skipping import for '$db'."
      fi
    done

    echo "Database import complete."
    ;;

  export)
    # Remove old backup if it exists
    [ -f databases.tar ] && rm databases.tar

    # Export each database (show a spinner for each export)
    echo "Starting export..."
    for db in "${databases[@]}"; do
      echo "Exporting '$db'..."
      mariadb-dump --no-tablespaces --single-transaction -u"$DB_USER" -p"$DB_PASS" "$db" > "${db}.txt" &
      export_pid=$!
      spinner "$export_pid"
      wait "$export_pid"
      echo " Exported '$db' successfully."
    done

    # Archive the backups
    echo "Creating archive 'databases.tar'..."
    tar -cvf databases.tar *.txt

    echo "Database export complete."

    # Optionally send via Magic Wormhole
    read -rp "Would you like to send the databases with magic wormhole? [y/n]: " SEND_WORMHOLE
    if [[ "$SEND_WORMHOLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      if command -v wormhole >/dev/null 2>&1; then
        wormhole send databases.tar
      else
        echo "Magic Wormhole is not installed on this system. Please install it and try again."
      fi
    fi
    ;;

  *)
    echo "Invalid option. Please run the script again and choose 'import' or 'export'."
    exit 1
    ;;
esac
