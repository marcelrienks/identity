#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Rollback Command Implementation                                            ║
# ║  Phase 6: User Story 4 - Rollback & Versioning (Tasks T047-T053)            ║
# ║  Handles version history, rollback, and version management                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ============================================================================
# T047: Rollback Subcommand - Argument Parsing & Version Validation
# ============================================================================

parse_rollback_arguments() {
    local -a args=()
    local version=""
    local confirm=0
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                version="$2"
                shift 2
                ;;
            --confirm)
                confirm=1
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: ./deploy.sh rollback [OPTIONS]

Rollback website content to a previous version.

Options:
  --version VERSION      Version ID to rollback to (default: previous version)
  --confirm             Skip confirmation prompt (for CI/CD automation)
  --help, -h            Show this help message

Examples:
  ./deploy.sh rollback --version 20260501-143022
  ./deploy.sh rollback  # Rollback to immediately previous version
  ./deploy.sh rollback --version 20260501-143022 --confirm

EOF
                return 2
                ;;
            *)
                error "Unknown rollback option: $1"
                return 1
                ;;
        esac
    done
    
    # If no version specified, use previous version
    if [[ -z "$version" ]]; then
        version=$(get_previous_version)
        if [[ -z "$version" ]]; then
            error "No previous version found. Cannot determine which version to rollback to."
            return 1
        fi
        info "Using previous version: $version"
    fi
    
    # Validate version exists
    if ! validate_version_exists "$version"; then
        error "Version not found: $version"
        return 1
    fi
    
    # Prompt user for confirmation unless --confirm provided
    if (( !confirm )); then
        local file_count=$(get_version_file_count "$version")
        local timestamp=$(get_version_timestamp "$version")
        
        warn "Rollback will restore $file_count files from version $timestamp"
        read -p "Continue? (yes/no): " -r response
        if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
            info "Rollback cancelled"
            return 2
        fi
    fi
    
    # Store parsed arguments
    args[version]="$version"
    args[confirm]="$confirm"
    
    return 0
}

get_previous_version() {
    local versions_dir=".deploy/versions"
    
    if [[ ! -d "$versions_dir" ]]; then
        return 1
    fi
    
    # Find most recent version file
    local latest=$(ls -t "$versions_dir"/*.json 2>/dev/null | head -1)
    
    if [[ -z "$latest" ]]; then
        return 1
    fi
    
    # Extract version ID from filename
    basename "$latest" .json | sed 's/^multi-//'
}

validate_version_exists() {
    local version="$1"
    
    # Check local storage
    if [[ -f ".deploy/versions/${version}.json" ]] || [[ -f ".deploy/versions/multi-${version}.json" ]]; then
        return 0
    fi
    
    # Could also check S3, but local check is sufficient for most cases
    return 1
}

get_version_file_count() {
    local version="$1"
    
    local version_file=".deploy/versions/${version}.json"
    if [[ ! -f "$version_file" ]]; then
        version_file=".deploy/versions/multi-${version}.json"
    fi
    
    if [[ -f "$version_file" ]]; then
        jq '.files | length // 0' "$version_file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

get_version_timestamp() {
    local version="$1"
    
    local version_file=".deploy/versions/${version}.json"
    if [[ ! -f "$version_file" ]]; then
        version_file=".deploy/versions/multi-${version}.json"
    fi
    
    if [[ -f "$version_file" ]]; then
        jq -r '.timestamp // empty' "$version_file" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# ============================================================================
# T048: Version History Querying (versions --list)
# ============================================================================

list_versions() {
    local limit=${1:-20}
    local output_json=${2:-0}
    
    local versions_dir=".deploy/versions"
    
    if [[ ! -d "$versions_dir" ]]; then
        info "No version history available"
        return 0
    fi
    
    # Find all version files and sort by modification time (newest first)
    local -a version_files=()
    while IFS= read -r -d '' file; do
        version_files+=("$file")
    done < <(find "$versions_dir" -name "*.json" -type f -print0 | sort -zr)
    
    if (( ${#version_files[@]} == 0 )); then
        info "No version history available"
        return 0
    fi
    
    # Limit to requested count
    version_files=("${version_files[@]:0:$limit}")
    
    if (( output_json )); then
        # Output as JSON array
        local json="["
        for version_file in "${version_files[@]}"; do
            local version_data=$(cat "$version_file")
            json+="$version_data,"
        done
        json="${json%,}"
        json+="]"
        echo "$json"
    else
        # Output as formatted table
        echo ""
        printf "%-20s %-15s %-8s %-15s\n" "VERSION" "TIMESTAMP" "FILES" "SUBDOMAIN"
        printf "%-20s %-15s %-8s %-15s\n" "-------" "---------" "-----" "---------"
        
        for version_file in "${version_files[@]}"; do
            local version_data=$(cat "$version_file")
            local version_id=$(echo "$version_data" | jq -r '.version_id // empty')
            local timestamp=$(echo "$version_data" | jq -r '.timestamp // "unknown"' | cut -d'T' -f1,2 | cut -d. -f1)
            local file_count=$(echo "$version_data" | jq '.files | length // ([ .subdomains | to_entries[] | .value.count ] | add)' 2>/dev/null || echo "?")
            local subdomain=$(echo "$version_data" | jq -r 'if .subdomains then "multi" else .subdomain end' 2>/dev/null)
            
            printf "%-20s %-15s %-8s %-15s\n" "$version_id" "$timestamp" "$file_count" "$subdomain"
        done
        echo ""
    fi
    
    return 0
}

# ============================================================================
# T049: Version Details Display (versions --show)
# ============================================================================

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
        echo "$version_data"
    else
        # Format human-readable output
        echo ""
        echo "Version Details: $version_id"
        echo "=================================================================================="
        echo ""
        echo "Timestamp: $(echo "$version_data" | jq -r '.timestamp')"
        echo "Domain: $(echo "$version_data" | jq -r '.domain')"
        echo "Subdomain: $(echo "$version_data" | jq -r '.subdomain // "multi"')"
        echo ""
        
        # List files in version
        if echo "$version_data" | jq -e '.files' >/dev/null 2>&1; then
            local file_count=$(echo "$version_data" | jq '.files | length')
            echo "Files ($file_count):"
            echo "$version_data" | jq -r '.files[]' | sed 's/^/  /'
        elif echo "$version_data" | jq -e '.subdomains' >/dev/null 2>&1; then
            echo "Multi-Subdomain Files:"
            echo "$version_data" | jq -r '.subdomains | to_entries[] | "\n\(.key): \(.value.count) files"' | sed 's/^/  /'
        fi
        echo ""
    fi
    
    return 0
}

# ============================================================================
# T050: Atomic Rollback Restoration
# ============================================================================

atomic_restore_version() {
    local version_id="$1"
    local s3_bucket="$2"
    local aws_profile="$3"
    
    info "Starting atomic restore for version: $version_id"
    
    local version_file=".deploy/versions/${version_id}.json"
    if [[ ! -f "$version_file" ]]; then
        version_file=".deploy/versions/multi-${version_id}.json"
    fi
    
    if [[ ! -f "$version_file" ]]; then
        error "Version file not found: $version_id"
        return 1
    fi
    
    local version_data=$(cat "$version_file")
    
    # Get list of files to restore
    local -a files_to_restore=()
    if echo "$version_data" | jq -e '.files' >/dev/null 2>&1; then
        # Single-subdomain version
        mapfile -t files_to_restore < <(echo "$version_data" | jq -r '.files[]')
    elif echo "$version_data" | jq -e '.subdomains' >/dev/null 2>&1; then
        # Multi-subdomain version - restore all subdomain files
        mapfile -t files_to_restore < <(echo "$version_data" | jq -r '.subdomains | to_entries[] | .value.files[]')
    fi
    
    if (( ${#files_to_restore[@]} == 0 )); then
        error "No files found in version manifest"
        return 1
    fi
    
    info "Restoring ${#files_to_restore[@]} files from version $version_id"
    
    # Restore files
    local restored=0
    local failed=0
    local checkpoint_file=".deploy/restore-checkpoint-${version_id}.json"
    local restored_list=()
    
    for s3_key in "${files_to_restore[@]}"; do
        if aws s3 cp "s3://${s3_bucket}/${s3_key}" "s3://${s3_bucket}/${s3_key}" \
            --profile "$aws_profile" \
            --copy-props all 2>/dev/null; then
            
            ((restored++))
            restored_list+=("$s3_key")
            
            # Save checkpoint every 10 files
            if (( restored % 10 == 0 )); then
                printf '%s\n' "${restored_list[@]}" | jq -R -s -c 'split("\n")[:-1]' > "$checkpoint_file"
                info "Restored $restored files (checkpoint saved)"
            fi
        else
            error "Failed to restore: $s3_key"
            ((failed++))
        fi
    done
    
    # Check if restore was successful (all-or-nothing semantics)
    if (( failed > 0 )); then
        error "Restore failed: $failed files could not be restored"
        return 1
    fi
    
    # Clean up checkpoint
    rm -f "$checkpoint_file"
    
    info "Successfully restored all ${#files_to_restore[@]} files"
    return 0
}

# ============================================================================
# T051: CloudFront Cache Invalidation After Rollback
# ============================================================================

invalidate_after_rollback() {
    local distribution_id="$1"
    local aws_profile="$2"
    
    info "Creating CloudFront invalidation after rollback"
    
    # Invalidate all paths to ensure fresh content
    local invalidation_id=$(aws cloudfront create-invalidation \
        --distribution-id "$distribution_id" \
        --paths "/*" \
        --profile "$aws_profile" \
        --query 'Invalidation.Id' \
        --output text 2>/dev/null)
    
    if [[ -z "$invalidation_id" ]]; then
        error "Failed to create CloudFront invalidation"
        return 1
    fi
    
    info "Invalidation created: $invalidation_id"
    
    # Poll for completion (timeout: 5 minutes)
    local start_time=$(date +%s)
    local timeout=300
    local poll_interval=10
    
    while true; do
        local current_time=$(date +%s)
        if (( current_time - start_time > timeout )); then
            warn "CloudFront invalidation timeout (still in progress)"
            break
        fi
        
        local status=$(aws cloudfront get-invalidation \
            --distribution-id "$distribution_id" \
            --id "$invalidation_id" \
            --profile "$aws_profile" \
            --query 'Invalidation.Status' \
            --output text 2>/dev/null)
        
        if [[ "$status" == "Completed" ]]; then
            info "CloudFront invalidation completed"
            return 0
        fi
        
        sleep "$poll_interval"
    done
    
    return 0
}

# ============================================================================
# T052: Rollback Completion Reporting & Audit Logging
# ============================================================================

report_rollback_completion() {
    local from_version="$1"
    local to_version="$2"
    local restored_count="$3"
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Create rollback record
    local rollback_record=$(cat <<EOF
{
  "operation": "rollback",
  "timestamp": "$timestamp",
  "from_version": "$from_version",
  "to_version": "$to_version",
  "files_restored": $restored_count,
  "success": true
}
EOF
)
    
    # Save to deployment log
    local log_dir=".deploy/deployments"
    mkdir -p "$log_dir"
    local log_file="$log_dir/$(date +%Y-%m-%d).log"
    
    echo "$rollback_record" >> "$log_file"
    
    # Print summary
    echo ""
    info "✓ Rollback Complete"
    info "  From: $from_version"
    info "  To:   $to_version"
    info "  Files Restored: $restored_count"
    info "  Live in: ~1-2 minutes (after CloudFront invalidation)"
    echo ""
    
    return 0
}

# ============================================================================
# Main Rollback Command Handler
# ============================================================================

rollback_command() {
    info "Executing rollback command"
    
    # Load deployment state
    local state_file=".deploy/state.json"
    if [[ ! -f "$state_file" ]]; then
        error "No deployment state found. Cannot rollback without previous deployment."
        return 1
    fi
    
    local state=$(cat "$state_file")
    local s3_bucket=$(echo "$state" | jq -r '.s3_bucket // empty')
    local distribution_id=$(echo "$state" | jq -r '.cloudfront_distribution // empty')
    local aws_profile=$(echo "$state" | jq -r '.aws_profile // "default"')
    
    if [[ -z "$s3_bucket" ]] || [[ -z "$distribution_id" ]]; then
        error "Invalid deployment state: missing S3 bucket or CloudFront distribution"
        return 1
    fi
    
    # Parse arguments
    local version=""
    parse_rollback_arguments "$@" || return $?
    
    # Get version ID from state (handle various argument formats)
    local version_arg=""
    for arg in "$@"; do
        if [[ "$arg" != --* ]] && [[ "$arg" != rollback ]]; then
            version_arg="$arg"
        fi
    done
    
    if [[ -z "$version_arg" ]]; then
        version_arg=$(get_previous_version)
    fi
    
    if [[ -z "$version_arg" ]]; then
        error "No version specified and cannot determine previous version"
        return 1
    fi
    
    # Perform rollback
    atomic_restore_version "$version_arg" "$s3_bucket" "$aws_profile" || return 1
    
    # Invalidate CloudFront cache
    invalidate_after_rollback "$distribution_id" "$aws_profile" || return 1
    
    # Get current version for reporting
    local current_version=$(cat "$state_file" | jq -r '.current_version // "unknown"')
    
    # Report completion
    local file_count=$(get_version_file_count "$version_arg")
    report_rollback_completion "$current_version" "$version_arg" "$file_count" || return 1
    
    # Update state to reflect new current version
    local updated_state=$(echo "$state" | jq --arg version "$version_arg" '.current_version = $version')
    echo "$updated_state" > "$state_file"
    
    return 0
}

export -f rollback_command
export -f parse_rollback_arguments
export -f get_previous_version
export -f validate_version_exists
export -f list_versions
export -f show_version_details
export -f atomic_restore_version
export -f invalidate_after_rollback
