# This is free and unencumbered software released into the public domain.
# Author: NotAlexNoyle (admin@true-og.net)

#!/bin/bash

# Update git submodules with a real-time progress display
echo "Initializing and updating submodules..."
failed_submodules=()
git submodule update --force --recursive --init --remote 2>&1 | while read -r line; do
    # Extract submodule path without "plugins/" prefix
    if [[ "$line" =~ ^Submodule\ path\ \'plugins\/([^\']+)\' ]]; then
        submodule="${BASH_REMATCH[1]}"
        echo -ne "\rUpdating submodule: $submodule                  "
    fi

    # Detect failed submodule update
    if [[ "$line" =~ fatal|error ]]; then
        failed_submodules+=("$submodule")
    fi
done

# Check if any submodules failed to update
if [[ ${#failed_submodules[@]} -gt 0 ]]; then
    echo -e "\rSubmodule update completed with errors.            "
    echo "The following submodules failed to update:"
    for submodule in "${failed_submodules[@]}"; do
        echo "- $submodule"
    done
    exit 1
else
    echo -e "\rSubmodules updated successfully.                   "
fi

# Array to store results
declare -A build_results
halted=false

# Trap Ctrl+C (SIGINT) to stop the script gracefully
trap 'echo -e "\n\nBuild process interrupted."; halted=true' SIGINT

# Define paths
BASE_DIR="$(dirname "$0")/plugins"  # Point to plugins directory inside true-og
OUTPUT_DIR="$(dirname "$0")/server"  # Output JAR files to server folder inside true-og
TEMP_PLUGINS_DIR="$(dirname "$0")/temp_plugins"

# Create directories for the output and temporary storage of up-to-date JARs
mkdir -p "$OUTPUT_DIR" "$TEMP_PLUGINS_DIR"

# Function to calculate the SHA-256 hash of a file
hash_file() {
    local file_path="$1"
    sha256sum "$file_path" | awk '{print $1}'
}

# Move up-to-date JARs to temp_plugins to retain them
for plugin_jar in "$OUTPUT_DIR"/*.jar; do
    if [[ -f "$plugin_jar" ]]; then
        plugin_name=$(basename "$plugin_jar")
        plugin_found=false

        for project_dir in "$BASE_DIR"/*/*/; do
            jar_path=""
            if [[ -f "$project_dir/build.gradle" || -f "$project_dir/settings.gradle" || -f "$project_dir/build.gradle.kts" || -f "$project_dir/settings.gradle.kts" ]]; then
                jar_path="$project_dir/build/libs/$plugin_name"
            elif [[ -f "$project_dir/pom.xml" ]]; then
                jar_path="$project_dir/target/$plugin_name"
            fi

            if [[ -f "$jar_path" && "$(hash_file "$plugin_jar")" == "$(hash_file "$jar_path")" ]]; then
                mv "$plugin_jar" "$TEMP_PLUGINS_DIR/"
                plugin_found=true
                break
            fi
        done
        [[ $plugin_found == false ]] && rm -f "$plugin_jar"
    fi
done

# Clear output folder and move retained JARs back to output
rm -f "$OUTPUT_DIR"/*
mv "$TEMP_PLUGINS_DIR"/* "$OUTPUT_DIR/" 2>/dev/null || true # Suppress error if temp_plugins is empty
rmdir "$TEMP_PLUGINS_DIR"

# Count total plugin subdirectories to set up the progress bar
total_dirs=$(find "$BASE_DIR" -mindepth 2 -maxdepth 2 -type d ! -name '.*' | wc -l)
completed=0

# List of prefixes for build order (matching exact folder names)
build_order=("OG-Suite" "Hard-Forks" "Soft-Forks" "Third-Party")

# Function to sort by prefix order
sort_by_prefix_order() {
    local arr=("$@")
    printf "%s\n" "${arr[@]}" | sort -t/ -k1,1 --stable -s -f | sort -t/ -k2,2 --stable -s -f
}

# Function to display progress bar with current project name, formatted to a fixed width
progress_bar() {
    local subfolder="$1"
    local project_name="$2"
    local progress=$(( (completed * 100) / total_dirs ))
    progress=$(( progress > 100 ? 100 : progress )) # Ensure progress does not exceed 100%
    local bar_length=20 # Fixed bar length
    local filled_length=$(( (progress * bar_length) / 100 ))
    local bar=""

    # Fill the bar with '#' and spaces to ensure consistent length
    for ((i = 0; i < filled_length; i++)); do
        bar+="#"
    done
    for ((i = filled_length; i < bar_length; i++)); do
        bar+=" "
    done

    # Display parent folder and project name, ensuring consistent formatting
    local formatted_subfolder=$(printf "%-10.10s" "$subfolder")
    local formatted_project_name=$(printf "%-20.20s" "$(basename "$project_name")")

    printf "\rBuilding %s: %s [%-20s] %3d%%" "$formatted_subfolder" "$formatted_project_name" "$bar" "$progress"
}

# Build each main directory in the specified order
for prefix in "${build_order[@]}"; do
    for main_dir in "$BASE_DIR/$prefix"*/; do
        [[ ! -d "$main_dir" || "$main_dir" == "$OUTPUT_DIR/" ]] && continue

        for dir in "$main_dir"*/; do
            if $halted; then
                break 2
            fi

            subfolder="${prefix}"  # Use prefix as parent folder name
            project_name="${dir%/}"

            if [[ "${build_results["$subfolder/$project_name"]}" == "Pass (cached)" ]]; then
                continue
            fi

            # Check and build if project is Gradle or Maven
            if [[ -f "$dir/build.gradle" || -f "$dir/settings.gradle" || -f "$dir/build.gradle.kts" || -f "$dir/settings.gradle.kts" ]]; then
                progress_bar "$subfolder" "$project_name"
                (cd "$dir" && ./gradlew build -q > /dev/null 2>&1)  # Suppress all Gradle output
                if [[ $? -eq 0 ]]; then
                    build_results["$subfolder/$project_name"]="Pass"
                    if [[ -d "$dir/build/libs" ]]; then
                        find "$dir/build/libs" -name "*.jar" ! -name "*javadoc*" ! -name "*sources*" ! -name "*part*" ! -name "original*" -exec cp {} "$OUTPUT_DIR/" \; 2>/dev/null
                    fi
                else
                    build_results["$subfolder/$project_name"]="Fail"
                fi
            elif [[ -f "$dir/pom.xml" ]]; then
                progress_bar "$subfolder" "$project_name"
                (cd "$dir" && mvn package -q > /dev/null 2>&1)  # Suppress all Maven output
                if [[ $? -eq 0 ]]; then
                    build_results["$subfolder/$project_name"]="Pass"
                    if [[ -d "$dir/target" ]]; then
                        find "$dir/target" -name "*.jar" ! -name "*javadoc*" ! -name "*sources*" ! -name "*part*" ! -name "original*" -exec cp {} "$OUTPUT_DIR/" \; 2>/dev/null
                    fi
                else
                    build_results["$subfolder/$project_name"]="Fail"
                fi
            else
                build_results["$subfolder/$project_name"]="Fail"
            fi

            completed=$((completed + 1))
            progress_bar "$subfolder" "$project_name"
        done
    done
done

# Separate lists for passed and failed builds
pass_list=()
fail_list=()

for project in "${!build_results[@]}"; do
    if [[ "${build_results[$project]}" =~ "Pass" ]]; then
        pass_list+=("$project")
    elif [[ "${build_results[$project]}" == "Fail" ]]; then
        fail_list+=("$project")
    fi
done

# Sort and display results
echo -e "\n\nPlugins built successfully:"
sorted_pass_list=($(sort_by_prefix_order "${pass_list[@]}"))
for project in "${sorted_pass_list[@]}"; do
    echo "$project"
done

if [[ ${#fail_list[@]} -gt 0 ]]; then
    echo -e "\nFailed builds:"
    sorted_fail_list=($(sort_by_prefix_order "${fail_list[@]}"))
    for project in "${sorted_fail_list[@]}"; do
        echo "$project"
    done
fi

if $halted; then
    echo -e "\nBuild process was halted by the user."
fi
