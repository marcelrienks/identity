#!/bin/bash

# State tracking system (T013)
# Provides: Deployment state persistence, stack metadata tracking, deployment logs

# Save deployment state to .deploy/state.json
save_deployment_state() {
    local domain="$1"
    local subdomain="$2"
    local region="$3"
    local stack_id="$4"
    local s3_bucket="$5"
    local cf_distribution="$6"
    local cf_domain="$7"
    local version_id="$8"
    local state_file="${9:-.deploy/state.json}"
    
    debug "Saving deployment state to: $state_file"
    
    mkdir -p "$(dirname "$state_file")"
    
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    
    local state_json
    read -r -d '' state_json << EOF || true
{
    "domain": "$domain",
    "subdomain": "$subdomain",
    "region": "$region",
    "stack_id": "$stack_id",
    "s3_bucket": "$s3_bucket",
    "cf_distribution": "$cf_distribution",
    "cf_domain": "$cf_domain",
    "current_version": "$version_id",
    "last_deployed": "$timestamp"
}
EOF
    
    echo "$state_json" | jq . > "$state_file"
    debug "Deployment state saved"
    return $EXIT_SUCCESS
}

# Load deployment state from .deploy/state.json
load_deployment_state() {
    local state_file="${1:-.deploy/state.json}"
    
    if [[ ! -f "$state_file" ]]; then
        debug "No deployment state file found: $state_file"
        return $EXIT_ERROR
    fi
    
    debug "Loading deployment state from: $state_file"
    
    cat "$state_file"
    return $EXIT_SUCCESS
}

# Get specific state value
get_deployment_state_value() {
    local key="$1"
    local state_file="${2:-.deploy/state.json}"
    
    if [[ ! -f "$state_file" ]]; then
        return $EXIT_ERROR
    fi
    
    jq -r ".$key" "$state_file" 2>/dev/null
}

# Create deployment log entry
create_deployment_log_entry() {
    local operation="$1"  # deploy, update, rollback
    local status="$2"     # success, failure
    local details="$3"    # Additional details
    local log_dir="${4:-.deploy/deployments}"
    
    mkdir -p "$log_dir"
    
    local log_file="$log_dir/$(date +%Y-%m-%d).log"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%d %H:%M:%S')
    
    cat >> "$log_file" << EOF
[${timestamp}] $operation - $status
  Details: $details
---
EOF
    
    debug "Deployment log entry created: $log_file"
}

# Append to deployment record
append_deployment_record() {
    local message="$1"
    local record_file="${2:-.deploy/deployment-record.txt}"
    
    mkdir -p "$(dirname "$record_file")"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$record_file"
}

# Get deployment history
get_deployment_history() {
    local log_dir="${1:-.deploy/deployments}"
    local limit="${2:-10}"
    
    if [[ ! -d "$log_dir" ]]; then
        info "No deployment history available"
        return $EXIT_SUCCESS
    fi
    
    section "Deployment History (last $limit)"
    
    # Show recent log entries
    tail -n "$((limit * 3))" "$log_dir"/*.log 2>/dev/null || info "No logs found"
}

# Print deployment summary
print_deployment_summary() {
    local domain="$1"
    local subdomain="$2"
    local stack_name="$3"
    local stack_id="$4"
    local s3_bucket="$5"
    local cf_domain="$6"
    local cf_distribution="$7"
    local version_id="$8"
    local file_count="$9"
    local duration="${10:-0}"
    
    section "Deployment Complete"
    
    cat << EOF

✓ Infrastructure Deployment Complete

  Stack Name:        $stack_name
  Stack ID:          $stack_id
  
  Domain:            $domain
  Subdomain:         $subdomain
  CloudFront Domain: $cf_domain
  CloudFront ID:     $cf_distribution
  
  S3 Bucket:         $s3_bucket
  Files Deployed:    $file_count
  Version ID:        $version_id
  
  Deployment Time:   ${duration}s
  
Access your website at:
  https://${subdomain}.${domain} or https://${domain}

EOF
}

# Print update summary
print_update_summary() {
    local domain="$1"
    local subdomain="$2"
    local files_uploaded="$3"
    local version_id="$4"
    local previous_version="$5"
    local duration="${6:-0}"
    
    section "Content Update Complete"
    
    cat << EOF

✓ Content Update Complete

  Domain:            ${subdomain}.${domain}
  Files Uploaded:    $files_uploaded
  Version ID:        $version_id (previous: $previous_version)
  
  Update Time:       ${duration}s
  Cache Status:      Invalidating (changes live in 1-2 minutes)

EOF
}

export -f save_deployment_state load_deployment_state get_deployment_state_value
export -f create_deployment_log_entry append_deployment_record get_deployment_history
export -f print_deployment_summary print_update_summary
