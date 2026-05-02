#!/bin/bash

# File operations and discovery (T010)
# Provides: File discovery, pattern matching, inventory generation, hashing

# Find files to upload with include/exclude patterns (T010)
find_files_to_upload() {
    local source_dir="${1:-.}"
    local aws_profile="${2:-${AWS_PROFILE:-default}}"
    
    # Default include patterns
    local -a include_patterns=(
        "*.html"
        "*.css"
        "*.js"
        "*.json"
        "*.jpg"
        "*.jpeg"
        "*.png"
        "*.svg"
        "*.webp"
        "*.gif"
        "*.ico"
        "*.woff"
        "*.woff2"
        "*.ttf"
        "*.otf"
    )
    
    # Default exclude patterns
    local -a exclude_patterns=(
        "node_modules"
        ".git"
        ".DS_Store"
        "*.tmp"
        ".env*"
        ".aws"
        ".deploy"
        "logs"
        "tests"
        "*.md"
    )
    
    # Read from config if available
    if has_config "INCLUDE_PATTERNS"; then
        include_patterns=()
        # Parse comma-separated patterns
        readarray -t include_patterns < <(echo "${CONFIG[INCLUDE_PATTERNS]}" | tr ',' '\n')
    fi
    
    if has_config "EXCLUDE_PATTERNS"; then
        exclude_patterns=()
        readarray -t exclude_patterns < <(echo "${CONFIG[EXCLUDE_PATTERNS]}" | tr ',' '\n')
    fi
    
    debug "Include patterns: ${include_patterns[*]}"
    debug "Exclude patterns: ${exclude_patterns[*]}"
    
    # Find files matching include patterns, excluding excluded patterns
    local -a find_args=("$source_dir" "-type" "f")
    
    # Build find command with OR conditions for includes
    local -a include_expr=()
    for pattern in "${include_patterns[@]}"; do
        include_expr+=("-o" "-name" "$pattern")
    done
    
    # Build find command with AND conditions for excludes
    local -a exclude_expr=("-not" "-path" "*/.*")  # Exclude hidden files by default
    for pattern in "${exclude_patterns[@]}"; do
        exclude_expr+=("-not" "-path" "*/$pattern*")
        exclude_expr+=("-not" "-name" "$pattern*")
    done
    
    # Execute find
    find "${find_args[@]}" \( "${include_expr[@]:1}" \) "${exclude_expr[@]}" -print 2>/dev/null | sort
}

# Generate file inventory with metadata
generate_file_inventory() {
    local source_dir="${1:-.}"
    
    section "Generating file inventory"
    
    local -a files=()
    local total_size=0
    
    # Find all files to upload
    while IFS= read -r file; do
        local rel_path="${file#$source_dir/}"
        [[ "$rel_path" == "$file" ]] && rel_path="$file"
        
        local size
        size=$(file_size "$file")
        
        local hash
        hash=$(file_hash "$file")
        
        files+=("$file")
        total_size=$((total_size + size))
        
        debug "  $(printf '%-50s' "$rel_path") $(printf '%10s' "$size") bytes"
    done < <(find_files_to_upload "$source_dir")
    
    info "Found ${#files[@]} files to deploy ($(printf "%.1f" $(echo "scale=2; $total_size / 1024 / 1024" | bc)) MB)"
    
    # Return files array (as associative array would be complex)
    printf '%s\n' "${files[@]}"
}

# Count files to upload (for dry-run)
count_files_to_upload() {
    local source_dir="${1:-.}"
    
    find_files_to_upload "$source_dir" | wc -l
}

# Calculate total size of files to upload
calculate_total_upload_size() {
    local source_dir="${1:-.}"
    
    local total=0
    while IFS= read -r file; do
        total=$((total + $(file_size "$file")))
    done < <(find_files_to_upload "$source_dir")
    
    echo "$total"
}

# Format bytes as human-readable string
format_bytes() {
    local bytes="$1"
    
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt 1048576 ]]; then
        printf "%.1f KB" "$(echo "scale=1; $bytes / 1024" | bc)"
    elif [[ $bytes -lt 1073741824 ]]; then
        printf "%.1f MB" "$(echo "scale=1; $bytes / 1024 / 1024" | bc)"
    else
        printf "%.1f GB" "$(echo "scale=1; $bytes / 1024 / 1024 / 1024" | bc)"
    fi
}

# Get relative path of file within source directory
get_relative_path() {
    local file="$1"
    local source_dir="${2:-.}"
    
    # Handle absolute vs relative paths
    if [[ "$file" =~ ^/ ]]; then
        # Absolute path
        echo "${file#$source_dir/}"
    else
        # Relative path
        echo "${file#./}"
    fi
}

export -f find_files_to_upload generate_file_inventory count_files_to_upload
export -f calculate_total_upload_size format_bytes get_relative_path
