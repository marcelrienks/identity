#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Versions Command Implementation                                            ║
# ║  Phase 6: User Story 4 - Version History & Display (Tasks T048-T049)        ║
# ║  Handles version listing and detailed version information display            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ============================================================================
# Versions Command Handler - Main Entry Point
# ============================================================================

versions_command() {
    local subcommand="${1:-list}"
    shift || true
    
    case "$subcommand" in
        list)
            versions_list_command "$@"
            ;;
        show)
            versions_show_command "$@"
            ;;
        --help|-h|help)
            versions_help
            ;;
        *)
            error "Unknown versions subcommand: $subcommand"
            versions_help
            return 1
            ;;
    esac
}

versions_help() {
    cat <<EOF
Usage: ./deploy.sh versions [SUBCOMMAND] [OPTIONS]

Manage and view deployment version history.

Subcommands:
  list           List all available versions (default)
  show VERSION   Display details of a specific version
  --help, -h     Show this help message

Options for 'list':
  --limit N      Show last N versions (default: 20)
  --json         Output as JSON

Options for 'show':
  --json         Output as JSON

Examples:
  ./deploy.sh versions
  ./deploy.sh versions list
  ./deploy.sh versions list --limit 50
  ./deploy.sh versions list --json
  ./deploy.sh versions show 20260501-143022
  ./deploy.sh versions show 20260501-143022 --json

EOF
}

# ============================================================================
# T048: Version List Command
# ============================================================================

versions_list_command() {
    local limit=20
    local output_json=0
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)
                limit="$2"
                shift 2
                ;;
            --json)
                output_json=1
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: ./deploy.sh versions list [OPTIONS]

List all available deployment versions in chronological order.

Options:
  --limit N      Show last N versions (default: 20)
  --json         Output as JSON array

Examples:
  ./deploy.sh versions list
  ./deploy.sh versions list --limit 50
  ./deploy.sh versions list --json

EOF
                return 0
                ;;
            *)
                error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Validate limit
    if ! [[ "$limit" =~ ^[0-9]+$ ]] || (( limit < 1 )); then
        error "Invalid limit value: $limit (must be positive integer)"
        return 1
    fi
    
    list_versions "$limit" "$output_json"
}

list_versions() {
    local limit=${1:-20}
    local output_json=${2:-0}
    
    local versions_dir=".deploy/versions"
    
    if [[ ! -d "$versions_dir" ]]; then
        if (( output_json )); then
            echo "[]"
        else
            info "No version history available"
        fi
        return 0
    fi
    
    # Find all version files and sort by modification time (newest first)
    local -a version_files=()
    while IFS= read -r -d '' file; do
        version_files+=("$file")
    done < <(find "$versions_dir" -maxdepth 1 -name "*.json" -type f -print0 | \
        xargs -0 ls -t 2>/dev/null | \
        head -"$limit" | \
        while read f; do printf '%s\0' "$f"; done)
    
    if (( ${#version_files[@]} == 0 )); then
        if (( output_json )); then
            echo "[]"
        else
            info "No version history available"
        fi
        return 0
    fi
    
    if (( output_json )); then
        # Output as JSON array
        local versions="["
        for version_file in "${version_files[@]}"; do
            local version_data=$(cat "$version_file")
            versions+="$version_data,"
        done
        versions="${versions%,}"
        versions+="]"
        echo "$versions" | jq '.'
    else
        # Output as formatted table
        echo ""
        printf "%-20s %-20s %-8s %-20s %-20s\n" "VERSION" "TIMESTAMP" "FILES" "DOMAIN" "SUBDOMAIN"
        printf "%-20s %-20s %-8s %-20s %-20s\n" "-------" "---------" "-----" "------" "---------"
        
        for version_file in "${version_files[@]}"; do
            local version_data=$(cat "$version_file")
            local version_id=$(echo "$version_data" | jq -r '.version_id // empty')
            
            if [[ -z "$version_id" ]]; then
                # Try to extract from filename
                version_id=$(basename "$version_file" .json | sed 's/^multi-//')
            fi
            
            local timestamp=$(echo "$version_data" | jq -r '.timestamp // "unknown"')
            
            # Format timestamp for display
            if [[ "$timestamp" != "unknown" ]]; then
                timestamp=$(echo "$timestamp" | cut -d'T' -f1,2)
            fi
            
            local file_count=0
            if echo "$version_data" | jq -e '.files' >/dev/null 2>&1; then
                file_count=$(echo "$version_data" | jq '.files | length // 0')
            elif echo "$version_data" | jq -e '.subdomains' >/dev/null 2>&1; then
                file_count=$(echo "$version_data" | jq '[.subdomains[] | .count] | add // 0')
            fi
            
            local domain=$(echo "$version_data" | jq -r '.domain // "unknown"')
            local subdomain=$(echo "$version_data" | jq -r '.subdomain // "multi"')
            
            printf "%-20s %-20s %-8s %-20s %-20s\n" "$version_id" "$timestamp" "$file_count" "$domain" "$subdomain"
        done
        echo ""
    fi
    
    return 0
}

# ============================================================================
# T049: Version Show Command
# ============================================================================

versions_show_command() {
    local version_id=""
    local output_json=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                output_json=1
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: ./deploy.sh versions show VERSION [OPTIONS]

Display detailed information about a specific deployment version.

Arguments:
  VERSION        Version ID to display (e.g., 20260501-143022)

Options:
  --json         Output as JSON

Examples:
  ./deploy.sh versions show 20260501-143022
  ./deploy.sh versions show 20260501-143022 --json

EOF
                return 0
                ;;
            -*)
                error "Unknown option: $1"
                return 1
                ;;
            *)
                version_id="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$version_id" ]]; then
        error "Missing version ID argument"
        error "Usage: ./deploy.sh versions show VERSION_ID"
        return 1
    fi
    
    show_version_details "$version_id" "$output_json"
}

show_version_details() {
    local version_id="$1"
    local output_json=${2:-0}
    
    local version_file=".deploy/versions/${version_id}.json"
    if [[ ! -f "$version_file" ]]; then
        version_file=".deploy/versions/multi-${version_id}.json"
    fi
    
    if [[ ! -f "$version_file" ]]; then
        error "Version not found: $version_id"
        return 1
    fi
    
    local version_data=$(cat "$version_file")
    
    if (( output_json )); then
        echo "$version_data" | jq '.'
    else
        # Format human-readable output
        echo ""
        echo "╔════════════════════════════════════════════════════════════════════════════════╗"
        echo "║ Version Details: $version_id"
        echo "╚════════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        
        # Extract basic info
        local timestamp=$(echo "$version_data" | jq -r '.timestamp // "unknown"')
        local domain=$(echo "$version_data" | jq -r '.domain // "unknown"')
        local bucket=$(echo "$version_data" | jq -r '.bucket // "unknown"')
        local created_by=$(echo "$version_data" | jq -r '.created_by // "unknown"')
        
        echo "Timestamp:  $timestamp"
        echo "Domain:     $domain"
        echo "Bucket:     $bucket"
        echo "Created by: $created_by"
        echo ""
        
        # List files in version
        if echo "$version_data" | jq -e '.files' >/dev/null 2>&1; then
            local file_count=$(echo "$version_data" | jq '.files | length')
            echo "Files ($file_count):"
            echo "───────────────────────────────────────────────────────────────────────────────"
            echo "$version_data" | jq -r '.files[]' | sort | sed 's/^/  /'
        elif echo "$version_data" | jq -e '.subdomains' >/dev/null 2>&1; then
            echo "Multi-Subdomain Files:"
            echo "───────────────────────────────────────────────────────────────────────────────"
            echo "$version_data" | jq -r '.subdomains | to_entries[] | "\n  \(.key) (\(.value.count) files):"' | sed 's/^ //'
            echo "$version_data" | jq -r '.subdomains[] | .files[]' | sort | sed 's/^/    /'
        fi
        echo ""
    fi
    
    return 0
}

# ============================================================================
# Helper: Get All Versions as Array
# ============================================================================

get_all_versions() {
    local versions_dir=".deploy/versions"
    local -a versions=()
    
    if [[ ! -d "$versions_dir" ]]; then
        return 0
    fi
    
    while IFS= read -r -d '' file; do
        local version_id=$(basename "$file" .json | sed 's/^multi-//')
        versions+=("$version_id")
    done < <(find "$versions_dir" -maxdepth 1 -name "*.json" -type f -print0 | \
        xargs -0 ls -t 2>/dev/null | \
        while read f; do printf '%s\0' "$f"; done)
    
    printf '%s\n' "${versions[@]}"
}

# ============================================================================
# Helper: Get Latest Version
# ============================================================================

get_latest_version() {
    local versions_dir=".deploy/versions"
    
    if [[ ! -d "$versions_dir" ]]; then
        return 1
    fi
    
    local latest=$(ls -t "$versions_dir"/*.json 2>/dev/null | head -1)
    
    if [[ -z "$latest" ]]; then
        return 1
    fi
    
    basename "$latest" .json | sed 's/^multi-//'
}

# ============================================================================
# Helper: Get Version Count
# ============================================================================

get_version_count() {
    local versions_dir=".deploy/versions"
    
    if [[ ! -d "$versions_dir" ]]; then
        echo 0
        return 0
    fi
    
    local count=$(find "$versions_dir" -maxdepth 1 -name "*.json" -type f | wc -l)
    echo "$count"
}

export -f versions_command
export -f versions_list_command
export -f versions_show_command
export -f list_versions
export -f show_version_details
export -f get_all_versions
export -f get_latest_version
export -f get_version_count
