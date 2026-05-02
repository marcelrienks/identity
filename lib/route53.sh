#!/bin/bash

# AWS Route 53 API wrapper functions (T009)
# Provides: Hosted zone management, DNS record operations, propagation checking

# Check if Route 53 hosted zone exists
r53_zone_exists() {
    local domain_name="$1"
    local aws_profile="${2:-${AWS_PROFILE:-default}}"
    
    # Ensure domain ends with dot for Route 53
    [[ ! "$domain_name" =~ \.$ ]] && domain_name="${domain_name}."
    
    aws route53 list-hosted-zones-by-name \
        --dns-name "$domain_name" \
        --profile "$aws_profile" \
        --query "HostedZones[?Name=='$domain_name']|[0].Id" \
        --output text 2>/dev/null | grep -q .
}

# Get Route 53 hosted zone ID for domain
r53_get_zone_id() {
    local domain_name="$1"
    local aws_profile="${2:-${AWS_PROFILE:-default}}"
    
    # Ensure domain ends with dot for Route 53
    [[ ! "$domain_name" =~ \.$ ]] && domain_name="${domain_name}."
    
    local zone_id
    zone_id=$(aws route53 list-hosted-zones-by-name \
        --dns-name "$domain_name" \
        --profile "$aws_profile" \
        --query "HostedZones[?Name=='$domain_name']|[0].Id" \
        --output text 2>/dev/null)
    
    # Remove /hostedzone/ prefix if present
    zone_id="${zone_id##*/}"
    
    if [[ -z "$zone_id" || "$zone_id" == "None" ]]; then
        return $EXIT_ERROR
    fi
    
    echo "$zone_id"
    return $EXIT_SUCCESS
}

# List all Route 53 hosted zones
r53_list_zones() {
    local aws_profile="${1:-${AWS_PROFILE:-default}}"
    
    aws route53 list-hosted-zones \
        --profile "$aws_profile" \
        --output json 2>/dev/null
}

# Create alias record in Route 53
r53_create_alias_record() {
    local zone_id="$1"
    local record_name="$2"  # e.g., www.example.com or example.com
    local alias_target="$3"  # e.g., d123abc.cloudfront.net (CloudFront domain)
    local alias_hosted_zone="$4"  # CloudFront hosted zone ID
    local aws_profile="${5:-${AWS_PROFILE:-default}}"
    
    debug "Creating Route 53 alias record: $record_name → $alias_target"
    
    # Ensure record name ends with dot
    [[ ! "$record_name" =~ \.$ ]] && record_name="${record_name}."
    
    # Ensure alias target ends with dot
    [[ ! "$alias_target" =~ \.$ ]] && alias_target="${alias_target}."
    
    # CloudFront hosted zone ID (always Z2FDTNDATAQYW2)
    alias_hosted_zone="${alias_hosted_zone:-Z2FDTNDATAQYW2}"
    
    # Create change batch JSON
    local change_batch
    read -r -d '' change_batch << EOF || true
{
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "$record_name",
            "Type": "A",
            "AliasTarget": {
                "HostedZoneId": "$alias_hosted_zone",
                "DNSName": "$alias_target",
                "EvaluateTargetHealth": false
            }
        }
    }]
}
EOF
    
    if ! aws route53 change-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --change-batch "$change_batch" \
        --profile "$aws_profile" \
        --output json 2>/dev/null > /dev/null; then
        
        error "Failed to create Route 53 alias record: $record_name"
        return $EXIT_AWS_ERROR
    fi
    
    success "Route 53 alias record created: $record_name → $alias_target"
    return $EXIT_SUCCESS
}

# List all records in hosted zone
r53_list_records() {
    local zone_id="$1"
    local aws_profile="${2:-${AWS_PROFILE:-default}}"
    
    aws route53 list-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --profile "$aws_profile" \
        --output json 2>/dev/null
}

# Get specific record from hosted zone
r53_get_record() {
    local zone_id="$1"
    local record_name="$2"
    local record_type="${3:-A}"
    local aws_profile="${4:-${AWS_PROFILE:-default}}"
    
    # Ensure record name ends with dot
    [[ ! "$record_name" =~ \.$ ]] && record_name="${record_name}."
    
    aws route53 list-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --profile "$aws_profile" \
        --query "ResourceRecordSets[?Name=='$record_name' && Type=='$record_type']|[0]" \
        --output json 2>/dev/null
}

# Delete DNS record from Route 53
r53_delete_record() {
    local zone_id="$1"
    local record_name="$2"
    local record_type="${3:-A}"
    local aws_profile="${4:-${AWS_PROFILE:-default}}"
    
    debug "Deleting Route 53 record: $record_name ($record_type)"
    
    # Get current record first (needed for DELETE action)
    local current_record
    current_record=$(r53_get_record "$zone_id" "$record_name" "$record_type" "$aws_profile")
    
    if [[ -z "$current_record" || "$current_record" == "null" ]]; then
        warn "Record not found: $record_name"
        return $EXIT_SUCCESS
    fi
    
    # Create change batch JSON
    local change_batch
    read -r -d '' change_batch << EOF || true
{
    "Changes": [{
        "Action": "DELETE",
        "ResourceRecordSet": $current_record
    }]
}
EOF
    
    if ! aws route53 change-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --change-batch "$change_batch" \
        --profile "$aws_profile" \
        --output json 2>/dev/null > /dev/null; then
        
        error "Failed to delete Route 53 record: $record_name"
        return $EXIT_AWS_ERROR
    fi
    
    success "Route 53 record deleted: $record_name"
    return $EXIT_SUCCESS
}

# Check if domain resolves to target (DNS propagation check)
r53_check_dns_propagation() {
    local record_name="$1"
    local expected_target="$2"  # e.g., d123abc.cloudfront.net
    local timeout="${3:-60}"
    local aws_profile="${4:-${AWS_PROFILE:-default}}"
    
    debug "Checking DNS propagation for: $record_name → $expected_target"
    
    # Remove trailing dot for dig lookup
    record_name="${record_name%.}"
    expected_target="${expected_target%.}"
    
    local elapsed=0
    local poll_interval=5
    
    while [[ $elapsed -lt $timeout ]]; do
        # Query DNS (prefer dig if available, fall back to nslookup)
        local result
        if command_exists dig; then
            result=$(dig +short "$record_name" CNAME 2>/dev/null | grep -q "$expected_target" && echo "true" || echo "false")
        elif command_exists nslookup; then
            result=$(nslookup "$record_name" 2>/dev/null | grep -q "$expected_target" && echo "true" || echo "false")
        else
            warn "No DNS lookup tool available (dig or nslookup)"
            return $EXIT_SUCCESS
        fi
        
        if [[ "$result" == "true" ]]; then
            success "DNS propagation verified: $record_name → $expected_target"
            return $EXIT_SUCCESS
        fi
        
        if [[ $elapsed -lt $timeout ]]; then
            info "DNS propagation pending... ($elapsed seconds)"
            sleep $poll_interval
            ((elapsed += poll_interval))
        fi
    done
    
    warn "DNS propagation check timed out (but may complete later)"
    return $EXIT_SUCCESS  # Don't fail deployment
}

export -f r53_zone_exists r53_get_zone_id r53_list_zones
export -f r53_create_alias_record r53_list_records r53_get_record r53_delete_record
export -f r53_check_dns_propagation
