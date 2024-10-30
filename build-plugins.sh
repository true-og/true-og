#!/bin/bash

echo "Initializing and updating submodules..."
git submodule update --force --recursive --init --remote 2>&1 | tee submodule_update.log

# Check for errors in submodule update
if grep -i -E "fatal|error" submodule_update.log; then
    echo "Submodule update encountered errors. See 'submodule_update.log' for details."
    exit 1
else
    echo "Submodules updated successfully."
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

build_order=("OG-Suite" "Hard-Forks" "Soft-Forks" "Third-Party")

for prefix in "${build_order[@]}"; do
    for main_dir in "$BASE_DIR/$prefix"*/; do
        [[ ! -d "$main_dir" || "$main_dir" == "$OUTPUT_DIR/" ]] && continue

        for dir in "$main_dir"*/; do
            if $halted; then
                break 2
            fi

            subfolder="${prefix}"
            plugin_name="$(basename "$dir")"

            echo "Processing plugin: $plugin_name in category: $subfolder"

            # Determine the build output directory
            build_output_dirs=()
            if [[ -d "$dir/build/libs" ]]; then
                build_output_dirs+=("$dir/build/libs")
            elif [[ -d "$dir/target" ]]; then
                build_output_dirs+=("$dir/target")
            fi

            # Check for existing built jars
            built_jars=()
            for build_output_dir in "${build_output_dirs[@]}"; do
                if [[ -d "$build_output_dir" ]]; then
                    jars_in_dir=($(find "$build_output_dir" -maxdepth 1 -type f -name "*.jar" \
                        ! -name "*javadoc*" ! -name "*sources*" ! -name "*part*" ! -name "original*"))
                    built_jars+=("${jars_in_dir[@]}")
                fi
            done

            # Build the project if necessary
            need_to_build=true

            if [[ ${#built_jars[@]} -gt 0 ]]; then
                need_to_build=false
                echo "Existing JARs found for $plugin_name. Skipping build."
            fi

            if $need_to_build; then
                echo "No existing JARs found for $plugin_name. Initiating build process."

                if [[ -f "$dir/gradlew" ]]; then
                    chmod +x "$dir/gradlew"
                fi

                if [[ -f "$dir/build.gradle" || -f "$dir/settings.gradle" || -f "$dir/build.gradle.kts" || -f "$dir/settings.gradle.kts" ]]; then
                    build_command="./gradlew build"
                elif [[ -f "$dir/pom.xml" ]]; then
                    build_command="mvn package"
                else
                    echo "No build configuration found for $plugin_name. Marking as Fail."
                    build_results["$subfolder/$plugin_name"]="Fail"
                    continue
                fi

                echo "Building $plugin_name using command: $build_command"

                # Run the build command and capture output
                build_log="$OUTPUT_DIR/${plugin_name}_build.log"
                (
                    cd "$dir"
                    echo "Executing build command in $(pwd)"
                    $build_command
                ) > "$build_log" 2>&1

                build_exit_code=$?

                if [[ $build_exit_code -eq 0 ]]; then
                    echo "Build succeeded for $plugin_name."
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
                        echo "Copied built JAR to $OUTPUT_DIR/"
                        build_results["$subfolder/$plugin_name"]="built"
                    else
                        echo "No JARs found after building $plugin_name. Marking as Fail."
                        build_results["$subfolder/$plugin_name"]="Fail"
                    fi
                else
                    echo "Build failed for $plugin_name. See log at $build_log"
                    build_results["$subfolder/$plugin_name"]="Fail"
                fi
            else
                # Copy existing JARs to OUTPUT_DIR
                preferred_jar=$(select_preferred_jar "${built_jars[@]}")
                cp "$preferred_jar" "$OUTPUT_DIR/"
                echo "Copied existing JAR to $OUTPUT_DIR/"
                build_results["$subfolder/$plugin_name"]="cached"
            fi
        done
    done
done

# Output the build results
echo -e "\nBuild Summary:"

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

if [[ ${#pass_list[@]} -gt 0 ]]; then
    echo -e "\nPlugins built successfully:"
    for project in "${pass_list[@]}"; do
        echo "- $project"
    done
fi

if [[ ${#cached_list[@]} -gt 0 ]]; then
    echo -e "\nCached plugins (no build needed):"
    for project in "${cached_list[@]}"; do
        echo "- $project"
    done
fi

if [[ ${#fail_list[@]} -gt 0 ]]; then
    echo -e "\nFailed builds:"
    for project in "${fail_list[@]}"; do
        echo "- $project"
        echo "  See log at $OUTPUT_DIR/$(basename "$project")_build.log"
    done
fi

if $halted; then
    echo -e "\nBuild process was halted by the user."
fi

