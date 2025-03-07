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
