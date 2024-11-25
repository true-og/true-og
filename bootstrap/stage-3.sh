#!/usr/bin/env bash

# Stage 3: Bootstrap Spigot BuildTools, purpurclip, and java.

# Variables
WORK_DIR="$(pwd)"
BUILD_TOOLS_JAR="$WORK_DIR/BuildTools.jar"

# Function to handle script interruption
cleanup() {
    echo
    echo "Script interrupted. Cleaning up..."
    # Kill any background processes
    if [ -n "$BUILD_PID" ]; then
        kill $BUILD_PID 2>/dev/null || true
    fi
    # Restore cursor
    tput cnorm
    exit 1
}

# Trap SIGINT (Ctrl+C)
trap cleanup SIGINT

# Function to display a spinner while a background process is running
spinner() {
    local pid=$1
    local spin='-\|/'
    local i=0
    tput civis  # Hide cursor
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r[%c] Building..." "${spin:$i:1}"
        sleep .1
    done
    tput cnorm  # Show cursor
    printf "\r"  # Clear the spinner
}

# Download BuildTools.jar if not present
if [ ! -f "$BUILD_TOOLS_JAR" ]; then
    echo "Downloading BuildTools.jar..."
    echo
    wget -q -O "$BUILD_TOOLS_JAR" "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"
fi

# Function to download and set up a specific Java version
download_java() {
    local java_version="$1"
    local java_dir="$WORK_DIR/java$java_version"

    if [ ! -d "$java_dir" ]; then
        mkdir -p "$java_dir"

        # Determine the correct download URL based on Java version
        case "$java_version" in
            8)
                java_url="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u382-b05/OpenJDK8U-jdk_x64_linux_hotspot_8u382b05.tar.gz"
                ;;
            16)
                java_url="https://github.com/adoptium/temurin16-binaries/releases/download/jdk-16.0.2+7/OpenJDK16U-jdk_x64_linux_hotspot_16.0.2_7.tar.gz"
                ;;
            17)
                java_url="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.8.1+1/OpenJDK17U-jdk_x64_linux_hotspot_17.0.8.1_1.tar.gz"
                ;;
            21)
                java_url="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21+35/OpenJDK21U-jdk_x64_linux_hotspot_21_35.tar.gz"
                ;;
            *)
                echo "Unsupported Java version: $java_version"
                echo
                exit 1
                ;;
        esac

        echo "Downloading OpenJDK $java_version..."
        echo
        wget -q -O "$java_dir/java.tar.gz" "$java_url"
        if [ $? -ne 0 ]; then
            echo "Failed to download Java $java_version from $java_url"
            echo
            exit 1
        fi

        echo "Extracting OpenJDK $java_version..."
        echo
        tar -xzf "$java_dir/java.tar.gz" -C "$java_dir" --strip-components=1
        if [ $? -ne 0 ]; then
            echo "Failed to extract Java $java_version archive."
            echo
            exit 1
        fi

        # Ensure Java binaries are executable
        chmod +x "$java_dir/bin/"*

        rm "$java_dir/java.tar.gz"

        # Test Java executable and suppress version output
        "$java_dir/bin/java" -version > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Java $java_version is not working properly."
            echo
            exit 1
        fi
    fi
}

# Function to download and set up Maven locally
download_maven() {
    local maven_version="3.9.4"
    local maven_dir="$WORK_DIR/maven"

    if [ ! -d "$maven_dir" ]; then
        mkdir -p "$maven_dir"

        echo "Downloading Maven..."
        echo

        maven_url="https://archive.apache.org/dist/maven/maven-3/$maven_version/binaries/apache-maven-$maven_version-bin.tar.gz"

        wget -q -O "$maven_dir/maven.tar.gz" "$maven_url"
        if [ $? -ne 0 ]; then
            echo "Failed to download Maven from $maven_url"
            echo
            exit 1
        fi

        echo "Extracting Maven..."
        echo
        tar -xzf "$maven_dir/maven.tar.gz" -C "$maven_dir" --strip-components=1
        if [ $? -ne 0 ]; then
            echo "Failed to extract Maven archive."
            echo
            exit 1
        fi

        # Ensure Maven binaries are executable
        chmod +x "$maven_dir/bin/"*

        rm "$maven_dir/maven.tar.gz"
    fi

    # Update PATH to include local Maven bin directory
    export PATH="$maven_dir/bin:$PATH"
}

# Function to set Java environment variables
use_java_version() {
    local java_version="$1"
    export JAVA_HOME="$WORK_DIR/java$java_version"
    export PATH="$JAVA_HOME/bin:$ORIGINAL_PATH"

    echo "Using Java $java_version from $JAVA_HOME"
    echo
}

# Save the original PATH to restore later
ORIGINAL_PATH="$PATH"

# Download required Java versions
download_java 8
download_java 16
download_java 17
download_java 21

# Download Maven locally
download_maven

# Total number of builds
total_builds=0
build_count=0

# Arrays of Minecraft versions for each Java version
java8_versions=(
    1.8.3 1.8.8 1.9 1.9.2 1.9.4 1.10.2 1.11 1.11.1 1.11.2
    1.12 1.12.1 1.12.2 1.13 1.13.1 1.13.2 1.14 1.14.1 1.14.2
    1.14.3 1.14.4 1.15 1.15.2 1.16.1 1.16.2 1.16.3 1.16.4 1.16.5
)
java16_versions=(1.17 1.17.1)
java17_versions=(
    1.18 1.18.1 1.18.2 1.19 1.19.1 1.19.2
    1.19.3 1.19.4 1.20.1 1.20.2 1.20.4
)
java21_versions=(1.20.6 1.21 1.21.1)

# Calculate total builds
total_builds=$((${#java8_versions[@]} + ${#java16_versions[@]} * 2 + ${#java17_versions[@]} + ${#java21_versions[@]}))

# Function to build versions
build_versions() {
    local java_version="$1"
    shift
    local versions=("$@")

    use_java_version "$java_version"

    for version in "${versions[@]}"; do
        ((build_count++))
        echo "[$build_count/$total_builds] Building Minecraft version $version with Java $java_version..."
        echo

        mkdir -p "$version"
        cd "$version"

        if [[ "$java_version" -eq 16 && ( "$version" == "1.17" || "$version" == "1.17.1" ) ]]; then
            # For Java 16 versions, build standard and remapped
            echo "    Building standard version..."
            echo
            java -jar "$BUILD_TOOLS_JAR" --rev "$version" > build.log 2>&1 &
            BUILD_PID=$!
            spinner $BUILD_PID
            wait $BUILD_PID

            ((build_count++))
            echo "[$build_count/$total_builds] Building Minecraft version $version (remapped) with Java $java_version..."
            echo
            mkdir -p remapped
            cd remapped
            java -jar "$BUILD_TOOLS_JAR" --rev "$version" --remapped > build.log 2>&1 &
            BUILD_PID=$!
            spinner $BUILD_PID
            wait $BUILD_PID
            cd ../..
        else
            java -jar "$BUILD_TOOLS_JAR" --rev "$version" --remapped > build.log 2>&1 &
            BUILD_PID=$!
            spinner $BUILD_PID
            wait $BUILD_PID
            cd ..
        fi
    done
}

echo "Starting builds..."
echo

# Build Java 8 versions
build_versions 8 "${java8_versions[@]}"

# Build Java 16 versions
build_versions 16 "${java16_versions[@]}"

# Build Java 17 versions
build_versions 17 "${java17_versions[@]}"

# Build Java 21 versions
build_versions 21 "${java21_versions[@]}"

echo "All builds completed."
echo

# Clean up Java and Maven directories
rm -rf "$WORK_DIR/java8" "$WORK_DIR/java16" "$WORK_DIR/java17" "$WORK_DIR/java21"
rm -rf "$WORK_DIR/maven"

# Restore original PATH
export PATH="$ORIGINAL_PATH"

# Unset environment variables
unset JAVA_HOME

# Clean up BuildTools.jar and build directories
rm -f "$BUILD_TOOLS_JAR"
rm -rf "$WORK_DIR/"[1-9]*

echo "Clean up completed. Only the script remains in the folder."
echo

