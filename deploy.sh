#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                              ║
# ║  AWS Static Website Deployment Tool                                         ║
# ║  Unified deployment and management for static websites on AWS               ║
# ║                                                                              ║
# ║  Usage: ./deploy.sh COMMAND [OPTIONS]                                       ║
# ║  For help: ./deploy.sh help                                                 ║
# ║  Requires: Bash 4.0+ (for associative arrays)                              ║
# ║                                                                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -o pipefail

# Check bash version (need 4.0+ for associative arrays)
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo "ERROR: Bash 4.0+ is required. Current version: $BASH_VERSION"
    echo "macOS users: Install bash 4+ via Homebrew: brew install bash"
    exit 1
fi

# Get script directory for sourcing libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source library modules in correct order (dependencies first)
if [[ ! -f "$LIB_DIR/logging.sh" ]]; then
    echo "ERROR: Library files not found. Expected: $LIB_DIR/"
    echo "Did you forget to initialize the project structure?"
    exit 1
fi

source "$LIB_DIR/logging.sh" || { echo "FATAL: Could not source logging.sh"; exit 1; }
source "$LIB_DIR/common.sh" || { echo "FATAL: Could not source common.sh"; exit 1; }
source "$LIB_DIR/config.sh" || { echo "FATAL: Could not source config.sh"; exit 1; }
source "$LIB_DIR/cli.sh" || { echo "FATAL: Could not source cli.sh"; exit 1; }
source "$LIB_DIR/aws-common.sh" || { echo "FATAL: Could not source aws-common.sh"; exit 1; }
source "$LIB_DIR/cloudformation.sh" || { echo "FATAL: Could not source cloudformation.sh"; exit 1; }
source "$LIB_DIR/s3.sh" || { echo "FATAL: Could not source s3.sh"; exit 1; }
source "$LIB_DIR/cloudfront.sh" || { echo "FATAL: Could not source cloudfront.sh"; exit 1; }
source "$LIB_DIR/route53.sh" || { echo "FATAL: Could not source route53.sh"; exit 1; }
source "$LIB_DIR/file-operations.sh" || { echo "FATAL: Could not source file-operations.sh"; exit 1; }
source "$LIB_DIR/versioning.sh" || { echo "FATAL: Could not source versioning.sh"; exit 1; }
source "$LIB_DIR/validation.sh" || { echo "FATAL: Could not source validation.sh"; exit 1; }
source "$LIB_DIR/state.sh" || { echo "FATAL: Could not source state.sh"; exit 1; }
source "$LIB_DIR/deploy-cmd.sh" || { echo "FATAL: Could not source deploy-cmd.sh"; exit 1; }
source "$LIB_DIR/update-cmd.sh" || { echo "FATAL: Could not source update-cmd.sh"; exit 1; }

# Set log level from environment or default to INFO
export LOG_LEVEL="${LOG_LEVEL:-INFO}"
export DEBUG_MODE=0

# Deploy and update command functions are now defined in deploy-cmd.sh and update-cmd.sh
# The cmd_deploy and cmd_update functions are already sourced above

cmd_rollback() {
    info "Rollback command - Phase 6 implementation"
}

cmd_versions() {
    info "Versions command - Phase 6 implementation"
}

cmd_validate() {
    info "Validate command - Phase 5 implementation"
}

cmd_status() {
    info "Status command - Phase 8 implementation"
}

cmd_destroy() {
    info "Destroy command - Phase 8 implementation"
}

# Register all commands
register_command "deploy" "cmd_deploy" "Provision AWS infrastructure and deploy initial website"
register_command "update" "cmd_update" "Upload modified website files to live S3 bucket"
register_command "rollback" "cmd_rollback" "Revert website to previous version"
register_command "versions" "cmd_versions" "Manage and view deployment versions"
register_command "validate" "cmd_validate" "Validate configuration and permissions (dry-run)"
register_command "status" "cmd_status" "Check current deployment status"
register_command "destroy" "cmd_destroy" "Delete AWS infrastructure and resources"

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Parse global flags
    local -a args=("$@")
    local verbose_flag=0
    
    # Remove verbose flag if present
    for ((i=0; i<${#args[@]}; i++)); do
        case "${args[$i]}" in
            -v|--verbose|--debug)
                verbose_flag=1
                export LOG_LEVEL="DEBUG"
                export DEBUG_MODE=1
                # Remove this argument
                args=("${args[@]:0:$i}" "${args[@]:$((i+1))}")
                ((i--))
                ;;
        esac
    done
    
    # Get command name
    local cmd="${args[0]:-help}"
    
    # Shift to remove command from args
    if [[ ${#args[@]} -gt 0 ]]; then
        args=("${args[@]:1}")
    fi
    
    # Parse remaining arguments
    if [[ ${#args[@]} -gt 0 ]]; then
        load_cli_args "${args[@]}"
    fi
    
    # Load configuration file if it exists
    if [[ -f ".deployrc" ]]; then
        load_config_file ".deployrc"
    fi
    
    # Load environment variables
    load_env_config
    
    # Handle special commands
    case "$cmd" in
        -h|--help|help)
            show_help
            return $EXIT_SUCCESS
            ;;
        
        -v|--version|version)
            echo "$APP_NAME v$APP_VERSION"
            return $EXIT_SUCCESS
            ;;
    esac
    
    # Execute command
    execute_command "$cmd" "${args[@]}"
}

# Ensure main is called with all arguments
main "$@"
exit $?
