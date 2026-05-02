#!/bin/bash

# AWS CloudFront API wrapper functions (T008)
# Provides: Distribution management, cache invalidation, invalidation polling

# Get CloudFront distribution
cf_get_distribution() {
    local distribution_id="$1"
    local aws_profile="${2:-${AWS_PROFILE:-default}}"
    
    aws cloudfront get-distribution \
        --id "$distribution_id" \
        --profile "$aws_profile" \
        --output json 2>/dev/null
}

# Get CloudFront distribution ID by domain name
cf_get_distribution_id_by_domain() {
    local domain_name="$1"
    local aws_profile="${2:-${AWS_PROFILE:-default}}"
    
    aws cloudfront list-distributions \
        --profile "$aws_profile" \
        --output json 2>/dev/null | \
        jq -r ".DistributionList.Items[] | select(.DomainName==\"$domain_name\") | .Id" | \
        head -1
}

# Create CloudFront invalidation for given paths
cf_create_invalidation() {
    local distribution_id="$1"
    local paths_json="$2"  # JSON array: ["/index.html", "/css/*", "/*"]
    local aws_profile="${3:-${AWS_PROFILE:-default}}"
    
    debug "Creating CloudFront invalidation for distribution: $distribution_id"
    debug "Paths: $paths_json"
    
    local invalidation_id
    invalidation_id=$(aws cloudfront create-invalidation \
        --distribution-id "$distribution_id" \
        --invalidation-batch "Paths={Quantity=$(echo "$paths_json" | jq 'length'),Items=$paths_json},CallerReference=$(date +%s)" \
        --profile "$aws_profile" \
        --query 'Invalidation.Id' \
        --output text 2>/dev/null)
    
    if [[ -z "$invalidation_id" ]]; then
        error "Failed to create CloudFront invalidation"
        return $EXIT_AWS_ERROR
    fi
    
    echo "$invalidation_id"
    return $EXIT_SUCCESS
}

# Get CloudFront invalidation status
cf_describe_invalidation() {
    local distribution_id="$1"
    local invalidation_id="$2"
    local aws_profile="${3:-${AWS_PROFILE:-default}}"
    
    aws cloudfront get-invalidation \
        --distribution-id "$distribution_id" \
        --id "$invalidation_id" \
        --profile "$aws_profile" \
        --output json 2>/dev/null
}

# Get invalidation status (Pending or Completed)
cf_get_invalidation_status() {
    local distribution_id="$1"
    local invalidation_id="$2"
    local aws_profile="${3:-${AWS_PROFILE:-default}}"
    
    aws cloudfront get-invalidation \
        --distribution-id "$distribution_id" \
        --id "$invalidation_id" \
        --profile "$aws_profile" \
        --query 'Invalidation.Status' \
        --output text 2>/dev/null
}

# Poll CloudFront invalidation completion
cf_poll_invalidation() {
    local distribution_id="$1"
    local invalidation_id="$2"
    local max_wait_seconds="${3:-300}"  # Default: 5 minutes
    local aws_profile="${4:-${AWS_PROFILE:-default}}"
    
    local elapsed=0
    local poll_interval=10
    
    debug "Polling CloudFront invalidation: $invalidation_id"
    
    while [[ $elapsed -lt $max_wait_seconds ]]; do
        local status
        status=$(cf_get_invalidation_status "$distribution_id" "$invalidation_id" "$aws_profile")
        
        case "$status" in
            Pending)
                info "CloudFront invalidation pending... ($elapsed seconds)"
                sleep $poll_interval
                ((elapsed += poll_interval))
                ;;
            
            Completed)
                success "CloudFront cache invalidation completed"
                return $EXIT_SUCCESS
                ;;
            
            *)
                error "Unknown invalidation status: $status"
                return $EXIT_AWS_ERROR
                ;;
        esac
    done
    
    warn "CloudFront invalidation timed out (but may complete later)"
    return $EXIT_SUCCESS  # Don't fail deployment, cache will eventually expire
}

# List CloudFront distributions
cf_list_distributions() {
    local aws_profile="${1:-${AWS_PROFILE:-default}}"
    
    aws cloudfront list-distributions \
        --profile "$aws_profile" \
        --output json 2>/dev/null
}

# Invalidate all CloudFront cache (/*) - useful for full refresh
cf_invalidate_all() {
    local distribution_id="$1"
    local aws_profile="${2:-${AWS_PROFILE:-default}}"
    
    debug "Invalidating all CloudFront cache for distribution: $distribution_id"
    
    cf_create_invalidation "$distribution_id" '["/*"]' "$aws_profile"
}

# Optimize invalidation paths: use /* if many files, else list specific paths
cf_optimize_invalidation_paths() {
    local -a paths=("$@")
    local path_count=${#paths[@]}
    
    if [[ $path_count -gt 100 ]]; then
        # Use wildcard for >100 paths
        echo '["/*"]'
    else
        # List specific paths
        jq -n --args '[$ARGS.positional]' "${paths[@]}"
    fi
}

export -f cf_get_distribution cf_get_distribution_id_by_domain
export -f cf_create_invalidation cf_describe_invalidation cf_get_invalidation_status
export -f cf_poll_invalidation cf_list_distributions cf_invalidate_all
export -f cf_optimize_invalidation_paths
