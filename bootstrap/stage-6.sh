# This is free and unencumbered software released into the public domain.
# Author: NotAlexNoyle (admin@true-og.net)
#!/bin/bash

# Stage 5: Assemble server.

# Set java version
sdk use graalvm64-17.0.9 

# Auto-restart loop
while [ true ]; do
    echo "Starting TrueOG..."
	java -Xms43008M -Xmx43008M -Dterminal.jline=false -XX:+UseG1GC -Dpaper.playerconnection.keepalive=60 -XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -jar --add-modules=jdk.incubator.vector purpur-1.19.4-R0.1-SNAPSHOT.jar nogui
	for i in 5 4 3 2 1; do
        printf 'Server restarting in %s... (press CTRL-C to exit)\n' "${i}"
        sleep 1
    done
done
