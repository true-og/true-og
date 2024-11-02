#!/usr/bin/env bash
# This is free and unencumbered software released into the public domain.
# Builds all TrueOG Plugins and puts them into a folder called server/ in the current directory.

# Display ASCII art and wait for user input to start
cat << "EOF"

♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥
♥   ___  __        ___  __   __           ___ ___       __   __         ♥
♥    |  |__) |  | |__  /  \ / _`    |\ | |__   |  |  | /  \ |__) |__/   ♥
♥    |  |  \ \__/ |___ \__/ \__>    | \| |___  |  |/\| \__/ |  \ |  \   ♥
♥                                                                       ♥
♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥   ♥

	  		  Plugin Bootstrap
 			"ad astra per aspera"

			Author: NotAlexNoyle

EOF

read -p "Press Enter to start..."

# Collect initial commit hashes of submodules from previous run
declare -A plugin_commit_hash_before
declare -A plugin_commit_hash_after
declare -A new_commit_hashes
declare -A build_results
halted=false

# Move the commit_hashes.txt file to plugins/logs/
BASE_DIR="$(dirname "$0")/plugins"  # Point to plugins directory
LOG_DIR="$BASE_DIR/logs"  # Directory to store logs
COMMIT_HASH_FILE="$LOG_DIR/commit_hashes.txt"

# Function to handle script interruption
cleanup() {
    echo -e "\n\nBuild process interrupted."
    # Kill all child processes of the script
    kill 0
    exit 1
}

# Trap SIGINT (Ctrl+C) and call cleanup
trap 'cleanup' SIGINT

# Start a new process group
set -m

OUTPUT_DIR="$(dirname "$0")/server"  # Output JAR files to server folder

mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

build_order=("OG-Suite" "Hard-Forks" "Soft-Forks" "Third-Party")

# Function to get commit hash of a plugin directory
get_plugin_commit_hash() {
    local dir="$1"
    if [[ -e "$dir/.git" ]]; then
        (cd "$dir" && git rev-parse HEAD 2>/dev/null)
    else
        echo ""
    fi
}

# Load previous commit hashes from file if it exists
if [[ -f "$COMMIT_HASH_FILE" ]]; then
    while IFS=: read -r plugin_key commit_hash; do
        plugin_commit_hash_before["$plugin_key"]="$commit_hash"
    done < "$COMMIT_HASH_FILE"
fi

echo

# Updating submodules with progress bar
submodule_paths=($(git config --file .gitmodules --get-regexp path | awk '{ print $2 }'))
total_submodules=${#submodule_paths[@]}
declare -A failed_submodules=()

submodule_progress_bar() {
    local current=$1
    local total=$2
    local submodule_name=$3
    local progress=$(( (current * 100) / total ))
    progress=$(( progress > 100 ? 100 : progress ))
    local bar_length=20
    local filled_length=$(( (progress * bar_length) / 100 ))
    local bar=""
    for ((i = 0; i < filled_length; i++)); do
        bar+="#"
    done
    for ((i = filled_length; i < bar_length; i++)); do
        bar+=" "
    done
    printf "\r\033[KUpdating submodules -> %s [%-20s] %3d%%" "$submodule_name" "$bar" "$progress"
}

submodule_index=0

for submodule_path in "${submodule_paths[@]}"; do
    submodule_index=$((submodule_index + 1))
    submodule_name=$(basename "$submodule_path")
    submodule_progress_bar "$submodule_index" "$total_submodules" "$submodule_name"
    # Update the submodule
    git submodule update --force --recursive --init --remote --quiet "$submodule_path" &> "$LOG_DIR/${submodule_name}_update.log"
    if [[ $? -ne 0 ]]; then
        failed_submodules["$submodule_path"]=1
    fi
done

# Move to the next line after submodule progress bar
echo

# Retry failed submodules
if [[ ${#failed_submodules[@]} -gt 0 ]]; then
    echo
    echo "Retrying failed submodules..."
    for submodule_path in "${!failed_submodules[@]}"; do
        submodule_name=$(basename "$submodule_path")
        echo "Retrying $submodule_name..."
        git submodule update --force --recursive --init --remote --quiet "$submodule_path" &>> "$LOG_DIR/${submodule_name}_update.log"
        if [[ $? -ne 0 ]]; then
            absolute_log_path=$(realpath "$LOG_DIR/${submodule_name}_update.log")
            echo "Failed to update submodule $submodule_name after retry. See log at $absolute_log_path"
            exit 1
        else
            unset failed_submodules["$submodule_path"]
        fi
    done
fi

echo
echo "Submodules updated successfully."

echo

# Collect commit hashes after updating submodules
for prefix in "${build_order[@]}"; do
    for dir in "$BASE_DIR/$prefix"/*/; do
        [[ ! -d "$dir" ]] && continue
        plugin_name="$(basename "$dir")"
        plugin_key="${prefix}/${plugin_name}"
        plugin_commit_hash_after["$plugin_key"]="$(get_plugin_commit_hash "$dir")"
    done
done

# Initialize counters for progress bar
total_dirs=0
for prefix in "${build_order[@]}"; do
    count=$(find "$BASE_DIR/$prefix" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    total_dirs=$((total_dirs + count))
done
completed=0

progress_bar() {
    local subfolder="$1"
    local project_name="$2"
    local progress=$(( (completed * 100) / total_dirs ))
    progress=$(( progress > 100 ? 100 : progress ))
    local bar_length=20
    local filled_length=$(( (progress * bar_length) / 100 ))
    local bar=""
    for ((i = 0; i < filled_length; i++)); do
        bar+="#"
    done
    for ((i = filled_length; i < bar_length; i++)); do
        bar+=" "
    done
    local formatted_subfolder=$(printf "%-12.12s" "$subfolder")
    local formatted_project_name=$(printf "%-20.20s" "$project_name")
    printf "\r\033[KBuilding %s -> %s [%-20s] %3d%%" "$formatted_subfolder" "$formatted_project_name" "$bar" "$progress"
}

select_preferred_jar() {
    local jars=("$@")
    # Prefer jars without "-all" in their name
    local preferred_jars=()
    for jar in "${jars[@]}"; do
        basename=$(basename "$jar")
        if [[ ! "$basename" =~ -all\.jar$ ]]; then
            preferred_jars+=("$jar")
        fi
    done
    if [[ ${#preferred_jars[@]} -eq 0 ]]; then
        # No jars without "-all.jar", use the original list
        preferred_jars=("${jars[@]}")
    fi
    # Select the jar with the shortest name (excluding path)
    preferred_jar="${preferred_jars[0]}"
    shortest_name_length=${#preferred_jar}
    for jar in "${preferred_jars[@]}"; do
        basename=$(basename "$jar")
        if [[ ${#basename} -lt $shortest_name_length ]]; then
            preferred_jar="$jar"
            shortest_name_length=${#basename}
        fi
    done
    echo "$preferred_jar"
}

# Function to sort projects by category and name
sort_projects() {
    local projects=("$@")
    local sorted_projects=()
    for category in "${build_order[@]}"; do
        local category_projects=()
        for project in "${projects[@]}"; do
            if [[ "$project" == "$category/"* ]]; then
                category_projects+=("$project")
            fi
        done
        IFS=$'\n' sorted_category_projects=($(printf "%s\n" "${category_projects[@]}" | sort))
        unset IFS
        sorted_projects+=("${sorted_category_projects[@]}")
    done
    echo "${sorted_projects[@]}"
}

for prefix in "${build_order[@]}"; do
    for dir in "$BASE_DIR/$prefix"/*/; do
        [[ ! -d "$dir" ]] && continue
        if $halted; then
            break 2
        fi

        plugin_name="$(basename "$dir")"
        plugin_key="${prefix}/${plugin_name}"

        # Exclude specific plugins
        if [[ "$plugin_key" == "OG-Suite/Template-OG" || "$plugin_key" == "OG-Suite/KotlinTemplate-OG" ]]; then
            continue
        fi

        progress_bar "$prefix" "$plugin_name"

        # Get current commit hash
        commit_hash="${plugin_commit_hash_after["$plugin_key"]}"
        new_commit_hashes["$plugin_key"]="$commit_hash"

        # Get previous commit hash
        commit_hash_before="${plugin_commit_hash_before["$plugin_key"]}"

        # Determine if the plugin needs to be built
        need_to_build=false
        if [[ -z "$commit_hash_before" || "$commit_hash_before" != "$commit_hash" ]]; then
            # Need to build
            need_to_build=true
        else
            # Plugin directory did not change
            # Check if any jar matching the plugin exists in OUTPUT_DIR
            jar_exists=false
            matching_jars=($(find "$OUTPUT_DIR" -maxdepth 1 -type f -name "*.jar" -iname "*${plugin_name}*.jar"))
            if [[ ${#matching_jars[@]} -gt 0 ]]; then
                jar_exists=true
            fi
            if $jar_exists; then
                # No need to rebuild
                build_results["$plugin_key"]="cached"
                completed=$((completed + 1))
                progress_bar "$prefix" "$plugin_name"
                continue
            else
                # JAR does not exist, need to build
                need_to_build=true
            fi
        fi

        # Determine the build output directories
        build_output_dirs=()
        if [[ -d "$dir/build/libs" ]]; then
            build_output_dirs+=("$dir/build/libs")
        fi
        if [[ -d "$dir/target" ]]; then
            build_output_dirs+=("$dir/target")
        fi
        if [[ -d "$dir/build/distributions" ]]; then
            build_output_dirs+=("$dir/build/distributions")
        fi

        # Move existing JARs to old/ before building
        for build_output_dir in "${build_output_dirs[@]}"; do
            if [[ -d "$build_output_dir" ]]; then
                mkdir -p "$build_output_dir/old"
                find "$build_output_dir" -maxdepth 1 -type f -name "*.jar" ! -path "*/old/*" \
                    -exec mv {} "$build_output_dir/old/" \;
            fi
        done

        if $need_to_build; then
            if [[ -f "$dir/gradlew" ]]; then
                chmod +x "$dir/gradlew" 2>/dev/null
            fi

            if [[ -f "$dir/build.gradle" || -f "$dir/settings.gradle" || -f "$dir/build.gradle.kts" || -f "$dir/settings.gradle.kts" ]]; then
                build_command="./gradlew build"
            elif [[ -f "$dir/pom.xml" ]]; then
                build_command="mvn package"
            else
                build_results["$plugin_key"]="Fail"
                completed=$((completed + 1))
                progress_bar "$prefix" "$plugin_name"
                continue
            fi

            # Run the build command and capture output
            build_log="$LOG_DIR/${plugin_name}_build.log"
            (
                cd "$dir" || exit
                $build_command
            ) > "$build_log" 2>&1  # Run in foreground

            build_exit_code=$?

            if [[ $build_exit_code -eq 0 ]]; then
                # Re-determine the build output directories after build
                build_output_dirs=()
                if [[ -d "$dir/build/libs" ]]; then
                    build_output_dirs+=("$dir/build/libs")
                fi
                if [[ -d "$dir/target" ]]; then
                    build_output_dirs+=("$dir/target")
                fi
                if [[ -d "$dir/build/distributions" ]]; then
                    build_output_dirs+=("$dir/build/distributions")
                fi

                # Collect built jars after building
                built_jars=()
                for build_output_dir in "${build_output_dirs[@]}"; do
                    if [[ -d "$build_output_dir" ]]; then
                        jars_in_dir=($(find "$build_output_dir" -maxdepth 1 -type f -name "*.jar" \
                            ! -name "*javadoc*" ! -name "*sources*" ! -name "*part*" ! -name "original*" 2>/dev/null))
                        built_jars+=("${jars_in_dir[@]}")
                    fi
                done

                if [[ ${#built_jars[@]} -gt 0 ]]; then
                    # Select the preferred jar
                    preferred_jar=$(select_preferred_jar "${built_jars[@]}")

                    # Remove old JARs in OUTPUT_DIR for this plugin
                    mkdir -p "$OUTPUT_DIR/old"
                    matching_jars=($(find "$OUTPUT_DIR" -maxdepth 1 -type f -name "*.jar" -iname "*${plugin_name}*.jar"))
                    for old_jar in "${matching_jars[@]}"; do
                        mv "$old_jar" "$OUTPUT_DIR/old/"
                    done

                    # Copy the preferred jar to OUTPUT_DIR with its original name
                    cp "$preferred_jar" "$OUTPUT_DIR/" 2>/dev/null

                    build_results["$plugin_key"]="built"
                else
                    build_results["$plugin_key"]="Fail"
                fi
            else
                build_results["$plugin_key"]="Fail"
            fi
        else
            # Copy existing JARs to OUTPUT_DIR
            built_jars=()
            for build_output_dir in "${build_output_dirs[@]}"; do
                if [[ -d "$build_output_dir" ]]; then
                    jars_in_dir=($(find "$build_output_dir" -maxdepth 1 -type f -name "*.jar" \
                        ! -name "*javadoc*" ! -name "*sources*" ! -name "*part*" ! -name "original*" 2>/dev/null))
                    built_jars+=("${jars_in_dir[@]}")
                fi
            done

            if [[ ${#built_jars[@]} -gt 0 ]]; then
                preferred_jar=$(select_preferred_jar "${built_jars[@]}")

                # Remove old JARs in OUTPUT_DIR for this plugin
                mkdir -p "$OUTPUT_DIR/old"
                matching_jars=($(find "$OUTPUT_DIR" -maxdepth 1 -type f -name "*.jar" -iname "*${plugin_name}*.jar"))
                for old_jar in "${matching_jars[@]}"; do
                    mv "$old_jar" "$OUTPUT_DIR/old/"
                done

                # Copy the preferred jar to OUTPUT_DIR with its original name
                cp "$preferred_jar" "$OUTPUT_DIR/" 2>/dev/null

                build_results["$plugin_key"]="cached"
            else
                build_results["$plugin_key"]="Fail"
            fi
        fi

        completed=$((completed + 1))
        progress_bar "$prefix" "$plugin_name"
    done
done

# Move to the next line after the progress bar
echo

# Save new commit hashes to file, sorted as per build order
{
    sorted_keys=($(sort_projects "${!new_commit_hashes[@]}"))
    for plugin_key in "${sorted_keys[@]}"; do
        echo "${plugin_key}:${new_commit_hashes[$plugin_key]}"
    done
} > "$COMMIT_HASH_FILE"

# Output the build results
echo -e "\nBuild Summary:\n"

pass_list=()
cached_list=()
fail_list=()

for project in "${!build_results[@]}"; do
    status="${build_results[$project]}"
    if [[ "$status" == "built" ]]; then
        pass_list+=("$project")
    elif [[ "$status" == "Fail" ]]; then
        fail_list+=("$project")
    elif [[ "$status" == "cached" ]]; then
        cached_list+=("$project")
    fi
done

if [[ ${#pass_list[@]} -gt 0 ]]; then
    echo -e "Plugins built successfully:\n"
    sorted_pass_list=($(sort_projects "${pass_list[@]}"))
    for project in "${sorted_pass_list[@]}"; do
        echo "- $project"
    done
fi

# Moved Cached Plugins above Failed Builds
if [[ ${#cached_list[@]} -gt 0 ]]; then
    echo
    echo -e "Cached plugins:\n"
    sorted_cached_list=($(sort_projects "${cached_list[@]}"))
    for project in "${sorted_cached_list[@]}"; do
        echo "- $project"
    done
fi

if [[ ${#fail_list[@]} -gt 0 ]]; then
    echo
    echo -e "Failed builds:\n"
    sorted_fail_list=($(sort_projects "${fail_list[@]}"))
    for project in "${sorted_fail_list[@]}"; do
        echo "- $project"
    done
fi

# If there are any failed builds, print log directory location
if [[ ${#fail_list[@]} -gt 0 ]]; then
    echo
    echo "Build logs for failed plugins are located at: $LOG_DIR"
fi

# Add a descriptive closing message
total_built=${#pass_list[@]}
total_cached=${#cached_list[@]}
total_failed=${#fail_list[@]}
total_plugins=$((total_built + total_cached + total_failed))

echo
echo "Build process completed."
echo "Total plugins processed: $total_plugins"
echo "Plugins built successfully: $total_built"
echo "Plugins cached (no rebuild needed): $total_cached"
echo "Failed builds: $total_failed"

if $halted; then
    echo -e "\nBuild process was halted by the user."
    echo
fi
