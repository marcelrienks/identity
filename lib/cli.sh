#!/bin/bash

# CLI command routing and subcommand dispatcher
# Provides: Command parsing, help text, subcommand routing

# Global command registry
declare -A COMMANDS=()

# Register a command
register_command() {
    local cmd_name="$1"
    local cmd_func="$2"
    local cmd_help="$3"
    
    COMMANDS["$cmd_name"]="$cmd_func"
}

# Show help for all commands
show_help() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════════╗
║                  AWS Static Website Deployment Tool                        ║
║                                                                            ║
║  Unified deployment and management for static websites on AWS S3 with     ║
║  CloudFront CDN and Route 53 DNS. Includes infrastructure provisioning,   ║
║  content updates, rollback, and version management via CloudFormation.    ║
╚════════════════════════════════════════════════════════════════════════════╝

USAGE:
  ./deploy.sh COMMAND [OPTIONS]

COMMANDS:
  deploy        Provision AWS infrastructure and deploy initial website
  update        Upload modified website files to live S3 bucket
  rollback      Revert website to previous version
  versions      Manage and view deployment versions
  validate      Validate configuration and permissions (dry-run)
  status        Check current deployment status
  destroy       Delete AWS infrastructure and resources (CAUTION)
  help          Show this help message

OPTIONS (common):
  --domain DOMAIN              Domain name (e.g., example.com)
  --subdomain DOMAIN           Subdomain (e.g., www; default: www)
  --region REGION              AWS region (default: us-east-1)
  --source-dir PATH            Source directory with website files (default: ./)
  --aws-profile PROFILE        AWS CLI profile to use (default: default)
  --certificate-arn ARN        Use existing ACM certificate (auto-provision if empty)
  --s3-bucket-name NAME        Use existing S3 bucket (auto-create if empty)
  --cloudfront-distribution-id ID  Use existing CloudFront distribution (auto-create if empty)
  --dry-run                    Validate without making AWS changes
  --verbose, -v                Enable verbose output (debug logging)
  --help, -h                   Show detailed help for command

EXAMPLES:

  # Deploy website to www.example.com (first time)
  ./deploy.sh deploy --domain example.com --subdomain www --source-dir ./website

  # Update website content after changes
  ./deploy.sh update

  # Show available versions
  ./deploy.sh versions --list

  # Rollback to specific version
  ./deploy.sh rollback --version 20260501-143022

  # Validate configuration without making changes
  ./deploy.sh validate --domain example.com

  # Check deployment status
  ./deploy.sh status

  # Remove all AWS resources (careful!)
  ./deploy.sh destroy --confirm

DOCUMENTATION:
  Configuration file: .deployrc (YAML format, see .deployrc.example)
  AWS credentials: Set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, or use IAM role
  Log file location: logs/deploy.sh.log

For more information, see: https://github.com/example/deploy#readme
EOF
}

# Show help for specific command
show_command_help() {
    local cmd="$1"
    
    case "$cmd" in
        deploy)
            cat << 'EOF'
DEPLOY - Provision AWS infrastructure and deploy initial website

SYNTAX:
  ./deploy.sh deploy [OPTIONS]

DESCRIPTION:
  Creates a complete AWS infrastructure stack (S3, CloudFront, Route53, ACM)
  via CloudFormation and uploads initial website content.

  This is a one-time operation to set up a new website. For updates to
  existing websites, use the 'update' command.

  Each AWS resource can be auto-provisioned (default) or use an existing
  resource by providing its ID/ARN.

REQUIRED OPTIONS:
  --domain DOMAIN              Website domain (e.g., example.com)

OPTIONAL OPTIONS:
  --subdomain SUBDOMAIN        Subdomain to deploy (default: www)
                              Example: --subdomain blog deploys blog.example.com
  --region REGION              AWS region (default: us-east-1)
                              Must be us-east-1 for CloudFront + ACM
  --source-dir PATH            Source directory (default: ./)
  --aws-profile PROFILE        AWS CLI profile (default: default)

RESOURCE OVERRIDES (auto-provision if not provided):
  --certificate-arn ARN        Use existing ACM certificate
                              Format: arn:aws:acm:us-east-1:123456789012:certificate/abc123
  --s3-bucket-name NAME        Use existing S3 bucket
                              Example: --s3-bucket-name my-website-bucket
  --cloudfront-distribution-id ID  Use existing CloudFront distribution
                              Format: E1234ABCD5FGH

FLAGS:
  --dry-run                    Validate without making changes
  --verbose, -v                Verbose output

EXAMPLES:
  # Auto-provision all resources (default)
  ./deploy.sh deploy --domain example.com

  # Use existing certificate, auto-provision others
  ./deploy.sh deploy --domain example.com \
    --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/abc123

  # Use existing S3 bucket and certificate
  ./deploy.sh deploy --domain example.com \
    --s3-bucket-name my-bucket \
    --certificate-arn arn:aws:acm:...

  # Use all existing resources
  ./deploy.sh deploy --domain example.com \
    --certificate-arn arn:aws:acm:... \
    --s3-bucket-name my-bucket \
    --cloudfront-distribution-id E1234ABCD5FGH

  # Deploy custom subdomain
  ./deploy.sh deploy --domain example.com --subdomain blog --source-dir ./blog-content

  # Validate before deploying
  ./deploy.sh deploy --domain example.com --dry-run --verbose

AUTO-PROVISIONED RESOURCES (if not overridden):
  - S3 bucket (with versioning enabled)
  - CloudFront distribution with OAC
  - Route 53 DNS alias record
  - ACM SSL/TLS certificate with auto-renewal
  - CloudFormation stack

FINDING AWS RESOURCE IDs:
  # List ACM certificates
  aws acm list-certificates --region us-east-1

  # List S3 buckets
  aws s3 ls

  # List CloudFront distributions
  aws cloudfront list-distributions | \
    jq '.DistributionList.Items[] | {Id, DomainName}'

EOF
            ;;
        
        update)
            cat << 'EOF'
UPDATE - Upload modified website files to live S3 bucket

SYNTAX:
  ./deploy.sh update [OPTIONS]

DESCRIPTION:
  Detects changes to local website files and uploads them to S3.
  Automatically invalidates CloudFront cache to publish changes.

  Requires prior deployment with 'deploy' command.

OPTIONS:
  --subdomain SUBDOMAIN    Subdomain to update (default: all)
  --source-dir PATH        Source directory (default: ./)
  --dry-run                Show what would be uploaded without uploading
  --verbose, -v            Verbose output

EXAMPLES:
  # Update website content
  ./deploy.sh update

  # Update specific subdomain only
  ./deploy.sh update --subdomain blog

  # Preview changes
  ./deploy.sh update --dry-run

BEHAVIOR:
  - Only changed files are uploaded (not already uploaded)
  - Upload resumes from last checkpoint if interrupted
  - CloudFront cache invalidated automatically
  - Changes live within 1-2 minutes

EOF
            ;;
        
        rollback)
            cat << 'EOF'
ROLLBACK - Revert website to previous version

SYNTAX:
  ./deploy.sh rollback [VERSION_ID] [OPTIONS]

DESCRIPTION:
  Restores website content to a previous deployment version.
  Versions are automatically created with each deploy/update.

OPTIONS:
  VERSION_ID               Specific version to restore (e.g., 20260501-143022)
                          If omitted, rolls back to previous version
  --confirm               Skip confirmation prompt (for automation)
  --verbose, -v          Verbose output

EXAMPLES:
  # Rollback to previous version
  ./deploy.sh rollback

  # Rollback to specific version
  ./deploy.sh rollback 20260501-143022

  # List available versions
  ./deploy.sh versions --list

EOF
            ;;
        
        versions)
            cat << 'EOF'
VERSIONS - Manage and view deployment versions

SYNTAX:
  ./deploy.sh versions SUBCOMMAND [OPTIONS]

SUBCOMMANDS:
  --list                 List all available versions
  --show VERSION_ID      Show details of specific version

OPTIONS:
  --limit N              Show last N versions (default: 20)
  --json                 Output as JSON
  --verbose, -v          Verbose output

EXAMPLES:
  # List all versions
  ./deploy.sh versions --list

  # Show last 5 versions
  ./deploy.sh versions --list --limit 5

  # Show files in specific version
  ./deploy.sh versions --show 20260501-143022

  # Get versions as JSON
  ./deploy.sh versions --list --json

EOF
            ;;
        
        validate)
            cat << 'EOF'
VALIDATE - Check configuration and AWS permissions

SYNTAX:
  ./deploy.sh validate [OPTIONS]

DESCRIPTION:
  Validates:
  - AWS credentials are valid
  - Required IAM permissions are present
  - Domain name format is valid
  - Configuration file (if present) is valid
  - Source directory and files are readable
  
  Does NOT make any changes to AWS.

OPTIONS:
  --domain DOMAIN        Domain to validate
  --source-dir PATH      Source directory to validate
  --verbose, -v          Verbose output

EXAMPLES:
  ./deploy.sh validate --domain example.com
  ./deploy.sh validate --domain example.com --source-dir ./website

EOF
            ;;
        
        status)
            cat << 'EOF'
STATUS - Check current deployment status

SYNTAX:
  ./deploy.sh status [OPTIONS]

DESCRIPTION:
  Shows:
  - Current CloudFormation stack status
  - S3 bucket and object count
  - CloudFront distribution status
  - Route 53 DNS records
  - Current version
  - Last deployment time

OPTIONS:
  --json                 Output as JSON
  --verbose, -v          Verbose output

EXAMPLES:
  ./deploy.sh status
  ./deploy.sh status --json

EOF
            ;;
        
        destroy)
            cat << 'EOF'
DESTROY - Delete AWS infrastructure and resources

SYNTAX:
  ./deploy.sh destroy [OPTIONS]

DESCRIPTION:
  CAUTION: This operation permanently deletes all AWS resources created
  by deploy command, including:
  - CloudFormation stack
  - S3 bucket (and all objects/versions)
  - CloudFront distribution
  - Route 53 records
  - ACM certificate

  This action cannot be undone.

OPTIONS:
  --confirm              Required. Confirm deletion without prompting
  --verbose, -v          Verbose output

EXAMPLES:
  # Delete all resources (with confirmation prompt)
  ./deploy.sh destroy

  # Delete without prompting (dangerous!)
  ./deploy.sh destroy --confirm

EOF
            ;;
        
        *)
            error "Unknown command: $cmd"
            echo "Use './deploy.sh help' for available commands"
            return 1
            ;;
    esac
}

# Get the main command from arguments
get_command() {
    local arg="${1:-}"
    
    # Remove leading dashes for help/version flags
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        echo "help"
    elif [[ "$arg" == "-v" && "$arg" != "--verbose" ]]; then
        echo "version"
    else
        echo "$arg"
    fi
}

# Check if command is registered
is_valid_command() {
    local cmd="$1"
    [[ -n "${COMMANDS[$cmd]:-}" ]]
}

# Execute command by name
execute_command() {
    local cmd="$1"
    shift
    
    if [[ "$cmd" == "help" ]]; then
        if [[ -n "${1:-}" ]]; then
            show_command_help "$1"
        else
            show_help
        fi
        return $EXIT_SUCCESS
    fi
    
    if ! is_valid_command "$cmd"; then
        error "Unknown command: $cmd"
        echo "Use './deploy.sh help' for available commands"
        return $EXIT_INVALID_ARGS
    fi
    
    # Execute the command function
    local cmd_func="${COMMANDS[$cmd]}"
    "$cmd_func" "$@"
}

export COMMANDS
