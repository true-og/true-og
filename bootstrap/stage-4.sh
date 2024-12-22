#!/usr/bin/env bash
#
# bootstrap-purpur.sh
#
# Fetches and builds Purpur, publishing it locally and copying a Purpur jar to ../server/.

set -euo pipefail

ORIGINAL_PATH="$PATH"
WORK_DIR="$(pwd)"
GRADLE_USER_HOME="$WORK_DIR/.gradle"
SELF_MAVEN_LOCAL_REPO="$WORK_DIR/.m2/repository"
PURPUR_BRANCH="ver/1.19.4"  # Adjust as needed

# Function to handle script interruption
cleanup() {
    echo
    echo "ERROR: Script interrupted! There may be build artifacts left over. Please clean up before running again."
    tput cnorm 2>/dev/null || true  # Restore cursor if tput is available
    export PATH="$ORIGINAL_PATH"
    exit 1
}

# Trap SIGINT (Ctrl+C)
trap cleanup SIGINT

# Spinner
spinner() {
    local pid=$1
    local message="$2"
    local spin='-\|/'
    local i=0
    tput civis 2>/dev/null || true

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r[%c] %s" "${spin:$i:1}" "$message"
        sleep 0.1
    done

    tput cnorm 2>/dev/null || true
    printf "\r[✓] %s\n" "$message"
}

echo "Bootstrapping Purpur..."

# We assume you have a sibling directory "Purpur" already cloned. For example:
#   yourfolder/
#     ├─ bootstrap/  (where this script runs)
#     └─ Purpur/     (the Purpur git repository)
#
# Also assume you have a sibling folder "server/" for the final .jar.

# 1. Navigate to the Purpur directory
if [ ! -d ../Purpur ]; then
  echo "Error: ../Purpur directory not found. Please clone Purpur in a sibling directory named 'Purpur'."
  exit 1
fi

cd ../Purpur

# 2. Fetch the latest changes
git fetch origin "$PURPUR_BRANCH"

LOCAL_HASH=$(git rev-parse HEAD)
REMOTE_HASH=$(git rev-parse "origin/$PURPUR_BRANCH")

# 3. Check if we already have a jar
PURPUR_JAR_FILE="$(ls build/libs/purpur-*.jar 2>/dev/null || true)"

echo "Using system java for Purpur build:"
java -version || true  # Just to show Java version

# 4. If no jar found OR there are updates on remote, build
if [ -z "$PURPUR_JAR_FILE" ] || [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
    if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
        echo "Purpur repository has updates. Resetting to $PURPUR_BRANCH..."
        git reset --hard "origin/$PURPUR_BRANCH"
    fi

    # Step 1: applyPatches
    message="[1/4] Applying Purpur patches..."
    (
      ./gradlew applyPatches --gradle-user-home "$GRADLE_USER_HOME" >/dev/null 2>&1
    ) &
    spinner $! "$message"

    # Step 2: build
    message="[2/4] Building Purpur..."
    (
      ./gradlew build --gradle-user-home "$GRADLE_USER_HOME" >/dev/null 2>&1
    ) &
    spinner $! "$message"

    # Step 3: createMojmapBundlerJar
    message="[3/4] Creating Mojmap Bundler Jar..."
    (
      ./gradlew createMojmapBundlerJar --gradle-user-home "$GRADLE_USER_HOME" >/dev/null 2>&1
    ) &
    spinner $! "$message"

    # Step 4: publishToMavenLocal
    message="[4/4] Publishing Purpur to Maven Local..."
    (
      ./gradlew publishToMavenLocal --gradle-user-home "$GRADLE_USER_HOME" >/dev/null 2>&1
    ) &
    spinner $! "$message"

    # Copy fresh Purpur jar to ../server/
    mkdir -p ../server
    cp build/libs/purpur-*.jar ../server/
    echo "Bootstrapping of Purpur complete."
    echo "Local Gradle home: $GRADLE_USER_HOME"
    echo "Local Maven repo: $SELF_MAVEN_LOCAL_REPO"
else
    echo "Purpur is up-to-date and the jar file already exists. Skipping build."
fi

# Return to the bootstrap directory (or wherever we started)
cd "$WORK_DIR" || {
    echo "Failed to navigate back to $WORK_DIR"
    exit 1
}

# Optionally remove any Mojmap jar from server if you don’t need it
rm -f ../server/purpur-bundler-*-mojmap.jar 2>/dev/null || true

echo "Done."

