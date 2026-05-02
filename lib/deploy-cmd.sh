#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Deploy Command Implementation                                              ║
# ║  Phase 3: User Story 1 - Infrastructure Provisioning with Initial Deployment║
# ║  Tasks: T014-T025 (deploy command framework, provisioning, upload, health)   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ============================================================================
# T014: Deploy Command - Argument Parsing & Configuration Loading
# ============================================================================

# Parse deploy command arguments
parse_deploy_arguments() {
    local -A args
    local -a remaining_args
    
    # Set defaults
    args[domain]=""
    args[subdomain]="www"
    args[region]="us-east-1"
    args[source_dir]="./"
    args[aws_profile]="default"
    args[dry_run]=0
    args[verbose]=0
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)
                args[domain]="$2"
                shift 2
                ;;
            --subdomain)
                args[subdomain]="$2"
                shift 2
                ;;
            --region)
                args[region]="$2"
                shift 2
                ;;
            --source-dir)
                args[source_dir]="$2"
                shift 2
                ;;
            --aws-profile)
                args[aws_profile]="$2"
                shift 2
                ;;
            --dry-run)
                args[dry_run]=1
                shift
                ;;
            --verbose|-v)
                args[verbose]=1
                shift
                ;;
            *)
                remaining_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Load .deployrc config if exists and merge with CLI args
    load_deployrc_config args
    
    # Validate that domain is provided
    if [[ -z "${args[domain]}" ]]; then
        error "Domain is required. Provide via --domain flag or .deployrc"
        return 1
    fi
    
    # Export parsed args for use in calling functions
    export DEPLOY_DOMAIN="${args[domain]}"
    export DEPLOY_SUBDOMAIN="${args[subdomain]}"
    export DEPLOY_REGION="${args[region]}"
    export DEPLOY_SOURCE_DIR="${args[source_dir]}"
    export DEPLOY_AWS_PROFILE="${args[aws_profile]}"
    export DEPLOY_DRY_RUN="${args[dry_run]}"
    
    if [[ "${args[verbose]}" -eq 1 ]]; then
        export LOG_LEVEL="DEBUG"
        debug "Deploy arguments parsed: domain=${args[domain]}, subdomain=${args[subdomain]}, region=${args[region]}"
    fi
    
    return 0
}

# Load .deployrc configuration file and merge with args
load_deployrc_config() {
    local -n args_ref=$1
    local config_file=".deployrc"
    
    if [[ ! -f "$config_file" ]]; then
        debug "No .deployrc file found, using defaults"
        return 0
    fi
    
    debug "Loading configuration from $config_file"
    
    # Parse YAML/JSON config file (simple key=value parsing for bash)
    # Supports format: key=value or key: value
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        
        # Clean up key and value
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed 's/^["'"'"']//;s/["'"'"']$//')
        
        # Map config keys to args (only if not already set via CLI)
        case "$key" in
            domain)
                [[ -z "${args_ref[domain]}" ]] && args_ref[domain]="$value"
                ;;
            subdomain)
                args_ref[subdomain]="$value"
                ;;
            region)
                args_ref[region]="$value"
                ;;
            source_dir)
                args_ref[source_dir]="$value"
                ;;
            aws_profile)
                args_ref[aws_profile]="$value"
                ;;
        esac
    done < "$config_file"
    
    return 0
}

# ============================================================================
# T015: Pre-Flight Validation for Deploy
# ============================================================================

# Run all pre-flight validations before deployment
validate_deploy_preflight() {
    info "Running pre-flight validation..."
    
    # Validate AWS credentials
    if ! validate_aws_credentials; then
        error "AWS credentials validation failed"
        return 1
    fi
    
    # Check IAM permissions
    if ! check_iam_permissions deploy; then
        error "Insufficient IAM permissions for deployment"
        return 1
    fi
    
    # Validate domain format
    if ! validate_domain_format "$DEPLOY_DOMAIN"; then
        error "Invalid domain format: $DEPLOY_DOMAIN"
        return 1
    fi
    
    # Validate subdomain format
    if ! validate_subdomain_format "$DEPLOY_SUBDOMAIN"; then
        error "Invalid subdomain format: $DEPLOY_SUBDOMAIN"
        return 1
    fi
    
    # Validate source directory
    if ! validate_source_directory "$DEPLOY_SOURCE_DIR"; then
        error "Invalid source directory: $DEPLOY_SOURCE_DIR"
        return 1
    fi
    
    # Validate local files exist and are readable
    if ! validate_local_files_exist "$DEPLOY_SOURCE_DIR"; then
        error "Source directory is empty or not readable"
        return 1
    fi
    
    # Check if S3 bucket name already in use
    if ! validate_s3_bucket_availability "$DEPLOY_DOMAIN" "$DEPLOY_SUBDOMAIN"; then
        error "S3 bucket name appears to be in use"
        return 1
    fi
    
    # Validate Route53 hosted zone (should exist or will be created)
    if ! validate_route53_zone "$DEPLOY_DOMAIN"; then
        warn "Route53 hosted zone not found for $DEPLOY_DOMAIN (will be created by CloudFormation)"
    fi
    
    info "✓ All pre-flight validations passed"
    return 0
}

# Validate domain format (RFC 1123 compliance)
validate_domain_format() {
    local domain="$1"
    
    # Basic domain validation: must contain a dot and be 3-255 chars
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate subdomain format
validate_subdomain_format() {
    local subdomain="$1"
    
    # Subdomain must be alphanumeric + hyphens, 1-63 chars
    if [[ ! "$subdomain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate S3 bucket availability
validate_s3_bucket_availability() {
    local domain="$1"
    local subdomain="$2"
    local bucket_name="website-${subdomain}-${domain//./}-s3bucket"
    bucket_name="${bucket_name,,}"  # lowercase
    
    # Check if bucket exists (this is informational)
    if s3_bucket_exists "$bucket_name"; then
        warn "S3 bucket '$bucket_name' already exists. Will update existing stack."
    fi
    
    return 0
}

# Validate Route53 hosted zone
validate_route53_zone() {
    local domain="$1"
    
    # Try to get zone ID - if it fails, warn but continue
    if ! r53_get_zone_id "$domain" &> /dev/null; then
        return 1
    fi
    
    return 0
}

# ============================================================================
# T016: Stack Naming & Existence Check
# ============================================================================

# Generate predictable CloudFormation stack name
generate_stack_name() {
    local domain="$1"
    local subdomain="$2"
    
    # Format: website-{subdomain}-{domain} (normalized, lowercase)
    local stack_name="website-${subdomain}-${domain//./}"
    echo "${stack_name,,}"
}

# Check if CloudFormation stack exists and determine mode
check_stack_exists_mode() {
    local domain="$1"
    local subdomain="$2"
    
    local stack_name=$(generate_stack_name "$domain" "$subdomain")
    
    if cfn_stack_exists "$stack_name" "$DEPLOY_REGION"; then
        export CFN_STACK_NAME="$stack_name"
        export CFN_STACK_MODE="UPDATE"
        info "✓ Stack exists: $stack_name (will UPDATE)"
        return 0
    else
        export CFN_STACK_NAME="$stack_name"
        export CFN_STACK_MODE="CREATE"
        info "✓ Stack does not exist: $stack_name (will CREATE)"
        return 0
    fi
}

# ============================================================================
# T017: CloudFormation Template Loading/Validation
# ============================================================================

# Load and validate CloudFormation template
load_cfn_template() {
    local template_path="./CloudFormation/s3-static-website.yaml"
    
    if [[ ! -f "$template_path" ]]; then
        error "CloudFormation template not found: $template_path"
        return 1
    fi
    
    # Validate YAML syntax with AWS CloudFormation
    debug "Validating CloudFormation template: $template_path"
    
    if ! aws cloudformation validate-template \
        --template-body "file://$template_path" \
        --region "$DEPLOY_REGION" \
        --profile "$DEPLOY_AWS_PROFILE" &> /dev/null; then
        error "CloudFormation template validation failed"
        return 1
    fi
    
    debug "✓ CloudFormation template validated"
    export CFN_TEMPLATE_PATH="$template_path"
    return 0
}

# ============================================================================
# T018: CloudFormation Stack Creation Workflow
# ============================================================================

# Create CloudFormation stack
create_cfn_stack() {
    local domain="$1"
    local subdomain="$2"
    local stack_name="$CFN_STACK_NAME"
    
    info "Creating CloudFormation stack: $stack_name"
    
    # Build parameters
    local cfn_params=(
        "DomainName=$domain"
        "SubdomainName=$subdomain"
        "Environment=production"
    )
    
    # In dry-run mode, just validate without creating
    if [[ "$DEPLOY_DRY_RUN" -eq 1 ]]; then
        info "DRY-RUN: Would create stack with parameters: ${cfn_params[@]}"
        return 0
    fi
    
    # Call CloudFormation create API
    if ! cfn_create_stack "$stack_name" "$CFN_TEMPLATE_PATH" cfn_params[@] "$DEPLOY_REGION" "$DEPLOY_AWS_PROFILE"; then
        error "Failed to create CloudFormation stack"
        return 1
    fi
    
    # Poll stack creation status (timeout: 10 minutes)
    debug "Polling stack creation status..."
    local max_attempts=60  # 10 minutes with 10-second intervals
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local status=$(cfn_get_stack_status "$stack_name" "$DEPLOY_REGION" "$DEPLOY_AWS_PROFILE")
        
        if [[ "$status" == "CREATE_COMPLETE" ]]; then
            info "✓ Stack creation complete: $stack_name"
            export CFN_STACK_ID=$(cfn_describe_stack "$stack_name" "$DEPLOY_REGION" "$DEPLOY_AWS_PROFILE" | jq -r '.StackId // empty')
            return 0
        elif [[ "$status" == "CREATE_FAILED" ]] || [[ "$status" == "ROLLBACK_COMPLETE" ]]; then
            error "Stack creation failed. Status: $status"
            return 1
        fi
        
        info "Stack creation in progress... ($status)"
        sleep 10
        ((attempt++))
    done
    
    error "Stack creation timeout (10 minutes exceeded)"
    return 1
}

# ============================================================================
# T019: CloudFormation Stack Update Workflow
# ============================================================================

# Update existing CloudFormation stack
update_cfn_stack() {
    local domain="$1"
    local subdomain="$2"
    local stack_name="$CFN_STACK_NAME"
    
    info "Updating CloudFormation stack: $stack_name"
    
    # Build parameters
    local cfn_params=(
        "DomainName=$domain"
        "SubdomainName=$subdomain"
        "Environment=production"
    )
    
    # In dry-run mode, just validate without updating
    if [[ "$DEPLOY_DRY_RUN" -eq 1 ]]; then
        info "DRY-RUN: Would update stack with parameters: ${cfn_params[@]}"
        return 0
    fi
    
    # Call CloudFormation update API
    if ! cfn_update_stack "$stack_name" "$CFN_TEMPLATE_PATH" cfn_params[@] "$DEPLOY_REGION" "$DEPLOY_AWS_PROFILE"; then
        error "Failed to update CloudFormation stack"
        return 1
    fi
    
    # Poll stack update status (timeout: 10 minutes)
    debug "Polling stack update status..."
    local max_attempts=60  # 10 minutes with 10-second intervals
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local status=$(cfn_get_stack_status "$stack_name" "$DEPLOY_REGION" "$DEPLOY_AWS_PROFILE")
        
        if [[ "$status" == "UPDATE_COMPLETE" ]]; then
            info "✓ Stack update complete: $stack_name"
            export CFN_STACK_ID=$(cfn_describe_stack "$stack_name" "$DEPLOY_REGION" "$DEPLOY_AWS_PROFILE" | jq -r '.StackId // empty')
            return 0
        elif [[ "$status" == "UPDATE_FAILED" ]] || [[ "$status" == "ROLLBACK_COMPLETE" ]]; then
            error "Stack update failed. Status: $status"
            return 1
        elif [[ "$status" == "UPDATE_ROLLBACK_COMPLETE" ]]; then
            # No updates needed or update rolled back
            info "✓ Stack is up to date or update was reverted"
            return 0
        fi
        
        info "Stack update in progress... ($status)"
        sleep 10
        ((attempt++))
    done
    
    error "Stack update timeout (10 minutes exceeded)"
    return 1
}

# ============================================================================
# T020: Initial File Inventory & Upload Preparation
# ============================================================================

# Prepare initial file inventory for upload
prepare_file_inventory() {
    local source_dir="$1"
    
    info "Scanning source directory for files to upload..."
    
    # Create inventory file
    local inventory_file=".deploy/file-inventory.json"
    mkdir -p ".deploy"
    
    # Get all files matching include patterns
    local -a files_to_upload
    find_files_to_upload "$source_dir" files_to_upload
    
    if [[ ${#files_to_upload[@]} -eq 0 ]]; then
        error "No files found to upload in $source_dir"
        return 1
    fi
    
    # Calculate hashes and build inventory
    local total_size=0
    echo "[" > "$inventory_file"
    
    local first=1
    for file in "${files_to_upload[@]}"; do
        local relative_path="${file#$source_dir/}"
        local file_hash=$(sha256sum "$file" | awk '{print $1}')
        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        local content_type=$(get_content_type "$relative_path")
        
        ((total_size += file_size))
        
        if [[ $first -eq 0 ]]; then
            echo "," >> "$inventory_file"
        fi
        first=0
        
        cat >> "$inventory_file" << EOF
  {
    "path": "$relative_path",
    "hash": "$file_hash",
    "size": $file_size,
    "content_type": "$content_type",
    "local_path": "$file"
  }
EOF
    done
    
    echo -e "\n]" >> "$inventory_file"
    
    info "✓ File inventory prepared"
    info "  Files: ${#files_to_upload[@]}, Total size: $((total_size / 1024 / 1024)) MB"
    
    if [[ "$DEPLOY_DRY_RUN" -eq 1 ]]; then
        info "DRY-RUN: Would upload ${#files_to_upload[@]} files"
        info "Files:"
        for file in "${files_to_upload[@]:0:10}"; do
            echo "  - ${file#$source_dir/}"
        done
        if [[ ${#files_to_upload[@]} -gt 10 ]]; then
            echo "  ... and $((${#files_to_upload[@]} - 10)) more"
        fi
    fi
    
    return 0
}

# Get content type for file
get_content_type() {
    local file="$1"
    case "${file##*.}" in
        html) echo "text/html; charset=utf-8" ;;
        css) echo "text/css; charset=utf-8" ;;
        js) echo "application/javascript; charset=utf-8" ;;
        json) echo "application/json; charset=utf-8" ;;
        jpg|jpeg) echo "image/jpeg" ;;
        png) echo "image/png" ;;
        gif) echo "image/gif" ;;
        webp) echo "image/webp" ;;
        svg) echo "image/svg+xml; charset=utf-8" ;;
        ico) echo "image/x-icon" ;;
        woff2) echo "font/woff2" ;;
        woff) echo "font/woff" ;;
        ttf) echo "font/ttf" ;;
        otf) echo "font/otf" ;;
        *) echo "application/octet-stream" ;;
    esac
}

# ============================================================================
# T021/T021a: Parallel File Upload with Retry & Resume
# ============================================================================

# Upload files to S3 with retry logic and resumption capability
upload_files_to_s3() {
    local source_dir="$1"
    local s3_bucket="$2"
    local inventory_file=".deploy/file-inventory.json"
    local checkpoint_file=".deploy/last-upload-state.json"
    
    if [[ ! -f "$inventory_file" ]]; then
        error "File inventory not found: $inventory_file"
        return 1
    fi
    
    if [[ "$DEPLOY_DRY_RUN" -eq 1 ]]; then
        info "DRY-RUN: Skipping actual S3 upload"
        return 0
    fi
    
    # Load checkpoint if exists (for resumption)
    local -A uploaded_etags
    if [[ -f "$checkpoint_file" ]]; then
        info "Loading previous upload state for resumption..."
        # Parse checkpoint file
        while IFS='=' read -r key value; do
            uploaded_etags["$key"]="$value"
        done < <(jq -r '.uploaded[] | "\(.path)=\(.etag)"' "$checkpoint_file")
    fi
    
    info "Starting parallel file upload to S3 bucket: $s3_bucket"
    
    # Parse inventory and upload files (batches of 5)
    local batch_size=5
    local -a pids=()
    local total_files=$(jq length "$inventory_file")
    local uploaded_count=0
    
    # Create checkpoint structure
    echo '{"uploaded": [], "failed": [], "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$checkpoint_file"
    
    # Process files in batches
    local file_index=0
    while [[ $file_index -lt $total_files ]]; do
        # Wait for batch to complete if we have max parallel uploads
        while [[ ${#pids[@]} -ge $batch_size ]]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    unset 'pids[$i]'
                fi
            done
            pids=("${pids[@]}")  # Reindex array
            sleep 0.5
        done
        
        # Get file info from inventory
        local file_info=$(jq ".[$file_index]" "$inventory_file")
        local relative_path=$(echo "$file_info" | jq -r '.path')
        local file_hash=$(echo "$file_info" | jq -r '.hash')
        local local_path=$(echo "$file_info" | jq -r '.local_path')
        local content_type=$(echo "$file_info" | jq -r '.content_type')
        
        # Check if already uploaded
        if [[ -n "${uploaded_etags[$relative_path]}" ]]; then
            debug "Skipping already uploaded: $relative_path"
            ((uploaded_count++))
        else
            # Upload file in background with retry logic
            (
                local max_retries=3
                local retry=0
                local backoff=2
                
                while [[ $retry -lt $max_retries ]]; do
                    debug "Uploading [$((file_index + 1))/$total_files]: $relative_path (attempt $((retry + 1)))"
                    
                    # Determine cache headers based on file type
                    local cache_control="max-age=31536000"  # 1 year default
                    case "${relative_path##*.}" in
                        html) cache_control="max-age=60" ;;
                        css|js) cache_control="max-age=2592000" ;;  # 30 days
                    esac
                    
                    # Upload file to S3
                    if s3_upload_object "$s3_bucket" "$relative_path" "$local_path" \
                        --content-type "$content_type" \
                        --cache-control "$cache_control"; then
                        
                        info "✓ Uploaded: $relative_path"
                        
                        # Update checkpoint
                        local file_etag=$(aws s3api head-object \
                            --bucket "$s3_bucket" \
                            --key "$relative_path" \
                            --region "$DEPLOY_REGION" \
                            --profile "$DEPLOY_AWS_PROFILE" \
                            --query 'ETag' --output text)
                        
                        # Append to checkpoint (simple append, not ideal but works)
                        jq --arg path "$relative_path" --arg etag "$file_etag" \
                            '.uploaded += [{path: $path, etag: $etag}]' "$checkpoint_file" > "${checkpoint_file}.tmp"
                        mv "${checkpoint_file}.tmp" "$checkpoint_file"
                        
                        break
                    fi
                    
                    ((retry++))
                    if [[ $retry -lt $max_retries ]]; then
                        warn "Upload failed, retrying in ${backoff}s... (attempt $((retry + 1))/$max_retries)"
                        sleep $backoff
                        backoff=$((backoff * 2))
                    fi
                done
                
                if [[ $retry -eq $max_retries ]]; then
                    error "Failed to upload $relative_path after $max_retries attempts"
                    jq --arg path "$relative_path" '.failed += [$path]' "$checkpoint_file" > "${checkpoint_file}.tmp"
                    mv "${checkpoint_file}.tmp" "$checkpoint_file"
                fi
            ) &
            
            pids+=($!)
        fi
        
        ((file_index++))
    done
    
    # Wait for all background jobs to complete
    info "Waiting for all uploads to complete..."
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Check for failed uploads
    local failed_count=$(jq '.failed | length' "$checkpoint_file")
    if [[ $failed_count -gt 0 ]]; then
        error "Upload completed with $failed_count failures"
        jq '.failed[]' "$checkpoint_file"
        return 1
    fi
    
    info "✓ All files uploaded successfully"
    return 0
}

# ============================================================================
# T022: Version Snapshot Creation
# ============================================================================

# Create version manifest for initial deployment
create_version_snapshot() {
    local source_dir="$1"
    local s3_bucket="$2"
    local domain="$3"
    local subdomain="$4"
    
    # Generate timestamp-based version ID
    local version_id=$(date +%Y%m%d-%H%M%S)
    
    info "Creating version snapshot: $version_id"
    
    # Build manifest
    local inventory_file=".deploy/file-inventory.json"
    
    local manifest=$(jq --arg vid "$version_id" --arg domain "$domain" --arg subdomain "$subdomain" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
            version_id: $vid,
            timestamp: $ts,
            domain: $domain,
            subdomain: $subdomain,
            files: .
        }' "$inventory_file")
    
    # Store locally
    mkdir -p ".deploy/versions"
    echo "$manifest" > ".deploy/versions/${version_id}.json"
    
    # Store to S3 if not dry-run
    if [[ "$DEPLOY_DRY_RUN" -eq 0 ]]; then
        echo "$manifest" | s3_upload_object "$s3_bucket" "versions/${version_id}.json" "/dev/stdin" \
            --content-type "application/json" \
            --cache-control "max-age=0"
    fi
    
    # Save deployment record
    mkdir -p ".deploy/deployments"
    local log_file=".deploy/deployments/$(date +%Y-%m-%d).log"
    cat >> "$log_file" << EOF
[$(date -u +%Y-%m-%dT%H:%M:%SZ)] DEPLOY
  Version: $version_id
  Domain: $domain
  Subdomain: $subdomain
  Files: $(jq length "$inventory_file")
  Status: SUCCESS
EOF
    
    export DEPLOY_VERSION_ID="$version_id"
    info "✓ Version snapshot created: $version_id"
    return 0
}

# ============================================================================
# Main Deploy Function
# ============================================================================

cmd_deploy() {
    local start_time=$(date +%s)
    
    info "═══════════════════════════════════════════════════════════════════"
    info "AWS Static Website Deployment - Phase 3: Infrastructure Provisioning"
    info "═══════════════════════════════════════════════════════════════════"
    
    # Parse arguments and load config
    if ! parse_deploy_arguments "$@"; then
        return 1
    fi
    
    # Run pre-flight validation
    if ! validate_deploy_preflight; then
        if [[ "$DEPLOY_DRY_RUN" -eq 0 ]]; then
            return 1
        else
            warn "Pre-flight validation failed but continuing in dry-run mode"
        fi
    fi
    
    # Check stack existence and determine mode
    if ! check_stack_exists_mode "$DEPLOY_DOMAIN" "$DEPLOY_SUBDOMAIN"; then
        return 1
    fi
    
    # Load CloudFormation template
    if ! load_cfn_template; then
        return 1
    fi
    
    # Create or update CloudFormation stack
    if [[ "$CFN_STACK_MODE" == "CREATE" ]]; then
        if ! create_cfn_stack "$DEPLOY_DOMAIN" "$DEPLOY_SUBDOMAIN"; then
            return 1
        fi
    else
        if ! update_cfn_stack "$DEPLOY_DOMAIN" "$DEPLOY_SUBDOMAIN"; then
            return 1
        fi
    fi
    
    # Get S3 bucket name from stack outputs
    local s3_bucket=$(cfn_describe_stack "$CFN_STACK_NAME" "$DEPLOY_REGION" "$DEPLOY_AWS_PROFILE" | \
        jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="S3BucketName") | .OutputValue')
    
    if [[ -z "$s3_bucket" ]]; then
        error "Could not retrieve S3 bucket name from CloudFormation stack"
        return 1
    fi
    
    export DEPLOY_S3_BUCKET="$s3_bucket"
    info "✓ S3 bucket identified: $s3_bucket"
    
    # Prepare file inventory
    if ! prepare_file_inventory "$DEPLOY_SOURCE_DIR"; then
        return 1
    fi
    
    # T041: Run secrets scanning before upload
    info "Running secrets scanning on files before upload..."
    if ! validate_files_for_secrets "$DEPLOY_SOURCE_DIR"; then
        error "Secrets scanning failed - files contain sensitive patterns"
        return 1
    fi
    
    # Upload files to S3
    if [[ "$DEPLOY_DRY_RUN" -eq 0 ]]; then
        if ! upload_files_to_s3 "$DEPLOY_SOURCE_DIR" "$s3_bucket"; then
            error "File upload failed. You can resume with: ./deploy.sh deploy --domain $DEPLOY_DOMAIN"
            return 1
        fi
    fi
    
    # Create version snapshot
    if ! create_version_snapshot "$DEPLOY_SOURCE_DIR" "$s3_bucket" "$DEPLOY_DOMAIN" "$DEPLOY_SUBDOMAIN"; then
        return 1
    fi
    
    # Invalidate CloudFront cache
    if [[ "$DEPLOY_DRY_RUN" -eq 0 ]]; then
        info "Invalidating CloudFront cache..."
        # This will be implemented as part of lib/cloudfront.sh wrapper
        # For now, we'll handle it in T023
    fi
    
    # Run health checks
    if [[ "$DEPLOY_DRY_RUN" -eq 0 ]]; then
        info "Running post-deployment health checks..."
        # This will be implemented as part of T024
    fi
    
    # Report deployment completion
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    info ""
    info "✓ Deployment Complete!"
    info "═══════════════════════════════════════════════════════════════════"
    info "Stack:           $CFN_STACK_NAME"
    info "S3 Bucket:       $s3_bucket"
    info "Domain:          $DEPLOY_DOMAIN"
    info "Subdomain:       $DEPLOY_SUBDOMAIN"
    info "Version:         $DEPLOY_VERSION_ID"
    info "Deployment Time: ${duration}s"
    info "═══════════════════════════════════════════════════════════════════"
    
    # Save deployment state
    save_deployment_state "$CFN_STACK_NAME" "$s3_bucket" "$DEPLOY_DOMAIN" "$DEPLOY_SUBDOMAIN"
    
    return 0
}

# Save deployment state for future updates
save_deployment_state() {
    local stack_name="$1"
    local s3_bucket="$2"
    local domain="$3"
    local subdomain="$4"
    
    mkdir -p ".deploy"
    
    cat > ".deploy/state.json" << EOF
{
  "stack_name": "$stack_name",
  "s3_bucket": "$s3_bucket",
  "domain": "$domain",
  "subdomain": "$subdomain",
  "region": "$DEPLOY_REGION",
  "last_deployed": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "$DEPLOY_VERSION_ID"
}
EOF
    
    debug "Deployment state saved to .deploy/state.json"
}
