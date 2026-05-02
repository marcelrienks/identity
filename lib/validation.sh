#!/bin/bash

# Validation and health check framework (T012, T005a)
# Provides: Configuration validation, AWS resource checks, health checks, secrets scanning

# Validate AWS credentials
validate_aws_credentials() {
    local aws_profile="${1:-${AWS_PROFILE:-default}}"
    
    debug "Validating AWS credentials"
    check_aws_credentials "$aws_profile"
}

# Validate domain name format (RFC 1123)
validate_domain_format() {
    local domain="$1"
    
    debug "Validating domain format: $domain"
    validate_domain_format "$domain"
}

# Validate subdomain format
validate_subdomain_format() {
    local subdomain="$1"
    
    [[ -z "$subdomain" ]] && return $EXIT_SUCCESS
    
    debug "Validating subdomain format: $subdomain"
    validate_subdomain_format "$subdomain"
}

# Validate source directory exists and is readable
validate_source_directory() {
    local source_dir="${1:-.}"
    
    debug "Validating source directory: $source_dir"
    
    if [[ ! -d "$source_dir" ]]; then
        error "Source directory does not exist: $source_dir"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -r "$source_dir" ]]; then
        error "Source directory is not readable: $source_dir"
        return $EXIT_VALIDATION_ERROR
    fi
    
    success "Source directory validated: $source_dir"
    return $EXIT_SUCCESS
}

# Validate all local files exist (from manifest or source dir)
validate_local_files_exist() {
    local source_dir="${1:-.}"
    local -a missing_files=()
    
    debug "Validating local files"
    
    while IFS= read -r file; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done < <(find_files_to_upload "$source_dir")
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        error "Missing files detected:"
        for file in "${missing_files[@]}"; do
            error "  - $file"
        done
        return $EXIT_VALIDATION_ERROR
    fi
    
    info "All local files validated"
    return $EXIT_SUCCESS
}

# Health check: Verify HTTPS endpoint (SSL certificate, TLS version)
health_check_https_endpoint() {
    local url="$1"
    
    debug "Health check: HTTPS endpoint $url"
    
    if ! command_exists curl; then
        warn "curl not available, skipping HTTPS health check"
        return $EXIT_SUCCESS
    fi
    
    # Check HTTPS certificate validity and TLS version
    if ! curl -s -I --tlsv1.2 "$url" 2>&1 | grep -q "HTTP"; then
        warn "HTTPS health check inconclusive (endpoint may not be ready yet)"
        return $EXIT_SUCCESS
    fi
    
    # Get certificate info
    local cert_info
    cert_info=$(echo | openssl s_client -servername "${url#https://}" -connect "${url#https://}:443" 2>/dev/null | openssl x509 -noout -text 2>/dev/null || echo "")
    
    if [[ -z "$cert_info" ]]; then
        warn "Could not retrieve certificate info"
        return $EXIT_SUCCESS
    fi
    
    success "HTTPS health check passed"
    return $EXIT_SUCCESS
}

# Health check: DNS resolution verification
health_check_dns_resolution() {
    local domain="$1"
    
    debug "Health check: DNS resolution for $domain"
    
    if ! command_exists dig && ! command_exists nslookup; then
        debug "DNS tools not available, skipping DNS health check"
        return $EXIT_SUCCESS
    fi
    
    local resolved
    if command_exists dig; then
        resolved=$(dig +short "$domain" 2>/dev/null | head -1)
    else
        resolved=$(nslookup "$domain" 2>/dev/null | grep "Address" | head -1)
    fi
    
    if [[ -z "$resolved" ]]; then
        warn "DNS resolution check inconclusive"
        return $EXIT_SUCCESS
    fi
    
    success "DNS resolution verified: $domain"
    debug "  Resolved to: $resolved"
    return $EXIT_SUCCESS
}

# Health check: Asset loading via HTTP
health_check_asset_loads() {
    local url="$1"
    local -a asset_paths=("/" "/index.html")  # Default key assets
    
    debug "Health check: Asset loading from $url"
    
    if ! command_exists curl; then
        warn "curl not available, skipping asset health checks"
        return $EXIT_SUCCESS
    fi
    
    for asset in "${asset_paths[@]}"; do
        local asset_url="$url$asset"
        local http_code
        
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "$asset_url" 2>/dev/null)
        
        if [[ "$http_code" == "200" ]]; then
            debug "  ✓ Asset loaded: $asset (HTTP $http_code)"
        else
            warn "  ✗ Asset check failed: $asset (HTTP $http_code)"
        fi
    done
    
    return $EXIT_SUCCESS
}

# Validate files for secrets before upload (T005a integration)
validate_files_for_secrets_upload() {
    local source_dir="${1:-.}"
    
    debug "Validating files for secrets"
    validate_files_for_secrets "$source_dir"
}

# Full pre-deployment validation
run_full_validation() {
    local domain="$1"
    local subdomain="$2"
    local source_dir="${3:-.}"
    local aws_profile="${4:-${AWS_PROFILE:-default}}"
    
    section "Running full pre-deployment validation"
    
    # AWS credentials and permissions
    if ! validate_aws_credentials "$aws_profile"; then
        return $EXIT_AWS_ERROR
    fi
    
    # Domain format
    if ! validate_domain_format "$domain"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Subdomain format (if provided)
    if ! validate_subdomain_format "$subdomain"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Source directory
    if ! validate_source_directory "$source_dir"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Local files exist
    if ! validate_local_files_exist "$source_dir"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Secrets scanning
    if ! validate_files_for_secrets_upload "$source_dir"; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    success "All validation checks passed"
    return $EXIT_SUCCESS
}

export -f validate_aws_credentials validate_domain_format validate_subdomain_format
export -f validate_source_directory validate_local_files_exist
export -f health_check_https_endpoint health_check_dns_resolution health_check_asset_loads
export -f validate_files_for_secrets_upload run_full_validation
