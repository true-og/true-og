#!/bin/bash

echo "Initializing and updating submodules..."
failed_submodules=()
git submodule update --force --recursive --init --remote 2>&1 | while read -r line; do
    if [[ "$line" =~ ^Submodule\ path\ \'plugins\/([^\']+)\' ]]; then
        submodule="${BASH_REMATCH[1]}"
        echo -ne "\rUpdating submodule: $submodule                  "
    fi
    if [[ "$line" =~ fatal|error ]]; then
        failed_submodules+=("$submodule")
    fi
done

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

trap 'echo -e "\n\nBuild process interrupted."; halted=true' SIGINT

BASE_DIR="$(dirname "$0")/plugins"  # Point to plugins directory inside true-og
OUTPUT_DIR="$(dirname "$0")/server"  # Output JAR files to server folder inside true-og

mkdir -p "$OUTPUT_DIR"

hash_file() {
    local file_path="$1"
    sha256sum "$file_path" | awk '{print $1}'
}

is_cached() {
    local built_jar="$1"
    local built_hash
    built_hash=$(hash_file "$built_jar")
    for existing_jar in "$OUTPUT_DIR"/*.jar; do
        if [[ -f "$existing_jar" && "$built_hash" == "$(hash_file "$existing_jar")" ]]; then
            return 0  # Cached
        fi
    done
    return 1  # Not cached
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

total_dirs=$(find "$BASE_DIR" -mindepth 2 -maxdepth 2 -type d ! -name '.*' | wc -l)
completed=0

build_order=("OG-Suite" "Hard-Forks" "Soft-Forks" "Third-Party")

sort_by_prefix_order() {
    local arr=("$@")
    local sorted=()
    for prefix in "${build_order[@]}"; do
        # Collect items for this prefix
        local prefix_items=()
        for item in "${arr[@]}"; do
            if [[ $item == "$prefix/"* ]]; then
                prefix_items+=("$item")
            fi
        done
        # Sort the prefix_items alphabetically
        if [[ ${#prefix_items[@]} -gt 0 ]]; then
            IFS=$'\n' sorted_prefix_items=($(sort <<<"${prefix_items[*]}"))
            unset IFS
            # Add to sorted list
            sorted+=("${sorted_prefix_items[@]}")
        fi
    done
    echo "${sorted[@]}"
}

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
    printf "\rBuilding %s: %s [%-20s] %3d%%" "$formatted_subfolder" "$formatted_project_name" "$bar" "$progress"
}

for prefix in "${build_order[@]}"; do
    for main_dir in "$BASE_DIR/$prefix"*/; do
        [[ ! -d "$main_dir" || "$main_dir" == "$OUTPUT_DIR/" ]] && continue

        for dir in "$main_dir"*/; do
            if $halted; then
                break 2
            fi

            subfolder="${prefix}"
            plugin_name="$(basename "$dir")"

            # Determine the build output directory and expected jar files
            build_output_dirs=()
            if [[ -d "$dir/build/libs" ]]; then
                build_output_dirs+=("$dir/build/libs")
            elif [[ -d "$dir/target" ]]; then
                build_output_dirs+=("$dir/target")
            fi

            # Collect existing built jars
            built_jars=()
            for build_output_dir in "${build_output_dirs[@]}"; do
                if [[ -d "$build_output_dir" ]]; then
                    jars_in_dir=($(find "$build_output_dir" -maxdepth 1 -type f -name "*.jar" \
                        ! -name "*javadoc*" ! -name "*sources*" ! -name "*part*" ! -name "original*"))
                    built_jars+=("${jars_in_dir[@]}")
                fi
            done

            if [[ ${#built_jars[@]} -gt 0 ]]; then
                # Select the preferred jar
                preferred_jar=$(select_preferred_jar "${built_jars[@]}")
                built_hash=$(hash_file "$preferred_jar")
                jar_cached=false
                for server_jar in "$OUTPUT_DIR"/*.jar; do
                    if [[ -f "$server_jar" ]]; then
                        server_hash=$(hash_file "$server_jar")
                        if [[ "$built_hash" == "$server_hash" ]]; then
                            jar_cached=true
                            break
                        fi
                    fi
                done

                if $jar_cached; then
                    # Jar is cached, no need to rebuild
                    build_results["$subfolder/$plugin_name"]="cached"
                    # Copy the preferred jar to OUTPUT_DIR (overwrite if necessary)
                    cp "$preferred_jar" "$OUTPUT_DIR/"
                else
                    # Need to build the project
                    progress_bar "$subfolder" "$plugin_name"
                    build_command=""
                    if [[ -f "$dir/build.gradle" || -f "$dir/settings.gradle" || -f "$dir/build.gradle.kts" || -f "$dir/settings.gradle.kts" ]]; then
                        build_command="./gradlew build -q"
                    elif [[ -f "$dir/pom.xml" ]]; then
                        build_command="mvn package -q"
                    else
                        build_results["$subfolder/$plugin_name"]="Fail"
                        completed=$((completed + 1))
                        progress_bar "$subfolder" "$plugin_name"
                        continue
                    fi

                    (cd "$dir" && $build_command > /dev/null 2>&1)
                    if [[ $? -eq 0 ]]; then
                        # Collect built jars again after building
                        built_jars=()
                        for build_output_dir in "${build_output_dirs[@]}"; do
                            if [[ -d "$build_output_dir" ]]; then
                                jars_in_dir=($(find "$build_output_dir" -maxdepth 1 -type f -name "*.jar" \
                                    ! -name "*javadoc*" ! -name "*sources*" ! -name "*part*" ! -name "original*"))
                                built_jars+=("${jars_in_dir[@]}")
                            fi
                        done

                        if [[ ${#built_jars[@]} -gt 0 ]]; then
                            # Select the preferred jar
                            preferred_jar=$(select_preferred_jar "${built_jars[@]}")
                            # Copy the preferred jar to OUTPUT_DIR
                            cp "$preferred_jar" "$OUTPUT_DIR/"
                            build_results["$subfolder/$plugin_name"]="built"
                        else
                            build_results["$subfolder/$plugin_name"]="Fail"
                        fi
                    else
                        build_results["$subfolder/$plugin_name"]="Fail"
                    fi
                fi
            else
                # No built jars found, need to build the project
                progress_bar "$subfolder" "$plugin_name"
                build_command=""
                if [[ -f "$dir/build.gradle" || -f "$dir/settings.gradle" || -f "$dir/build.gradle.kts" || -f "$dir/settings.gradle.kts" ]]; then
                    build_command="./gradlew build -q"
                elif [[ -f "$dir/pom.xml" ]]; then
                    build_command="mvn package -q"
                else
                    build_results["$subfolder/$plugin_name"]="Fail"
                    completed=$((completed + 1))
                    progress_bar "$subfolder" "$plugin_name"
                    continue
                fi

                (cd "$dir" && $build_command > /dev/null 2>&1)
                if [[ $? -eq 0 ]]; then
                    # Collect built jars after building
                    built_jars=()
                    for build_output_dir in "${build_output_dirs[@]}"; do
                        if [[ -d "$build_output_dir" ]]; then
                            jars_in_dir=($(find "$build_output_dir" -maxdepth 1 -type f -name "*.jar" \
                                ! -name "*javadoc*" ! -name "*sources*" ! -name "*part*" ! -name "original*"))
                            built_jars+=("${jars_in_dir[@]}")
                        fi
                    done

                    if [[ ${#built_jars[@]} -gt 0 ]]; then
                        # Select the preferred jar
                        preferred_jar=$(select_preferred_jar "${built_jars[@]}")
                        # Copy the preferred jar to OUTPUT_DIR
                        cp "$preferred_jar" "$OUTPUT_DIR/"
                        build_results["$subfolder/$plugin_name"]="built"
                    else
                        build_results["$subfolder/$plugin_name"]="Fail"
                    fi
                else
                    build_results["$subfolder/$plugin_name"]="Fail"
                fi
            fi

            completed=$((completed + 1))
            progress_bar "$subfolder" "$plugin_name"
        done
    done
done

pass_list=()
cached_list=()
fail_list=()

for project in "${!build_results[@]}"; do
    status="${build_results[$project]}"
    if [[ "$status" == "cached" ]]; then
        cached_list+=("$project")
    elif [[ "$status" == "built" ]]; then
        pass_list+=("$project")
    elif [[ "$status" == "Fail" ]]; then
        fail_list+=("$project")
    fi
done

echo -e "\n\nPlugins built successfully:"
sorted_pass_list=($(sort_by_prefix_order "${pass_list[@]}"))
for project in "${sorted_pass_list[@]}"; do
    echo "$project"
done

echo -e "\nCached plugins:"
sorted_cached_list=($(sort_by_prefix_order "${cached_list[@]}"))
for project in "${sorted_cached_list[@]}"; do
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
