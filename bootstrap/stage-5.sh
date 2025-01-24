#!/usr/bin/env bash
# This is free and unencumbered software released into the public domain.
# Author: NotAlexNoyle (admin@true-og.net)

# TrueOG Bootstrap stage 5: Server assembly with sdkman and Purpur.

# Set strict fail-on-error policy.
set -euo pipefail

WORK_DIR="$(pwd)"
PURPUR_BRANCH="ver/1.19.4"

# The final jar will be placed one directory above WORK_DIR:
FINAL_JAR_PATH="$WORK_DIR/../purpur-1.19.4.jar"

# Non-interactive for SDKMAN:
export SDKMAN_NON_INTERACTIVE=true

###############################################################################
# Spinner function
###############################################################################
spinner() {
    local pid="$1"
    local msg="$2"
    local spin='-\|/'
    local i=0

    # Print initial message (no newline, so we can animate in place).
    # Sending to stderr ensures it isn't redirected by > /dev/null.
    echo -n "$msg..." >&2

    # Keep spinning while "$pid" is alive.
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) %4 ))
        # Move back 1 char, print spinner, flush.
        echo -en "\b${spin:$i:1}" >&2
        sleep 0.15
    done

    # Wait for the process to finish and capture exit code.
    wait "$pid" || true
    local ec=$?

    # Remove the spinner character.
    echo -en "\b" >&2

    if [ "$ec" -ne 0 ]; then
        echo " [FAILED]" >&2
        echo >&2
        echo "A step has failed. Exiting." >&2
        exit 1
    else
        echo " [OK]" >&2
    fi
}

###############################################################################
# Step 1: Check or install local SDKMAN
###############################################################################
echo "Checking local SDKMAN environment..."
if [ ! -d "$WORK_DIR/.sdkman" ]; then
    echo "Initializing SDKMAN..."
    export SDKMAN_DIR="$WORK_DIR/.sdkman"

    {
        curl -s "https://get.sdkman.io" | bash
    } >/dev/null 2>&1

    # Temporarily disable -u while sourcing SDKMAN (avoids 'unbound variable').
    set +u
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
    set -u

    echo "Installing Java 17 via local SDKMAN..."
    (
        set +u
        sdk install java 17.0.9-graalce >/dev/null 2>&1
        set -u
    ) &
    spinner $! "Installing Java"
else
    echo "Local SDKMAN found. Using it."
    export SDKMAN_DIR="$WORK_DIR/.sdkman"

    set +u
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
    set -u
fi

echo "Selecting Java version..."
(
  set +u
  sdk use java 17.0.9-graalce >/dev/null 2>&1 || true
  set -u
) &
spinner $! "Switching Java version"

# Show which Java is in use (grab one line).
JAVA_VERSION=$(java -version 2>&1 | head -n1 | cut -d '"' -f2 || true)
echo "Java in use: $JAVA_VERSION"

###############################################################################
# Step 2: Check Purpur repo
###############################################################################
echo "Bootstrapping Purpur..."
if [ ! -d "../Purpur" ]; then
    echo "Error: '../Purpur' directory not found. Please clone Purpur in a sibling directory named 'Purpur'."
    exit 1
fi

cd ../Purpur

echo "Checking Purpur repository for updates..."
git fetch origin "$PURPUR_BRANCH" >/dev/null 2>&1
LOCAL_HASH="$(git rev-parse HEAD)"
REMOTE_HASH="$(git rev-parse origin/"$PURPUR_BRANCH")"

###############################################################################
# Step 3: Rebuild if needed
###############################################################################
BUILD_PERFORMED=0

if [ "$LOCAL_HASH" != "$REMOTE_HASH" ] || [ ! -f "$FINAL_JAR_PATH" ]; then
    if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
        echo "Detected new commits on branch '$PURPUR_BRANCH'. Resetting local repo..."
        git reset --hard "origin/$PURPUR_BRANCH" >/dev/null 2>&1
    else
        echo "Purpur JAR missing. Rebuilding from current HEAD ($LOCAL_HASH)."
    fi

    (
      ./gradlew applyPatches >/dev/null 2>&1
    ) &
    spinner $! "Applying patches"

    (
      ./gradlew build >/dev/null 2>&1
    ) &
    spinner $! "Building Purpur"

    (
      ./gradlew createMojmapBundlerJar >/dev/null 2>&1
    ) &
    spinner $! "Creating Mojmap Bundler Jar"

    (
      ./gradlew publishToMavenLocal >/dev/null 2>&1
    ) &
    spinner $! "Publishing to Maven Local"

    echo "Copying final JAR to '$FINAL_JAR_PATH'..."
    (
      cp build/libs/purpur-bundler-*-mojmap.jar "$FINAL_JAR_PATH" 2>/dev/null
    ) &
    spinner $! "Copying JAR"

    BUILD_PERFORMED=1
else
    echo "No changes detected and 'purpur-1.19.4.jar' already exists. Skipping build."
fi

###############################################################################
# Step 4: Copy startup script to same directory as the Purpur jar
###############################################################################
echo "Copying 'start.sh' into the Purpur jar's folder..."
(
  cat << 'EOF' > "$WORK_DIR/../start.sh"
#!/usr/bin/env bash
# This is free and unencumbered software released into the public domain.
# Author: NotAlexNoyle (admin@true-og.net)

# Stage 5: Assemble server.

# Source the self-contained SDKMAN installation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/bootstrap/.sdkman/bin/sdkman-init.sh"

# Use the desired Java version from the self-contained SDKMAN
sdk use java 17.0.9-graalce

# Auto-restart loop
while [ true ]; do
    echo "Starting TrueOG..."
    java -Xms43008M -Xmx43008M \
         -Dterminal.jline=false \
         -XX:+UseG1GC \
         -Dpaper.playerconnection.keepalive=60 \
         -XX:+UnlockDiagnosticVMOptions \
         -XX:+DebugNonSafepoints \
         -XX:+ParallelRefProcEnabled \
         -XX:MaxGCPauseMillis=200 \
         -XX:+UnlockExperimentalVMOptions \
         -XX:+DisableExplicitGC \
         -XX:+AlwaysPreTouch \
         -XX:G1HeapWastePercent=5 \
         -XX:G1MixedGCCountTarget=4 \
         -XX:G1MixedGCLiveThresholdPercent=90 \
         -XX:G1RSetUpdatingPauseTimePercent=5 \
         -XX:SurvivorRatio=32 \
         -XX:+PerfDisableSharedMem \
         -XX:MaxTenuringThreshold=1 \
         -XX:G1NewSizePercent=30 \
         -XX:G1MaxNewSizePercent=40 \
         -XX:G1HeapRegionSize=8M \
         -XX:G1ReservePercent=20 \
         -XX:InitiatingHeapOccupancyPercent=15 \
         -Dusing.aikars.flags=https://mcflags.emc.gs \
         -Daikars.new.flags=true \
         --add-modules=jdk.incubator.vector \
         -jar purpur-1.19.4.jar nogui

    for i in 5 4 3 2 1; do
        printf 'Server restarting in %s... (press CTRL-C to exit)\n' "${i}"
        sleep 1
    done
done
EOF

  chmod +x "$WORK_DIR/../start.sh"
) &
spinner $! "Writing startup script"

cd "$WORK_DIR" || exit 1

###############################################################################
# Step 5: Build report
###############################################################################
echo
if [ "$BUILD_PERFORMED" -eq 1 ]; then
    echo "Build Report:"
    echo " - Repository branch:       $PURPUR_BRANCH"
    echo " - Local commit:            $LOCAL_HASH"
    echo " - JAR created at:          $FINAL_JAR_PATH"
    echo " - Startup script:          $WORK_DIR/../start.sh"
    echo " - Java version used:       $JAVA_VERSION"
    echo
    echo "Purpur build completed successfully."
else
    echo "Build Report:"
    echo " - No rebuild needed."
    echo " - Existing JAR remains at: $FINAL_JAR_PATH"
    echo " - Startup script:          $WORK_DIR/../start.sh"
fi

echo "Done."

