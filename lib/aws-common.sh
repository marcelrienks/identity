#!/bin/bash

# AWS-common utilities for credential validation, permission checking, and security
# Provides: AWS CLI detection, credential validation, IAM permission checking, secrets scanning

# AWS CLI version requirement
readonly AWS_CLI_MIN_VERSION="2.0.0"

# Required AWS permissions for deployments
declare -ra AWS_REQUIRED_PERMISSIONS=(
    "s3:CreateBucket"
    "s3:GetBucketVersioning"
    "s3:PutBucketVersioning"
    "s3:PutObject"
    "s3:GetObject"
    "s3:ListBucket"
    "cloudformation:CreateStack"
    "cloudformation:UpdateStack"
    "cloudformation:DescribeStacks"
    "cloudformation:DescribeStackEvents"
    "cloudformation:GetTemplate"
    "cloudfront:CreateDistribution"
    "cloudfront:UpdateDistribution"
    "cloudfront:GetDistribution"
    "cloudfront:CreateInvalidation"
    "cloudfront:GetInvalidation"
    "route53:GetHostedZone"
    "route53:ListHostedZones"
    "route53:ChangeResourceRecordSets"
    "route53:ListResourceRecordSets"
    "acm:RequestCertificate"
    "acm:DescribeCertificate"
    "acm:ListCertificates"
    "iam:PassRole"
)

# Patterns for secret detection (regex)
declare -ra SECRET_PATTERNS=(
    '\.(pem|key|pkcs12|p12|pfx)$'  # Private key files
    '\.env[^/]*$'                  # .env, .env.local, etc.
    '(^|/)\.env[^/]*$'             # .env files anywhere
    '(password|passwd)'             # password field
    '(api_key|apikey)'              # API key field
    '(secret|token)'                # secret/token field
    '(credential|aws_access_key_id|aws_secret_access_key)'  # AWS credentials
    '(AKIA[0-9A-Z]{16})'            # AWS Access Key pattern
)

# Detect AWS CLI v2 installation
check_aws_cli() {
    if ! command_exists aws; then
        error "AWS CLI v2 is not installed"
        error "Install from: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        return $EXIT_ERROR
    fi
    
    # Check version
    local version
    version=$(aws --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [[ -z "$version" ]]; then
        error "Could not determine AWS CLI version"
        return $EXIT_ERROR
    fi
    
    debug "AWS CLI version: $version"
    
    # Basic version check (just verify major version is 2)
    if [[ ! "$version" =~ ^2\. ]]; then
        error "AWS CLI v2 is required (found version $version)"
        error "Install from: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        return $EXIT_ERROR
    fi
    
    success "AWS CLI v2 detected: $version"
    return $EXIT_SUCCESS
}

# Validate AWS credentials (basic check that credentials are configured)
check_aws_credentials() {
    local aws_profile="${1:-${AWS_PROFILE:-default}}"
    
    debug "Checking AWS credentials for profile: $aws_profile"
    
    # Try to get caller identity to verify credentials work
    if ! aws sts get-caller-identity --profile "$aws_profile" > /dev/null 2>&1; then
        error "AWS credentials validation failed"
        error "Check that:"
        error "  1. AWS credentials are configured (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
        error "  2. Profile '$aws_profile' exists"
        error "  3. Credentials have not expired"
        error "Run 'aws configure' to set up credentials"
        return $EXIT_AWS_ERROR
    fi
    
    # Get caller identity info
    local identity
    identity=$(aws sts get-caller-identity --profile "$aws_profile" 2>/dev/null)
    
    local account
    local arn
    account=$(echo "$identity" | jq -r '.Account' 2>/dev/null || echo "unknown")
    arn=$(echo "$identity" | jq -r '.Arn' 2>/dev/null || echo "unknown")
    
    success "AWS credentials valid"
    debug "  Account: $account"
    debug "  ARN: $arn"
    
    return $EXIT_SUCCESS
}

# Check if specific S3 bucket name is available (globally unique)
check_s3_bucket_available() {
    local bucket_name="$1"
    local aws_profile="${2:-${AWS_PROFILE:-default}}"
    
    debug "Checking S3 bucket availability: $bucket_name"
    
    # Try to access the bucket (will fail if doesn't exist or we don't have access)
    if aws s3 ls "s3://$bucket_name" --profile "$aws_profile" > /dev/null 2>&1; then
        error "S3 bucket already exists: $bucket_name"
        error "Bucket names must be globally unique across all AWS accounts"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # If bucket doesn't exist, check if name is valid (before creating)
    # Valid bucket names: 3-63 chars, lowercase alphanumeric and hyphens
    if ! [[ "$bucket_name" =~ ^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])?$ ]]; then
        error "Invalid S3 bucket name: $bucket_name"
        error "Bucket names must be:"
        error "  - 3-63 characters long"
        error "  - Lowercase alphanumeric and hyphens only"
        error "  - Start and end with letter or number"
        return $EXIT_VALIDATION_ERROR
    fi
    
    success "S3 bucket name available: $bucket_name"
    return $EXIT_SUCCESS
}

# Simulate IAM policy evaluation (basic check for critical permissions)
# Note: This is a simplified check - AWS IAM policies can be complex
check_iam_permissions() {
    local aws_profile="${1:-${AWS_PROFILE:-default}}"
    
    debug "Checking IAM permissions (this is a basic check)"
    
    # Get current user/role
    local principal_arn
    principal_arn=$(aws sts get-caller-identity --profile "$aws_profile" 2>/dev/null | jq -r '.Arn')
    
    if [[ -z "$principal_arn" || "$principal_arn" == "null" ]]; then
        error "Could not determine IAM principal"
        return $EXIT_AWS_ERROR
    fi
    
    debug "Principal: $principal_arn"
    
    # Note: AWS IAM policy simulation is complex. A production implementation would use:
    # aws iam simulate-principal-policy --policy-source-arn "$principal_arn" \
    #     --action-names s3:PutObject cloudformation:CreateStack ... \
    #     --resource-arns arn:aws:s3:::/* arn:aws:cloudformation:*:*:stack/* ...
    
    # For now, we'll do a simple check: try to describe a non-existent stack
    # If we get an access denied error, permissions are insufficient
    if aws cloudformation describe-stacks --stack-name nonexistent-stack --profile "$aws_profile" 2>&1 | grep -q "AccessDenied"; then
        error "Insufficient IAM permissions"
        error "User/role needs permissions for: ${AWS_REQUIRED_PERMISSIONS[@]}"
        return $EXIT_AWS_ERROR
    fi
    
    info "Basic IAM permission check passed (not comprehensive)"
    debug "For detailed permissions analysis, use AWS Access Analyzer"
    
    return $EXIT_SUCCESS
}

# Scan file for secret patterns (T005a)
scan_file_for_secrets() {
    local file="$1"
    local -a found_patterns=()

    if [[ ! -f "$file" ]]; then
        return $EXIT_SUCCESS
    fi

    # Skip non-secret filetypes
    case "$file" in
        *.js.map|*.css.map|*.json|*.woff|*.woff2|*.ttf|*.otf|*.png|*.jpg|*.gif|*.webp|*.ico)
            return $EXIT_SUCCESS
            ;;
    esac

    # Check filename patterns
    for pattern in "${SECRET_PATTERNS[@]}"; do
        if [[ "$file" =~ $pattern ]]; then
            found_patterns+=("$pattern")
        fi
    done

    # Check file content patterns (for some secrets)
    # Look for common secret markers in file content - only in text files
    if [[ "$file" == *.sh ]] || [[ "$file" == *.md ]] || [[ "$file" == *.yaml ]] || [[ "$file" == *.yml ]] || [[ "$file" == *.html ]]; then
        if grep -qi "private.key\|-----BEGIN\|password.*=\|api.key\|secret.key\|AKIA[A-Z0-9]\{16\}" "$file" 2>/dev/null; then
            found_patterns+=("suspicious_content")
        fi
    fi

    if [[ ${#found_patterns[@]} -gt 0 ]]; then
        return 1  # Found secrets
    fi

    return 0  # No secrets found
}

# Validate all files for secrets before upload (T005a)
validate_files_for_secrets() {
    local source_dir="${1:-.}"
    local -a files_with_secrets=()

    section "Scanning files for secrets"

    # Find only files that will be uploaded (matching include patterns)
    while IFS= read -r file; do
        if scan_file_for_secrets "$file"; then
            # No secrets
            debug "✓ $file"
        else
            # Found secrets
            warn "Potential secrets detected: $file"
            files_with_secrets+=("$file")
        fi
    done < <(find_files_to_upload "$source_dir")
    
    if [[ ${#files_with_secrets[@]} -gt 0 ]]; then
        error "Files containing potential secrets detected:"
        for file in "${files_with_secrets[@]}"; do
            error "  - $file"
        done
        error ""
        error "SECURITY ALERT: Do not deploy files with secrets!"
        error ""
        error "To fix:"
        error "  1. Remove the secrets from files"
        error "  2. Add files to .deployignore if they should not be deployed"
        error "  3. Use environment variables for secrets instead"
        error ""
        error "Examples of secrets to remove:"
        error "  - Private keys (.pem, .key files)"
        error "  - .env files with credentials"
        error "  - AWS access keys"
        error "  - API tokens"
        error "  - Database passwords"
        
        return $EXIT_VALIDATION_ERROR
    fi
    
    success "No secrets detected in files"
    return $EXIT_SUCCESS
}

# Deployment pre-flight checks
run_preflight_checks() {
    local aws_profile="${1:-${AWS_PROFILE:-default}}"
    
    section "Running pre-flight checks"
    
    # Check AWS CLI
    if ! check_aws_cli; then
        return $EXIT_ERROR
    fi
    
    # Check AWS credentials
    if ! check_aws_credentials "$aws_profile"; then
        return $EXIT_AWS_ERROR
    fi
    
    # Check IAM permissions (basic)
    if ! check_iam_permissions "$aws_profile"; then
        warn "Permission check indicated possible issues (but proceeding)"
    fi
    
    success "Pre-flight checks completed"
    return $EXIT_SUCCESS
}

export AWS_CLI_MIN_VERSION AWS_REQUIRED_PERMISSIONS SECRET_PATTERNS
