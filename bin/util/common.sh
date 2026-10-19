
#!/usr/bin/env bash

print() {
    echo "-----> $*"
}

indent() {
    local c='s/^/       /'
    case "$(uname)" in
        Darwin) sed -l "$c" ;;
        *)      sed -u "$c" ;;
    esac
}

get_os() {
    uname | tr '[:upper:]' '[:lower:]'
}

get_cpu() {
    local arch
    arch="$(uname -m)"

    case "$arch" in
        x86_64|amd64) echo "x64" ;;
        i386|i486|i586|i686) echo "x86" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armv6l) echo "arm" ;;
        *) echo "$arch" ;;
    esac
}

get_platform() {
    echo "$(get_os)-$(get_cpu)"
}

get_linux_platform_version() {
    if [[ -f /etc/os-release ]]; then
        (
            . /etc/os-release
            printf '%s\n' "${VERSION_ID//[a-zA-Z]/}"
        )
        return 0
    fi

    print "Linux platform version could not be detected: uname=$(uname)" >&2
    return 1
}

error() {
    local c="2,999 s/^/ !     /"

    exec 1>&2
    echo -e "\033[1;31m"
    echo -n " !     ERROR: "

    case "$(uname)" in
        Darwin) sed -l "$c" ;;
        *)      sed -u "$c" ;;
    esac

    echo -e "\033[0m"
    exit 1
}

export_env_dir() {
    local env_dir="${1:-}"
    local whitelist_regex="${2:-.*}"
    local blacklist_regex="${3:-^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH|LANG|BUILD_DIR)$}"
    local e value

    [[ -d "$env_dir" ]] || return 0

    while IFS= read -r -d '' e; do
        e="${e##*/}"

        [[ "$e" =~ $whitelist_regex ]] || continue
        [[ "$e" =~ $blacklist_regex ]] && continue
        [[ "$e" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue
        [[ -f "$env_dir/$e" ]] || continue

        value="$(cat "$env_dir/$e")"
        export "$e=$value"
    done < <(find "$env_dir" -mindepth 1 -maxdepth 1 -type f -print0)
}

# args: input string, match, replacement
string_replace() {
    local string="${1:-}"
    local match="${2:-}"
    local replacement="${3:-}"

    printf '%s\n' "${string/"$match"/"$replacement"}"
}

remove_trailing_slash() {
    local input="${1:-}"
    printf '%s\n' "${input%/}"
}

remove_beginning_slash() {
    local input="${1:-}"
    printf '%s\n' "${input#/}"
}

# Find the first solution file, searching the root and parent
# directories of the first file found beneath the build directory.
get_project_sln_file() {
    local build_dir="${1:-}"
    local file

    [[ -d "$build_dir" ]] || return 0

    while IFS= read -r -d '' file; do
        printf '%s\n' "$file"
        return 0
    done < <(
        find "$build_dir" -maxdepth 3 -type f \
            \( -name '*.sln' -o -name '*.slnx' \) -print0
    )
}

get_project_sln_name() {
    local solution_file
    solution_file="$(get_project_sln_file "${1:-}")"

    if [[ -n "$solution_file" ]]; then
        basename "${solution_file%.*}"
    fi
}

# Find a project file within the build directory.
get_project_file() {
    local build_dir="${1:-}"
    local file

    [[ -d "$build_dir" ]] || return 0

    while IFS= read -r -d '' file; do
        printf '%s\n' "$file"
        return 0
    done < <(
        find "$build_dir" -maxdepth 3 -type f \
            -name '*.csproj' -print0
    )
}

get_project_name() {
    local project_file
    project_file="$(get_project_file "${1:-}")"

    if [[ -n "$project_file" ]]; then
        basename "${project_file%.*}"
    fi
}

# Locate launchSettings.json and infer the project directory.
get_start_project_name() {
    local build_dir="${1:-}"
    local launch_file
    local project_dir
    local project_file
    local project_name

    [[ -d "$build_dir" ]] || return 0

    while IFS= read -r -d '' launch_file; do
        project_dir="$(dirname "$(dirname "$launch_file")")"

        project_file="$(
            find "$project_dir" -maxdepth 1 -type f \
                -name '*.csproj' -print -quit
        )"

        if [[ -n "$project_file" ]]; then
            project_name="$(basename "${project_file%.*}")"

            if [[ "$project_name" == build_* ]]; then
                project_name="$(get_project_name "$build_dir")"
            fi

            printf '%s\n' "$project_name"
            return 0
        fi
    done < <(
        find "$build_dir" -maxdepth 5 -type f \
            -name 'launchSettings.json' -print0
    )

    get_project_name "$build_dir"
}

get_specific_version() {
    local build_dir="${1:-}"
    local file

    [[ -d "$build_dir" ]] || return 0

    while IFS= read -r -d '' file; do
        cat "$file"
        return 0
    done < <(
        find "$build_dir" -maxdepth 4 -type f \
            -name 'productVersion.txt' -print0
    )
}

# Read TargetFramework or TargetFrameworks from a project file.
# Examples: net8.0 -> 8.0; netcoreapp3.1 -> 3.1.
get_framework_version() {
    local input="${1:-}"
    local project_file
    local framework

    if [[ -f "$input" && "$input" == *.csproj ]]; then
        project_file="$input"
    else
        project_file="$(get_project_file "$input")"
    fi

    [[ -n "$project_file" && -f "$project_file" ]] || return 0

    framework="$(
        sed -nE \
            's/.*<TargetFrameworks?>[[:space:]]*([^<]+)[[:space:]]*<\/TargetFrameworks?>.*/\1/p' \
            "$project_file" | head -n 1
    )"

    [[ -n "$framework" ]] || return 0

    framework="${framework%%;*}"

    if [[ "$framework" =~ ^netcoreapp([0-9]+(\.[0-9]+)*)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    elif [[ "$framework" =~ ^netstandard([0-9]+(\.[0-9]+)*)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    elif [[ "$framework" =~ ^net([0-9]+(\.[0-9]+)*)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    else
        printf '%s\n' "$framework"
    fi
}

get_runtime_framework_version() {
    local input="${1:-}"
    local project_file
    local version

    if [[ -f "$input" && "$input" == *.csproj ]]; then
        project_file="$input"
    else
        project_file="$(get_project_file "$input")"
    fi

    [[ -n "$project_file" && -f "$project_file" ]] || {
        echo "Latest"
        return 0
    }

    version="$(
        sed -nE \
            's/.*<RuntimeFrameworkVersion>[[:space:]]*([^<]+)[[:space:]]*<\/RuntimeFrameworkVersion>.*/\1/p' \
            "$project_file" | head -n 1
    )"

    if [[ -z "$version" ]]; then
        echo "Latest"
    else
        printf '%s\n' "$version"
    fi
}

is_postgres_used() {
    local input="${1:-}"
    local project_file

    if [[ -f "$input" && "$input" == *.csproj ]]; then
        project_file="$input"
    else
        project_file="$(get_project_file "$input")"
    fi

    if [[ -n "$project_file" ]] &&
       grep -qi 'Npgsql' "$project_file"; then
        echo "yes"
    else
        echo "no"
    fi
}

# Source KEY=value lines from an env file.
# Intended for trusted, simple environment files, not arbitrary shell scripts.
source_envfile() {
    local env_file="${1:-}"
    local line key value

    [[ -f "$env_file" ]] || return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" == *=* ]] || continue

        key="${line%%=*}"
        value="${line#*=}"

        key="${key//[[:space:]]/}"
        [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue

        export "$key=$value"
    done < "$env_file"
}

# Compare two decimal numbers.
# Usage: decimal_compare 1.2 1.5 '<'
# Returns success when the comparison is true.
decimal_compare() {
    local n1="${1:-0}"
    local n2="${2:-0}"
    local operator="${3:-}"

    awk -v n1="$n1" -v n2="$n2" -v op="$operator" '
        BEGIN {
            if (n1 !~ /^-?[0-9]+([.][0-9]+)?$/ ||
                n2 !~ /^-?[0-9]+([.][0-9]+)?$/) {
                exit 2
            }

            if      (op == "<")  result = (n1 < n2)
            else if (op == "<=") result = (n1 <= n2)
            else if (op == ">")  result = (n1 > n2)
            else if (op == ">=") result = (n1 >= n2)
            else if (op == "==") result = (n1 == n2)
            else if (op == "!=") result = (n1 != n2)
            else exit 2

            exit(result ? 0 : 1)
        }
    '
}
