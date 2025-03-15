#!/usr/bin/env bash
# This is free and unencumbered software released into the public domain.
# Author: NotAlexNoyle (admin@true-og.net)

# TrueOG Bootstrap Stage 3: Bootstrap Java and Spigot BuildTools.

# Variables
WORK_DIR="$(pwd)"
BUILD_TOOLS_JAR="$WORK_DIR/BuildTools.jar"
SELF_MAVEN_LOCAL_REPO="$WORK_DIR/.m2/repository"
GRADLE_USER_HOME="$WORK_DIR/.gradle"
export GRADLE_USER_HOME
ORIGINAL_PATH="$PATH"

# Set MAVEN_OPTS to ensure BuildTools uses the custom Maven local repository
export MAVEN_OPTS="-Dmaven.repo.local=$SELF_MAVEN_LOCAL_REPO"

# Function to handle script interruption
cleanup() {
    echo
    echo "ERROR: Script interrupted! There may be build artifacts left over. Please clean the directory before running the script again."
    # Show cursor (raw ANSI escape code instead of tput cnorm)
    echo -en "\033[?25h"
    exit 1
}

# Trap SIGINT (Ctrl+C)
trap cleanup SIGINT

# Function to display a spinner while a background process is running
spinner() {
    local pid=$1
    local message="$2"
    local spin='-\|/'
    local i=0
    # Hide cursor (raw ANSI escape code instead of tput civis)
    echo -en "\033[?25l"
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r[%c] %s" "${spin:$i:1}" "$message"
        sleep .1
    done
    # Show cursor (raw ANSI escape code instead of tput cnorm)
    echo -en "\033[?25h"
    printf "\r[✓] %s\n" "$message"
}

# Download BuildTools.jar if not present
if [ ! -f "$BUILD_TOOLS_JAR" ]; then
    echo "Downloading BuildTools.jar..."
    wget -q -O "$BUILD_TOOLS_JAR" "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"
fi

# Function to check if the required Java version exists in PATH
check_java_version() {
    local required_version="$1"
    if command -v java > /dev/null 2>&1; then
        local java_version_output
        java_version_output=$(java -version 2>&1)
        local java_version
        java_version=$(echo "$java_version_output" | awk -F[\"_] '/version/ {print $2}')
        local major_version
        major_version=$(echo "$java_version" | awk -F. '{print $1}')
        if [ "$major_version" -eq "$required_version" ] || \
           { [ "$major_version" -eq "1" ] && [ "$(echo "$java_version" | awk -F. '{print $2}')" -eq "$required_version" ]; }
        then
            return 0  # Required Java version is in PATH
        else
            return 1  # Different Java version in PATH
        fi
    else
        return 1  # Java not found in PATH
    fi
}

# Function to download and set up Java
download_java() {
    local java_version="$1"
    local java_dir="$WORK_DIR/java$java_version"

    if check_java_version "$java_version"; then
        echo "Java $java_version is already available in PATH. Skipping download."
    else
        if [ ! -d "$java_dir" ]; then
            mkdir -p "$java_dir"
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
                    exit 1
                    ;;
            esac

            echo "Downloading OpenJDK $java_version..."
            wget -q -O "$java_dir/java.tar.gz" "$java_url"
            echo "Extracting OpenJDK $java_version..."
            tar -xzf "$java_dir/java.tar.gz" -C "$java_dir" --strip-components=1
            rm "$java_dir/java.tar.gz"
        fi
    fi
}

# Set Java version
use_java_version() {
    local java_version="$1"
    if check_java_version "$java_version"; then
        echo "Using system Java $java_version from PATH"
        unset JAVA_HOME
        export PATH="$ORIGINAL_PATH"
    else
        export JAVA_HOME="$WORK_DIR/java$java_version"
        export PATH="$JAVA_HOME/bin:$ORIGINAL_PATH"
        echo "Using Java $java_version from $JAVA_HOME"
    fi
}

# Function to compare versions
version_ge() {
    # Returns 0 if $1 >= $2
    [ "$1" = "$2" ] && return 0
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]
}

version_lt() {
    # Returns 0 if $1 < $2
    [ "$1" = "$2" ] && return 1
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# Function to check if standard artifact exists only in SELF_MAVEN_LOCAL_REPO
artifact_exists_standard() {
    local version="$1"
    local maven_version="${version}-R0.1-SNAPSHOT"
    local artifact_rel_path="org/spigotmc/spigot-api/$maven_version/spigot-api-$maven_version.jar"

    local artifact_path_self="$SELF_MAVEN_LOCAL_REPO/$artifact_rel_path"

    if [ -f "$artifact_path_self" ]; then
        return 0  # Artifact exists in SELF repository
    else
        return 1  # Artifact does not exist in SELF repository
    fi
}

# Function to check if remapped artifacts exist only in SELF_MAVEN_LOCAL_REPO
artifact_exists_remapped() {
    local version="$1"

    # Only applicable for versions 1.17 and above
    if version_ge "$version" "1.17"; then
        local maven_version="${version}-R0.1-SNAPSHOT"
        local artifact_rel_path="org/spigotmc/spigot/$maven_version"

        local artifact_path_mojang_self="$SELF_MAVEN_LOCAL_REPO/$artifact_rel_path/spigot-$maven_version-remapped-mojang.jar"
        local artifact_path_obf_self="$SELF_MAVEN_LOCAL_REPO/$artifact_rel_path/spigot-$maven_version-remapped-obf.jar"

        if [ -f "$artifact_path_mojang_self" ] && [ -f "$artifact_path_obf_self" ]; then
            return 0  # Both remapped artifacts exist in SELF repository
        else
            return 1  # Artifacts do not exist in SELF repository
        fi
    else
        return 1  # Not applicable
    fi
}

# Initialize build_count and total_builds
build_count=0
total_builds=0

# Arrays of Minecraft versions for each Java version
java8_versions=(
    1.8 1.8.3 1.8.8 1.9 1.9.2 1.9.4 1.10.2 1.11 1.11.2
    1.12 1.12.1 1.12.2 1.13 1.13.1 1.13.2 1.14 1.14.1 1.14.2
    1.14.3 1.14.4 1.15 1.15.2 1.16.1 1.16.2 1.16.3 1.16.4 1.16.5
)
java16_versions=(1.17 1.17.1)
java17_versions=(
    1.18 1.18.1 1.18.2 1.19 1.19.1 1.19.2
    1.19.3 1.19.4 1.20.1 1.20.2 1.20.4
)
java21_versions=(1.20.6)

# Function to calculate total builds
calculate_total_builds() {
    local versions=("$@")
    for version in "${versions[@]}"; do
        if version_lt "$version" "1.17"; then
            total_builds=$((total_builds + 1))  # Standard build
        else
            total_builds=$((total_builds + 1))  # Remapped build
        fi
    done
}

# Calculate total builds
calculate_total_builds "${java8_versions[@]}"
calculate_total_builds "${java16_versions[@]}"
calculate_total_builds "${java17_versions[@]}"
calculate_total_builds "${java21_versions[@]}"

# Function to build versions
build_versions() {
    local java_version="$1"
    shift
    local versions=("$@")

    use_java_version "$java_version"

    for version in "${versions[@]}"; do
        if version_lt "$version" "1.17"; then
            # Build standard version only
            ((build_count++))
            if artifact_exists_standard "$version"; then
                message="[$build_count/$total_builds] Skipping Minecraft $version (standard), already built."
                echo "[✓] $message"
            else
                message="[$build_count/$total_builds] Building Minecraft $version (standard) with Java $java_version..."
                (
                    mkdir -p "$version"
                    pushd "$version" > /dev/null
                    java -jar "$BUILD_TOOLS_JAR" --rev "$version" > build_standard.log 2>&1
                    popd > /dev/null
                ) &
                BUILD_PID=$!
                spinner $BUILD_PID "$message"
            fi
        else
            # Build remapped version only
            ((build_count++))
            if artifact_exists_remapped "$version"; then
                message="[$build_count/$total_builds] Skipping Minecraft $version (remapped), already built."
                echo "[✓] $message"
            else
                message="[$build_count/$total_builds] Building Minecraft $version (remapped) with Java $java_version..."
                (
                    mkdir -p "$version/remapped"
                    pushd "$version/remapped" > /dev/null
                    java -jar "$BUILD_TOOLS_JAR" --rev "$version" --remapped > build_remapped.log 2>&1
                    popd > /dev/null
                ) &
                BUILD_PID=$!
                spinner $BUILD_PID "$message"
            fi
        fi
    done
}

# Download required Java versions
download_java 8
download_java 16
download_java 17
download_java 21

# Build Java 8 versions
build_versions 8 "${java8_versions[@]}"

# Build Java 16 versions
build_versions 16 "${java16_versions[@]}"

# Build Java 17 versions
build_versions 17 "${java17_versions[@]}"

# Build Java 21 versions
build_versions 21 "${java21_versions[@]}"

# Clean up Java directories if they were downloaded
[ -d "$WORK_DIR/java8" ] && rm -rf "$WORK_DIR/java8"
[ -d "$WORK_DIR/java16" ] && rm -rf "$WORK_DIR/java16"
[ -d "$WORK_DIR/java17" ] && rm -rf "$WORK_DIR/java17"
[ -d "$WORK_DIR/java21" ] && rm -rf "$WORK_DIR/java21"

# Restore original PATH
export PATH="$ORIGINAL_PATH"

# Unset environment variables
unset JAVA_HOME

# Clean up BuildTools.jar and build directories
rm -f "$BUILD_TOOLS_JAR"
rm -rf "$WORK_DIR/"[1-9]*

echo "Bootstrapping of Spigot BuildTools complete."

