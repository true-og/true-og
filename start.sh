#!/usr/bin/env bash
# This is free and unencumbered software released into the public domain.
# Author: NotAlexNoyle (admin@true-og.net)

# Stage 5: Assemble server.

#!/usr/bin/env bash

# Source the current directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the self-contained SDKMAN installation.
source "$SCRIPT_DIR/bootstrap/.sdkman/bin/sdkman-init.sh"

# Use the desired Java version from the self-contained SDKMAN.
sdk use java 17.0.9-graalce

# Determine the SubstAgent commit hash and jar path dynamically.
SUBSTAGENT_DIR="$SCRIPT_DIR/SubstAgent"
SUBSTAGENT_HASH="$(git -C "$SUBSTAGENT_DIR" rev-parse --short=10 HEAD)"

AGENT_JAR="$SUBSTAGENT_DIR/build/libs/SubstAgent-${SUBSTAGENT_HASH}.jar"

# Exit if SubstAgent was not found.
if [[ ! -f "$AGENT_JAR" ]]; then
  echo "SubstAgent jar not found: $AGENT_JAR" >&2
  echo "Did you run the build for SubstAgent at commit $SUBSTAGENT_HASH?" >&2
  exit 1
fi

# Auto-restarting optimized minecraft java server loop.
while true; do
    echo "Starting TrueOG..."
    java -Xms64G -Xmx64G \
         -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
         -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \
         -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M \
         -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \
         -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 \
         -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:MaxTenuringThreshold=1 \
         -XX:+PerfDisableSharedMem --add-modules=jdk.incubator.vector \
         -Dterminal.jline=false -Dpaper.playerconnection.keepalive=60 \
         -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true \
         -javaagent:"$AGENT_JAR" -Xbootclasspath/a:"$AGENT_JAR" -jar purpur-1.19.4.jar nogui

    for i in 5 4 3 2 1; do
        printf 'Server restarting in %s... (press CTRL-C to exit)\n' "${i}"
        sleep 1
    done
done
