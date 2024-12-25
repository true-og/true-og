#!/usr/bin/env bash
# This is free and unencumbered software released into the public domain.
# Builds all TrueOG Plugins and puts them into a folder called server/ in the current directory.

# Stage 4: Build all plugins.

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

echo
read -p "Press Enter to start..."

# Enable nullglob and extglob to handle non-matching patterns and extended globbing.
shopt -s nullglob extglob

# Declare the project root for git submodule fetching.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Define absolute paths for directories.
BASE_DIR="$PROJECT_ROOT/plugins"
OUTPUT_DIR="$PROJECT_ROOT/server"
LOG_DIR="$OUTPUT_DIR/logs"
COMMIT_HASH_FILE="$OUTPUT_DIR/commit_hashes.txt"
WORK_DIR="$(pwd)"
GRADLE_USER_HOME="$PROJECT_ROOT/.gradle"
SELF_MAVEN_LOCAL_REPO="$WORK_DIR/.m2/repository"

declare -A plugin_commit_hash_before
declare -A plugin_commit_hash_after
declare -A new_commit_hashes
declare -A build_results
declare -A plugin_dirs
halted=false

# Function to handle script interruption.
cleanup() {
    echo -e "\n\nBuild process interrupted."
    halted=true
    exit 1
}

# Trap SIGINT (Ctrl+C) and call cleanup.
trap 'cleanup' SIGINT

mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

build_order=("OG-Suite" "Hard-Forks" "Soft-Forks" "Third-Party")

# Function to get commit hash of a plugin directory.
get_plugin_commit_hash() {
    local dir="$1"
    if [[ -e "$dir/.git" ]]; then
        (cd "$dir" && git rev-parse HEAD 2>/dev/null)
    else
        echo ""
    fi
}

# Load previous commit hashes if they exist.
if [[ -f "$COMMIT_HASH_FILE" ]]; then
    while IFS=: read -r plugin_key commit_hash; do
        plugin_commit_hash_before["$plugin_key"]="$commit_hash"
    done < "$COMMIT_HASH_FILE"
fi

echo

# Change directory to the project root before fetching submodules.
cd "$PROJECT_ROOT" || { echo "Failed to change directory to $PROJECT_ROOT"; exit 1; }

# Updating submodules with a progress bar.
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
    git submodule update --force --recursive --init --quiet "$submodule_path" &> "$LOG_DIR/${submodule_name}_update.log"
    if [[ $? -ne 0 ]]; then
        failed_submodules["$submodule_path"]=1
    fi
done

# Move to next line after progress bar.
echo

# Retry failed submodules if any.
if [[ ${#failed_submodules[@]} -gt 0 ]]; then
    echo
    echo "Retrying failed submodules..."
    for submodule_path in "${!failed_submodules[@]}"; do
        submodule_name=$(basename "$submodule_path")
        echo "Retrying $submodule_name..."
        git submodule update --force --recursive --init --quiet "$submodule_path" &>> "$LOG_DIR/${submodule_name}_update.log"
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

# Return to the bootstrap directory.
cd "$PROJECT_ROOT/bootstrap" || { echo "Failed to return to $PROJECT_ROOT/bootstrap"; exit 1; }

# Build list of plugin keys and collect commit hashes.
declare -a plugin_keys

for prefix in "${build_order[@]}"; do
    for dir in "$BASE_DIR/$prefix"/*/; do
        [[ ! -d "$dir" ]] && continue
        plugin_name="$(basename "$dir")"
        plugin_key="${prefix}/${plugin_name}"

        # Exclude specific plugins.
        if [[ "$plugin_key" == "OG-Suite/Template-OG" || \
              "$plugin_key" == "OG-Suite/KotlinTemplate-OG" || \
              "$plugin_key" == "OG-Suite/plugins" || \
              "$plugin_key" == "Hard-Forks/plugins" || \
              "$plugin_key" == "Soft-Forks/plugins" || \
              "$plugin_key" == "Third-Party/plugins" ]]; then
            continue
        fi

        if [[ "$plugin_key" == "Soft-Forks/Essentials-OG" ]]; then
            # Add both pseudo-plugins.
            plugin_keys+=("Soft-Forks/EssentialsX")
            plugin_keys+=("Soft-Forks/EssentialsXSpawn")
            # Set commit hash under Essentials-OG.
            commit_hash="$(get_plugin_commit_hash "$dir")"
            plugin_commit_hash_after["Soft-Forks/Essentials-OG"]="$commit_hash"
            new_commit_hashes["Soft-Forks/Essentials-OG"]="$commit_hash"
            plugin_dirs["Soft-Forks/EssentialsX"]="$dir"
            plugin_dirs["Soft-Forks/EssentialsXSpawn"]="$dir"
        else
            plugin_keys+=("$plugin_key")
            commit_hash="$(get_plugin_commit_hash "$dir")"
            plugin_commit_hash_after["$plugin_key"]="$commit_hash"
            new_commit_hashes["$plugin_key"]="$commit_hash"
            plugin_dirs["$plugin_key"]="$dir"
        fi
    done
done

# Stop all existing Gradle daemons if available.
if command -v gradle >/dev/null 2>&1; then
    gradle --stop >/dev/null 2>&1
fi

# Initialize counters for progress bar.
total_dirs=${#plugin_keys[@]}
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
    # Prefer jars without "-all" in their name.
    local preferred_jars=()
    for jar in "${jars[@]}"; do
        basename=$(basename "$jar")
        if [[ ! "$basename" =~ -all\.jar$ ]]; then
            preferred_jars+=("$jar")
        fi
    done
    if [[ ${#preferred_jars[@]} -eq 0 ]]; then
        # No jars without "-all.jar"
        preferred_jars=("${jars[@]}")
    fi
    # Select the jar with the shortest name.
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

for plugin_key in "${plugin_keys[@]}"; do
    if $halted; then
        break
    fi

    prefix="${plugin_key%%/*}"
    plugin_name="${plugin_key##*/}"
    dir="${plugin_dirs[$plugin_key]}"

    progress_bar "$prefix" "$plugin_name"

    # Handle pseudo plugins using Essentials-OG commit hash.
    if [[ "$plugin_key" == "Soft-Forks/EssentialsX" || "$plugin_key" == "Soft-Forks/EssentialsXSpawn" ]]; then
        commit_hash="${plugin_commit_hash_after["Soft-Forks/Essentials-OG"]}"
        commit_hash_before="${plugin_commit_hash_before["Soft-Forks/Essentials-OG"]}"
    else
        commit_hash="${plugin_commit_hash_after["$plugin_key"]}"
        commit_hash_before="${plugin_commit_hash_before["$plugin_key"]}"
    fi

    need_to_build=false
    if [[ -n "$commit_hash_before" && -n "$commit_hash" && "$commit_hash_before" == "$commit_hash" ]]; then
        # Plugin did not change. Check if JAR exists.
        jar_exists=false
        if [[ "$plugin_key" == "Soft-Forks/EssentialsX" ]]; then
            plugin_names=("Essentials-OG" "EssentialsX-OG")
        elif [[ "$plugin_key" == "Soft-Forks/EssentialsXSpawn" ]]; then
            plugin_names=("EssentialsXSpawn-OG")
        elif [[ "$plugin_key" == "Hard-Forks/MiniPlaceholders-AFKPlus" ]]; then
            plugin_names=("MiniPlaceholders-AFKPlus")
        elif [[ "$plugin_key" == "Hard-Forks/MiniPlaceholders-Essentials" ]]; then
            plugin_names=("MiniPlaceholders-Essentials")
        elif [[ "$plugin_key" == "Hard-Forks/MiniPlaceholders-Statistic" ]]; then
            plugin_names=("MiniPlaceholders-Statistic")
        else
            plugin_names=("$plugin_name")
        fi

        for jar_file in "$OUTPUT_DIR"/*.jar; do
            base_name=$(basename "$jar_file" .jar)
            for name in "${plugin_names[@]}"; do
                remaining="${base_name#$name}"
                if [[ "$remaining" == "" || "$remaining" =~ ^[-\.][0-9] ]]; then
                    jar_exists=true
                    break 2
                fi
            done
        done

        if $jar_exists; then
            # No rebuild needed.
            build_results["$plugin_key"]="cached"
            completed=$((completed + 1))
            progress_bar "$prefix" "$plugin_name"
            continue
        else
            need_to_build=true
        fi
    else
        need_to_build=true
    fi

    if $need_to_build; then
        # Find build output dirs.
        build_output_dirs=()
        [[ -d "$dir/build/libs" ]] && build_output_dirs+=("$dir/build/libs")
        [[ -d "$dir/target" ]] && build_output_dirs+=("$dir/target")
        [[ -d "$dir/build/distributions" ]] && build_output_dirs+=("$dir/build/distributions")

        # Move existing jars to old/
        for build_output_dir in "${build_output_dirs[@]}"; do
            if [[ -d "$build_output_dir" ]]; then
                mkdir -p "$build_output_dir/old"
                find "$build_output_dir" -maxdepth 1 -type f -name "*.jar" ! -path "*/old/*" \
                    -exec mv {} "$build_output_dir/old/" \;
            fi
        done

        # Determine build tool.
        if [[ -f "$dir/gradlew" ]]; then
            chmod +x "$dir/gradlew" 2>/dev/null
        fi

        if [[ -f "$dir/build.gradle" || -f "$dir/settings.gradle" || -f "$dir/build.gradle.kts" || -f "$dir/settings.gradle.kts" ]]; then
            build_command="./gradlew -DSELF_MAVEN_LOCAL_REPO=$SELF_MAVEN_LOCAL_REPO --gradle-user-home=$GRADLE_USER_HOME --no-daemon --no-parallel clean build"
            use_gradle=true
        elif [[ -f "$dir/pom.xml" ]]; then
            build_command="./mvnw clean package -Dmaven.repo.local=$SELF_MAVEN_LOCAL_REPO"
            use_gradle=false
        else
            build_results["$plugin_key"]="Fail"
            completed=$((completed + 1))
            progress_bar "$prefix" "$plugin_name"
            continue
        fi

        build_log="$LOG_DIR/${plugin_name}_build.log"
        (
            cd "$dir" || exit
            if $use_gradle; then
                export GRADLE_USER_HOME="$dir/.gradle"
            fi
            $build_command
        ) > "$build_log" 2>&1

        build_exit_code=$?

        if [[ $build_exit_code -eq 0 ]]; then
            # Recollect build output directories.
            build_output_dirs=()
            [[ -d "$dir/build/libs" ]] && build_output_dirs+=("$dir/build/libs")
            [[ -d "$dir/target" ]] && build_output_dirs+=("$dir/target")
            [[ -d "$dir/build/distributions" ]] && build_output_dirs+=("$dir/build/distributions")

            built_jars=()
            for build_output_dir in "${build_output_dirs[@]}"; do
                if [[ -d "$build_output_dir" ]]; then
                    for jar_file in "$build_output_dir/"*.jar; do
                        if [[ -f "$jar_file" ]]; then
                            jar_name="$(basename "$jar_file")"
                            if [[ "$jar_name" != *javadoc* && "$jar_name" != *sources* && "$jar_name" != *part* && "$jar_name" != original* ]]; then
                                built_jars+=("$jar_file")
                            fi
                        fi
                    done
                fi
            done

            # Handle plugin-specific jar name patterns.
            if [[ "$plugin_key" == "Soft-Forks/EssentialsX" ]]; then
                plugin_names=("Essentials-OG" "EssentialsX-OG")
            elif [[ "$plugin_key" == "Soft-Forks/EssentialsXSpawn" ]]; then
                plugin_names=("EssentialsXSpawn-OG")
            elif [[ "$plugin_key" == "Hard-Forks/MiniPlaceholders-AFKPlus" ]]; then
                plugin_names=("MiniPlaceholders-AFKPlus")
            elif [[ "$plugin_key" == "Hard-Forks/MiniPlaceholders-Essentials" ]]; then
                plugin_names=("MiniPlaceholders-Essentials")
            elif [[ "$plugin_key" == "Hard-Forks/MiniPlaceholders-Statistic" ]]; then
                plugin_names=("MiniPlaceholders-Statistic")
            else
                plugin_names=("$plugin_name")
            fi

            sub_built_jars=()
            for jar_file in "${built_jars[@]}"; do
                jar_name=$(basename "$jar_file" .jar)
                for name in "${plugin_names[@]}"; do
                    remaining="${jar_name#$name}"
                    if [[ "$remaining" == "" || "$remaining" =~ ^[-\.][0-9] ]]; then
                        sub_built_jars+=("$jar_file")
                        break
                    fi
                done
            done

            if [[ ${#sub_built_jars[@]} -gt 0 ]]; then
                preferred_jar=$(select_preferred_jar "${sub_built_jars[@]}")
                preferred_jar_name="$(basename "$preferred_jar")"

                mkdir -p "$OUTPUT_DIR/old"
                for old_jar in "$OUTPUT_DIR/"*.jar; do
                    if [[ -f "$old_jar" ]]; then
                        old_jar_name=$(basename "$old_jar" .jar)
                        for name in "${plugin_names[@]}"; do
                            remaining="${old_jar_name#$name}"
                            if [[ "$remaining" == "" || "$remaining" =~ ^[-\.][0-9] ]]; then
                                if [[ "$old_jar_name.jar" != "$preferred_jar_name" ]]; then
                                    mv "$old_jar" "$OUTPUT_DIR/old/"
                                fi
                                break
                            fi
                        done
                    fi
                done

                cp "$preferred_jar" "$OUTPUT_DIR/" 2>/dev/null
                build_results["$plugin_key"]="built"
            else
                echo "Error: No JAR files found after building plugin '$plugin_name'." >> "$build_log"
                build_results["$plugin_key"]="Fail"
            fi
        else
            build_results["$plugin_key"]="Fail"
        fi
    else
        build_results["$plugin_key"]="cached"
    fi

    completed=$((completed + 1))
    progress_bar "$prefix" "$plugin_name"
done

echo

{
    sorted_keys=($(sort_projects "${!new_commit_hashes[@]}"))
    for plugin_key in "${sorted_keys[@]}"; do
        echo "${plugin_key}:${new_commit_hashes[$plugin_key]}"
    done
} > "$COMMIT_HASH_FILE"

echo ""
echo "Build Summary:"
echo ""

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
    echo "Plugins built successfully:"
    echo ""
    sorted_pass_list=($(sort_projects "${pass_list[@]}"))
    for project in "${sorted_pass_list[@]}"; do
        echo "- $project"
    done
    echo ""
fi

if [[ ${#cached_list[@]} -gt 0 ]]; then
    echo "Cached plugins:"
    echo ""
    sorted_cached_list=($(sort_projects "${cached_list[@]}"))
    for project in "${sorted_cached_list[@]}"; do
        echo "- $project"
    done
    echo ""
fi

if [[ ${#fail_list[@]} -gt 0 ]]; then
    echo "Failed builds:"
    echo ""
    sorted_fail_list=($(sort_projects "${fail_list[@]}"))
    for project in "${sorted_fail_list[@]}"; do
        echo "- $project"
    done
    echo ""
fi

total_built=${#pass_list[@]}
total_cached=${#cached_list[@]}
total_failed=${#fail_list[@]}
total_plugins=$((total_built + total_cached + total_failed))

#
# Only print "ERROR: Failed to build all plugins!" if there are actually any failed builds.
#
if [[ $total_failed -gt 0 ]]; then
    echo "ERROR: Failed to build all plugins!"
else
    echo "Completed plugin jarfiles: $OUTPUT_DIR/"
fi

echo ""
echo "Build logs: $LOG_DIR/"
echo ""
echo "Total plugins: $total_plugins"

if [[ $total_built -gt 0 ]]; then
    echo ""
    echo "Plugins built: $total_built"
fi

if [[ $total_cached -gt 0 ]]; then
    echo ""
    echo "Cached plugins: $total_cached"
fi

if [[ $total_failed -gt 0 ]]; then
    echo ""
    echo "Failed builds: $total_failed"
fi

if $halted; then
    echo ""
    echo "WARNING: Build process was halted manually!"
fi

