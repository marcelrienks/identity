#!/bin/bash

# Common utilities and global constants for unified deployment script
# Provides: Script directory paths, error handling, signal traps, utility functions

# Global constants - Script paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LIB_DIR="$SCRIPT_DIR/lib"
readonly DEPLOY_DIR="$SCRIPT_DIR/.deploy"
readonly TESTS_DIR="$SCRIPT_DIR/tests"
readonly CFN_DIR="$SCRIPT_DIR/CloudFormation"
readonly LOG_DIR="$SCRIPT_DIR/logs"

# Global constants - Application
readonly APP_NAME="deploy"
readonly APP_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_AWS_ERROR=3
readonly EXIT_VALIDATION_ERROR=4
readonly EXIT_TIMEOUT=5

# Ensure log directory exists
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Initialize logging file
export LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

# Signal handlers - Clean up on exit
_cleanup_on_exit() {
    local exit_code=$?
    debug "Cleanup: exit code=$exit_code"
    # Add cleanup tasks here (e.g., close file handles, remove temp files)
    return $exit_code
}

# Signal handler - SIGINT (Ctrl+C)
_handle_sigint() {
    error "Script interrupted by user (SIGINT)"
    exit $EXIT_ERROR
}

# Signal handler - SIGTERM
_handle_sigterm() {
    error "Script terminated (SIGTERM)"
    exit $EXIT_ERROR
}

# Setup signal traps
trap _cleanup_on_exit EXIT
trap _handle_sigint SIGINT
trap _handle_sigterm SIGTERM

# Error handler - Exit with error message
die() {
    local message="$1"
    local exit_code="${2:-$EXIT_ERROR}"
    error "$message"
    exit "$exit_code"
}

# Check if command exists
command_exists() {
    local cmd="$1"
    command -v "$cmd" > /dev/null 2>&1
}

# Check if file exists and is readable
file_exists() {
    local file="$1"
    [[ -f "$file" && -r "$file" ]]
}

# Check if directory exists and is readable
dir_exists() {
    local dir="$1"
    [[ -d "$dir" && -r "$dir" ]]
}

# Get file size in bytes
file_size() {
    local file="$1"
    stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
}

# Calculate SHA256 hash of file
file_hash() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # macOS uses shasum, Linux uses sha256sum
        if command_exists shasum; then
            shasum -a 256 "$file" | awk '{print $1}'
        elif command_exists sha256sum; then
            sha256sum "$file" | awk '{print $1}'
        else
            error "No SHA256 tool available (shasum or sha256sum)"
            return $EXIT_ERROR
        fi
    fi
}

# Parse command line arguments into key=value pairs
# Usage: parse_args --key value --flag
parse_args() {
    local args=("$@")
    declare -gA PARSED_ARGS=()
    
    local i=0
    while [[ $i -lt ${#args[@]} ]]; do
        local arg="${args[$i]}"
        
        if [[ "$arg" =~ ^-- ]]; then
            local key="${arg#--}"
            local value=""
            
            # Check if next argument is a value (doesn't start with --)
            if [[ $((i + 1)) -lt ${#args[@]} && ! "${args[$((i + 1))]}" =~ ^-- ]]; then
                value="${args[$((i + 1))]}"
                ((i += 2))
            else
                # Flag without value (boolean)
                value="true"
                ((i += 1))
            fi
            
            PARSED_ARGS["$key"]="$value"
        else
            ((i += 1))
        fi
    done
}

# Get parsed argument value
get_arg() {
    local key="$1"
    local default="${2:-}"
    echo "${PARSED_ARGS[$key]:-$default}"
}

# Check if argument was provided
has_arg() {
    local key="$1"
    [[ -n "${PARSED_ARGS[$key]:-}" ]]
}

# Validate required arguments
require_args() {
    local -a required=("$@")
    local -a missing=()
    
    for arg in "${required[@]}"; do
        if ! has_arg "$arg"; then
            missing+=("$arg")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required arguments: ${missing[*]}"
        return $EXIT_INVALID_ARGS
    fi
    
    return $EXIT_SUCCESS
}

# Print error with usage info
print_usage_error() {
    local message="$1"
    error "$message"
    error "Use '--help' or '-h' for usage information"
}

# Retry function with exponential backoff
# Usage: retry 3 2 "description" command arg1 arg2
retry() {
    local max_attempts="$1"
    local initial_delay="$2"
    local description="$3"
    shift 3
    local -a cmd=("$@")
    
    local attempt=1
    local delay=$initial_delay
    
    while [[ $attempt -le $max_attempts ]]; do
        debug "Attempt $attempt/$max_attempts: $description"
        
        if "${cmd[@]}"; then
            debug "Success on attempt $attempt"
            return $EXIT_SUCCESS
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            warn "Attempt $attempt failed for: $description. Retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi
        
        ((attempt++))
    done
    
    error "Failed after $max_attempts attempts: $description"
    return $EXIT_ERROR
}

# Check if running in dry-run mode
is_dry_run() {
    [[ "${DRY_RUN:-0}" == "1" ]]
}

# Execute command, respecting dry-run mode
execute() {
    local description="$1"
    shift
    local -a cmd=("$@")
    
    if is_dry_run; then
        info "[DRY-RUN] Would execute: ${cmd[*]}"
        return $EXIT_SUCCESS
    else
        debug "Executing: ${cmd[*]}"
        "${cmd[@]}"
    fi
}

export SCRIPT_DIR LIB_DIR DEPLOY_DIR TESTS_DIR CFN_DIR LOG_DIR
export APP_NAME APP_VERSION SCRIPT_NAME
export EXIT_SUCCESS EXIT_ERROR EXIT_INVALID_ARGS EXIT_AWS_ERROR EXIT_VALIDATION_ERROR EXIT_TIMEOUT
