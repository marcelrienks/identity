#!/bin/bash

# Version snapshot and manifest system (T011)
# Provides: Version manifest creation, storage, retrieval, version history

# Generate version ID (timestamp-based: YYYYMMDD-HHMMSS)
generate_version_id() {
    date '+%Y%m%d-%H%M%S'
}

# Create version manifest file
create_version_manifest() {
    local version_id="$1"
    local domain="$2"
    local subdomain="$3"
    local source_dir="${4:-.}"
    local output_file="$5"
    
    debug "Creating version manifest: $version_id"
    
    local -a files=()
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    
    # Build files array with metadata
    local files_json="["
    local first=1
    
    while IFS= read -r file; do
        local rel_path
        rel_path=$(get_relative_path "$file" "$source_dir")
        
        local hash
        hash=$(file_hash "$file")
        
        local size
        size=$(file_size "$file")
        
        if [[ $first -eq 1 ]]; then
            first=0
        else
            files_json+=","
        fi
        
        files_json+=$(cat <<EOF
        {
            "path": "$rel_path",
            "hash": "$hash",
            "size": $size
        }
EOF
)
    done < <(find_files_to_upload "$source_dir")
    
    files_json+="]"
    
    # Create manifest JSON
    local manifest
    read -r -d '' manifest << EOF || true
{
    "version_id": "$version_id",
    "timestamp": "$timestamp",
    "domain": "$domain",
    "subdomain": "$subdomain",
    "file_count": $(echo "$files_json" | jq 'length'),
    "files": $files_json
}
EOF
    
    # Write to output file if specified
    if [[ -n "$output_file" ]]; then
        mkdir -p "$(dirname "$output_file")"
        echo "$manifest" | jq . > "$output_file"
        debug "Manifest written to: $output_file"
    else
        echo "$manifest"
    fi
}

# Store version manifest to S3 and local
store_version_manifest() {
    local version_manifest_json="$1"
    local bucket_name="$2"
    local local_versions_dir="${3:-.deploy/versions}"
    local aws_profile="${4:-${AWS_PROFILE:-default}}"
    
    # Extract version_id from manifest
    local version_id
    version_id=$(echo "$version_manifest_json" | jq -r '.version_id')
    
    debug "Storing version manifest: $version_id"
    
    # Store locally
    mkdir -p "$local_versions_dir"
    local local_manifest_file="$local_versions_dir/$version_id.json"
    echo "$version_manifest_json" | jq . > "$local_manifest_file"
    debug "Local manifest: $local_manifest_file"
    
    # Store in S3
    local s3_key="versions/$version_id.json"
    if ! s3_upload_object "$local_manifest_file" "$bucket_name" "$s3_key" "$aws_profile"; then
        warn "Failed to store version manifest in S3 (will continue)"
    fi
    
    return $EXIT_SUCCESS
}

# List all versions (for deployment history)
list_versions() {
    local local_versions_dir="${1:-.deploy/versions}"
    local limit="${2:-20}"
    
    section "Available versions"
    
    if [[ ! -d "$local_versions_dir" ]]; then
        info "No versions found"
        return $EXIT_SUCCESS
    fi
    
    # List versions sorted by name (which is YYYYMMDD-HHMMSS, so chronological)
    local count=0
    ls -1r "$local_versions_dir"/*.json 2>/dev/null | while IFS= read -r manifest_file; do
        if [[ $count -ge $limit ]]; then
            break
        fi
        
        local version_id
        version_id=$(basename "$manifest_file" .json)
        
        local file_count
        file_count=$(jq '.file_count' "$manifest_file" 2>/dev/null || echo "?")
        
        local timestamp
        timestamp=$(jq -r '.timestamp' "$manifest_file" 2>/dev/null || echo "?")
        
        printf "  %-20s %5s files    %s\n" "$version_id" "$file_count" "$timestamp"
        
        ((count++))
    done
}

# Get specific version manifest
get_version_manifest() {
    local version_id="$1"
    local local_versions_dir="${2:-.deploy/versions}"
    
    local manifest_file="$local_versions_dir/$version_id.json"
    
    if [[ ! -f "$manifest_file" ]]; then
        error "Version not found: $version_id"
        return $EXIT_ERROR
    fi
    
    cat "$manifest_file"
}

# Get latest version ID
get_latest_version_id() {
    local local_versions_dir="${1:-.deploy/versions}"
    
    if [[ ! -d "$local_versions_dir" ]]; then
        return $EXIT_ERROR
    fi
    
    # Get latest by sorting (YYYYMMDD-HHMMSS format sorts chronologically)
    ls -1r "$local_versions_dir"/*.json 2>/dev/null | head -1 | xargs basename -s .json
}

# Get previous version ID
get_previous_version_id() {
    local local_versions_dir="${1:-.deploy/versions}"
    
    if [[ ! -d "$local_versions_dir" ]]; then
        return $EXIT_ERROR
    fi
    
    # Get second-latest
    ls -1r "$local_versions_dir"/*.json 2>/dev/null | sed -n '2p' | xargs basename -s .json
}

export -f generate_version_id create_version_manifest store_version_manifest
export -f list_versions get_version_manifest get_latest_version_id get_previous_version_id
