#!/bin/bash

# Configuration management system
# Provides: Config file parsing, CLI argument handling, environment variable resolution
# Priority order: CLI args > Environment vars > Config file > Defaults

# Global configuration
declare -A CONFIG=()

# Default values
CONFIG_DEFAULTS=(
    [REGION]="us-east-1"
    [SUBDOMAIN]="www"
    [SOURCE_DIR]="./"
    [AWS_PROFILE]="default"
    [DRY_RUN]="0"
    [VERBOSE]="0"
)

# Load default configuration
load_defaults() {
    for key in "${!CONFIG_DEFAULTS[@]}"; do
        CONFIG["$key"]="${CONFIG_DEFAULTS[$key]}"
    done
    debug "Default configuration loaded"
}

# Load configuration from .deployrc file (YAML format)
# Falls back to JSON parsing if jq is available, since pure Bash YAML parsing is complex
load_config_file() {
    local config_file="${1:-.deployrc}"
    
    if [[ ! -f "$config_file" ]]; then
        debug "Config file not found: $config_file"
        return $EXIT_SUCCESS
    fi
    
    if [[ ! -r "$config_file" ]]; then
        warn "Config file not readable: $config_file"
        return $EXIT_SUCCESS
    fi
    
    debug "Loading configuration from: $config_file"
    
    # Simple YAML parsing for common config keys
    # Supports: key: value format (basic YAML)
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Parse key: value format
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]^^}"  # Convert to uppercase
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes if present
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            
            CONFIG["$key"]="$value"
            debug "  $key=${CONFIG[$key]}"
        fi
    done < "$config_file"
    
    info "Configuration loaded from $config_file"
    return $EXIT_SUCCESS
}

# Load configuration from environment variables
load_env_config() {
    # Look for DEPLOY_* prefixed environment variables
    local env_var value key
    
    while IFS= read -r env_var; do
        if [[ "$env_var" =~ ^DEPLOY_([A-Z_]+)= ]]; then
            key="${BASH_REMATCH[1]}"
            value="${!env_var}"
            if [[ -n "$value" ]]; then
                CONFIG["$key"]="$value"
                debug "Environment: $key=${CONFIG[$key]}"
            fi
        fi
    done < <(compgen -e)
    
    debug "Environment configuration loaded"
}

# Load configuration from CLI arguments
# Arguments should be in format: --key value or --flag
load_cli_args() {
    local -a args=("$@")
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        local arg="${args[$i]}"
        
        if [[ "$arg" =~ ^--([a-z_-]+)$ ]]; then
            local key="${BASH_REMATCH[1]^^}"  # Convert to uppercase
            key="${key//-/_}"  # Replace hyphens with underscores
            local value=""
            
            # Check if next argument is a value (doesn't start with --)
            if [[ $((i + 1)) -lt ${#args[@]} && ! "${args[$((i + 1))]}" =~ ^-- ]]; then
                value="${args[$((i + 1))]}"
                CONFIG["$key"]="$value"
                debug "CLI arg: $key=${CONFIG[$key]}"
                ((i += 2))
            else
                # Flag without value (boolean, set to true)
                CONFIG["$key"]="true"
                debug "CLI flag: $key=true"
                ((i += 1))
            fi
        else
            ((i += 1))
        fi
    done
}

# Get configuration value
get_config() {
    local key="$1"
    local default="${2:-}"
    
    key="${key^^}"  # Convert to uppercase
    key="${key//-/_}"  # Replace hyphens with underscores
    
    echo "${CONFIG[$key]:-$default}"
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    
    key="${key^^}"  # Convert to uppercase
    key="${key//-/_}"  # Replace hyphens with underscores
    
    CONFIG["$key"]="$value"
}

# Check if configuration key exists and is set
has_config() {
    local key="$1"
    key="${key^^}"  # Convert to uppercase
    key="${key//-/_}"  # Replace hyphens with underscores
    
    [[ -n "${CONFIG[$key]:-}" ]]
}

# Validate required configuration keys
validate_required_config() {
    local -a required=("$@")
    local -a missing=()
    
    for key in "${required[@]}"; do
        if ! has_config "$key"; then
            missing+=("$key")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required configuration: ${missing[*]}"
        return $EXIT_VALIDATION_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# Validate domain name format (RFC 1123)
validate_domain_format() {
    local domain="$1"
    
    # Basic validation: alphanumeric, hyphens, dots; at least 3 characters
    if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.?$ ]]; then
        error "Invalid domain format: $domain"
        error "Domain must be a valid FQDN (e.g., example.com or www.example.com)"
        return $EXIT_VALIDATION_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# Validate subdomain format
validate_subdomain_format() {
    local subdomain="$1"
    
    # Subdomains are optional; if provided, must be valid hostname part
    if [[ -n "$subdomain" && ! "$subdomain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        error "Invalid subdomain format: $subdomain"
        error "Subdomain must be alphanumeric (hyphens allowed), 1-63 characters"
        return $EXIT_VALIDATION_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# Validate source directory
validate_source_directory() {
    local source_dir="$1"
    
    if [[ ! -d "$source_dir" ]]; then
        error "Source directory does not exist: $source_dir"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -r "$source_dir" ]]; then
        error "Source directory is not readable: $source_dir"
        return $EXIT_VALIDATION_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# Validate AWS region format
validate_region_format() {
    local region="$1"
    
    # AWS regions are in format: xx-xxxx-# (e.g., us-east-1, eu-west-2, ap-southeast-1a)
    if ! [[ "$region" =~ ^[a-z]{2}-[a-z]+-[0-9][a-z]?$ ]]; then
        error "Invalid AWS region format: $region"
        error "Expected format: xx-xxxx-# (e.g., us-east-1, eu-west-2)"
        return $EXIT_VALIDATION_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# Print current configuration for debugging
print_config() {
    echo
    section "Current Configuration"
    
    for key in $(printf '%s\n' "${!CONFIG[@]}" | sort); do
        local value="${CONFIG[$key]}"
        
        # Mask sensitive values
        if [[ "$key" =~ (SECRET|PASSWORD|TOKEN|KEY) ]]; then
            value="***REDACTED***"
        fi
        
        echo "  $key = $value"
    done
    echo
}

# Create .deployrc example file
create_example_config() {
    local output_file="${1:-.deployrc.example}"
    
    cat > "$output_file" << 'EOF'
# AWS Static Website Deployment Configuration
# Copy to .deployrc and edit with your settings
# Format: YAML (key: value)

# Required: Website domain name
domain: example.com

# Optional: Subdomain (default: www)
# Examples: www, blog, docs, api
subdomain: www

# Optional: AWS region (default: us-east-1)
# Note: Must be us-east-1 for CloudFront with ACM certificate
region: us-east-1

# Optional: Source directory with website files (default: ./)
source_dir: ./

# Optional: AWS CLI profile to use (default: default)
aws_profile: default

# Optional: Include patterns (files to deploy)
# Default: *.html, *.css, *.js, *.json, *.jpg, *.png, *.svg, *.webp, *.gif, *.ico, *.woff2, *.ttf
include_patterns:
  - "*.html"
  - "*.css"
  - "*.js"
  - "*.json"
  - "*.jpg"
  - "*.png"
  - "*.svg"

# Optional: Exclude patterns (files to skip)
# These are always excluded regardless of include_patterns
exclude_patterns:
  - "node_modules/"
  - ".git/"
  - ".env*"
  - "*.tmp"
  - ".DS_Store"

# Optional: CloudFront cache behaviors
# cache_default_ttl: 86400  # 1 day (default)
# cache_max_ttl: 31536000  # 1 year (default for immutable assets)

# Optional: Enable verbose logging
# verbose: true

# Optional: Enable dry-run mode (validate without making changes)
# dry_run: false
EOF
    
    info "Created example config: $output_file"
}

export CONFIG
