#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Multi-Subdomain Support Library                                            ║
# ║  Phase 5: User Story 3 - Multi-Subdomain Support (Tasks T039-T046)          ║
# ║  Handles parameter validation, routing, file upload, version tracking        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ============================================================================
# T039: Multi-Subdomain Parameter Validation
# ============================================================================

validate_subdomains() {
    local subdomains_str="$1"
    local max_subdomains=10
    
    if [[ -z "$subdomains_str" ]]; then
        error "Subdomain list cannot be empty"
        return 1
    fi
    
    # Convert comma-separated string to array
    local -a subdomains=()
    IFS=',' read -ra subdomains <<< "$subdomains_str"
    
    # Validate subdomain count
    if (( ${#subdomains[@]} > max_subdomains )); then
        error "Too many subdomains (${#subdomains[@]}) - max $max_subdomains allowed"
        return 1
    fi
    
    # Validate each subdomain format
    local -A seen_subdomains
    for subdomain in "${subdomains[@]}"; do
        # Trim whitespace
        subdomain="${subdomain#"${subdomain%%[![:space:]]*}"}"
        subdomain="${subdomain%"${subdomain##*[![:space:]]}"}"
        
        # Check for duplicates
        if [[ -n "${seen_subdomains[$subdomain]}" ]]; then
            error "Duplicate subdomain: $subdomain"
            return 1
        fi
        seen_subdomains[$subdomain]=1
        
        # Validate format (lowercase alphanumeric, hyphens, underscores)
        if ! [[ $subdomain =~ ^[a-z0-9_-]+$ ]]; then
            error "Invalid subdomain format: '$subdomain' (must be lowercase alphanumeric, hyphens, underscores)"
            return 1
        fi
        
        # Check length (max 63 chars per DNS spec)
        if (( ${#subdomain} > 63 )); then
            error "Subdomain too long: '$subdomain' (max 63 characters)"
            return 1
        fi
    done
    
    # Return success - validation passed
    return 0
}

normalize_subdomains() {
    local subdomains_str="$1"
    local -a normalized=()
    
    IFS=',' read -ra subdomains_arr <<< "$subdomains_str"
    for subdomain in "${subdomains_arr[@]}"; do
        # Trim and convert to lowercase
        subdomain="${subdomain#"${subdomain%%[![:space:]]*}"}"
        subdomain="${subdomain%"${subdomain##*[![:space:]]}"}"
        subdomain="${subdomain,,}"
        normalized+=("$subdomain")
    done
    
    # Output as JSON array
    printf '%s\n' "$(printf '"%s",' "${normalized[@]}" | sed 's/,$//')"
}

# ============================================================================
# T040: CloudFront Behavior Generation for Multi-Subdomain Routing
# ============================================================================

generate_cloudfront_behaviors() {
    local -a subdomains=("$@")
    local behaviors="[]"
    
    for subdomain in "${subdomains[@]}"; do
        # Create behavior for each subdomain path
        # Example: www subdomain routes to /www/*, blog routes to /blog/*
        local behavior=$(cat <<EOF
{
  "PathPattern": "/${subdomain}/*",
  "TargetOriginId": "S3Origin",
  "ViewerProtocolPolicy": "redirect-to-https",
  "AllowedMethods": ["GET", "HEAD", "OPTIONS"],
  "CachedMethods": ["GET", "HEAD"],
  "Compress": true,
  "ForwardedValues": {
    "QueryString": false,
    "Cookies": {"Forward": "none"}
  }
}
EOF
)
        # Append to behaviors array
        behaviors=$(echo "$behaviors" | jq --argjson behavior "$behavior" '. += [$behavior]')
    done
    
    echo "$behaviors"
}

# ============================================================================
# T042: Multi-Subdomain File Upload with S3 Prefix Routing
# ============================================================================

organize_files_by_subdomain() {
    local source_dir="$1"
    local subdomains_str="$2"
    
    # Create map of subdomain -> files to upload
    local -A subdomain_files
    
    # Check if source directory has subdirectory structure (subdomain/)
    if [[ -d "$source_dir/www" ]] || [[ -d "$source_dir/blog" ]]; then
        # Directory-based organization
        IFS=',' read -ra subdomains_arr <<< "$subdomains_str"
        for subdomain in "${subdomains_arr[@]}"; do
            subdomain="${subdomain#"${subdomain%%[![:space:]]*}"}"
            subdomain="${subdomain%"${subdomain##*[![:space:]]}"}"
            
            if [[ -d "$source_dir/$subdomain" ]]; then
                subdomain_files[$subdomain]="$source_dir/$subdomain"
            else
                warn "No directory found for subdomain: $subdomain"
                subdomain_files[$subdomain]="$source_dir"
            fi
        done
    else
        # Flat structure - use same source for all subdomains
        IFS=',' read -ra subdomains_arr <<< "$subdomains_str"
        for subdomain in "${subdomains_arr[@]}"; do
            subdomain="${subdomain#"${subdomain%%[![:space:]]*}"}"
            subdomain="${subdomain%"${subdomain##*[![:space:]]}"}"
            subdomain_files[$subdomain]="$source_dir"
        done
    fi
    
    # Output map as JSON
    local json="{"
    for subdomain in "${!subdomain_files[@]}"; do
        json+="\"$subdomain\":\"${subdomain_files[$subdomain]}\","
    done
    json="${json%,}"
    json+="}"
    
    echo "$json"
}

upload_files_for_subdomain() {
    local s3_bucket="$1"
    local subdomain="$2"
    local source_dir="$3"
    local aws_profile="$4"
    
    info "Uploading files for subdomain: $subdomain"
    
    # Find all eligible files
    local -a files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$source_dir" -type f \( \
        -name "*.html" -o -name "*.css" -o -name "*.js" -o \
        -name "*.json" -o -name "*.jpg" -o -name "*.png" -o \
        -name "*.svg" -o -name "*.webp" -o -name "*.gif" -o \
        -name "*.ico" -o -name "*.woff2" -o -name "*.ttf" \
    \) -print0)
    
    info "Found ${#files[@]} files to upload for $subdomain"
    
    # Upload each file with subdomain prefix
    local uploaded=0
    for file in "${files[@]}"; do
        # Calculate relative path
        local relative_path="${file#$source_dir/}"
        local s3_key="${subdomain}/${relative_path}"
        
        # Determine Content-Type
        local content_type
        case "$file" in
            *.html) content_type="text/html; charset=utf-8" ;;
            *.css) content_type="text/css; charset=utf-8" ;;
            *.js) content_type="application/javascript; charset=utf-8" ;;
            *.json) content_type="application/json; charset=utf-8" ;;
            *.svg) content_type="image/svg+xml" ;;
            *.png) content_type="image/png" ;;
            *.jpg) content_type="image/jpeg" ;;
            *.webp) content_type="image/webp" ;;
            *.gif) content_type="image/gif" ;;
            *.ico) content_type="image/x-icon" ;;
            *.woff2) content_type="font/woff2" ;;
            *.ttf) content_type="font/ttf" ;;
            *) content_type="application/octet-stream" ;;
        esac
        
        # Upload to S3 with subdomain prefix
        if s3_upload_object "$s3_bucket" "$s3_key" "$file" "$content_type" "$aws_profile"; then
            ((uploaded++))
        else
            error "Failed to upload $s3_key"
            return 1
        fi
    done
    
    info "Uploaded $uploaded files for subdomain $subdomain"
    return 0
}

# ============================================================================
# T043: Multi-Subdomain Version Tracking
# ============================================================================

create_multi_subdomain_version_manifest() {
    local version_id="$1"
    local subdomains_str="$2"
    local s3_bucket="$3"
    local domain="$4"
    local aws_profile="$5"
    
    # Create manifest structure with per-subdomain file lists
    local manifest=$(cat <<EOF
{
  "version_id": "$version_id",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "domain": "$domain",
  "subdomains": {},
  "bucket": "$s3_bucket",
  "created_by": "deploy.sh"
}
EOF
)
    
    # For each subdomain, list all files
    IFS=',' read -ra subdomains_arr <<< "$subdomains_str"
    for subdomain in "${subdomains_arr[@]}"; do
        subdomain="${subdomain#"${subdomain%%[![:space:]]*}"}"
        subdomain="${subdomain%"${subdomain##*[![:space:]]}"}"
        
        # Get list of files for this subdomain from S3
        local files=$(aws s3 ls "s3://$s3_bucket/${subdomain}/" --recursive \
            --profile "$aws_profile" 2>/dev/null | \
            awk '{print $4}' | \
            jq -R -s 'split("\n") | map(select(length > 0))')
        
        # Add to manifest
        manifest=$(echo "$manifest" | jq \
            --arg subdomain "$subdomain" \
            --argjson files "$files" \
            '.subdomains[$subdomain] = {"files": $files, "count": ($files | length)}')
    done
    
    # Store in S3 at version path
    local version_path="versions/multi-${version_id}.json"
    echo "$manifest" | aws s3 cp - "s3://$s3_bucket/$version_path" \
        --profile "$aws_profile" \
        --content-type "application/json" 2>/dev/null
    
    # Store locally
    local local_version_dir="deployments"
    mkdir -p "$local_version_dir"
    echo "$manifest" > "$local_version_dir/multi-${version_id}.json"
    
    info "Created multi-subdomain version manifest: $version_id"
    return 0
}

# ============================================================================
# T044: Multi-Subdomain Update Command
# ============================================================================

detect_subdomain_changes() {
    local subdomain="$1"
    local source_dir="$2"
    local s3_bucket="$3"
    local aws_profile="$4"
    
    # Get current files from S3 for this subdomain
    local s3_files=$(aws s3 ls "s3://$s3_bucket/${subdomain}/" --recursive \
        --profile "$aws_profile" 2>/dev/null | awk '{print $4}')
    
    # Get local files
    local -a local_files=()
    while IFS= read -r -d '' file; do
        local relative_path="${file#$source_dir/}"
        local s3_key="${subdomain}/${relative_path}"
        local_files+=("$s3_key")
    done < <(find "$source_dir" -type f \( \
        -name "*.html" -o -name "*.css" -o -name "*.js" -o \
        -name "*.json" -o -name "*.jpg" -o -name "*.png" -o \
        -name "*.svg" -o -name "*.webp" -o -name "*.gif" -o \
        -name "*.ico" -o -name "*.woff2" -o -name "*.ttf" \
    \) -print0)
    
    # Compare and identify changes
    local -a changed=()
    local -a added=()
    local -a deleted=()
    
    # Find added/modified files
    for file in "${local_files[@]}"; do
        if ! echo "$s3_files" | grep -q "^$file$"; then
            added+=("$file")
        fi
    done
    
    # Find deleted files
    for s3_file in $s3_files; do
        local found=0
        for file in "${local_files[@]}"; do
            if [[ "$file" == "$s3_file" ]]; then
                found=1
                break
            fi
        done
        if (( !found )); then
            deleted+=("$s3_file")
        fi
    done
    
    # Output results as JSON
    local results=$(cat <<EOF
{
  "subdomain": "$subdomain",
  "added": $(printf '%s\n' "${added[@]}" | jq -R -s 'split("\n")[:-1]'),
  "deleted": $(printf '%s\n' "${deleted[@]}" | jq -R -s 'split("\n")[:-1]'),
  "total_changes": $((${#added[@]} + ${#deleted[@]}))
}
EOF
)
    echo "$results"
}

# ============================================================================
# T045: Multi-Subdomain CloudFront Invalidation
# ============================================================================

invalidate_subdomain_cache() {
    local distribution_id="$1"
    local subdomain="$2"
    local aws_profile="$3"
    
    # Invalidate only paths for this subdomain
    local invalidation_path="/${subdomain}/*"
    
    info "Creating CloudFront invalidation for subdomain $subdomain: $invalidation_path"
    
    local invalidation_id=$(aws cloudfront create-invalidation \
        --distribution-id "$distribution_id" \
        --paths "$invalidation_path" \
        --profile "$aws_profile" \
        --query 'Invalidation.Id' \
        --output text 2>/dev/null)
    
    if [[ -z "$invalidation_id" ]]; then
        error "Failed to create CloudFront invalidation"
        return 1
    fi
    
    # Poll for completion (timeout: 5 minutes)
    local start_time=$(date +%s)
    local timeout=300
    local poll_interval=10
    
    while true; do
        local current_time=$(date +%s)
        if (( current_time - start_time > timeout )); then
            warn "CloudFront invalidation timeout (still in progress): $invalidation_id"
            break
        fi
        
        local status=$(aws cloudfront get-invalidation \
            --distribution-id "$distribution_id" \
            --id "$invalidation_id" \
            --profile "$aws_profile" \
            --query 'Invalidation.Status' \
            --output text 2>/dev/null)
        
        if [[ "$status" == "Completed" ]]; then
            info "CloudFront invalidation completed: $invalidation_id"
            return 0
        fi
        
        sleep "$poll_interval"
    done
    
    return 0
}

export -f validate_subdomains
export -f normalize_subdomains
export -f generate_cloudfront_behaviors
export -f organize_files_by_subdomain
export -f upload_files_for_subdomain
export -f create_multi_subdomain_version_manifest
export -f detect_subdomain_changes
export -f invalidate_subdomain_cache
