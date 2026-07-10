#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Validate Command Implementation                                            ║
# ║  Phase 7: User Story 5 - Deployment Validation (Tasks T054-T059)            ║
# ║  Handles comprehensive pre-flight validation and dry-run mode                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ============================================================================
# T054: Dry-Run Flag Handling Across All Commands
# ============================================================================

is_dry_run() {
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        return 0
    fi
    return 1
}

set_dry_run() {
    export DRY_RUN=1
    info "[DRY-RUN MODE] No AWS resources will be modified"
}

# Wrapper function for AWS API calls - skip in dry-run mode
aws_call() {
    local operation="$1"
    shift
    
    if is_dry_run; then
        debug "[DRY-RUN] Skipping AWS operation: $operation $@"
        return 0
    fi
    
    aws "$@"
}

s3_call() {
    if is_dry_run; then
        debug "[DRY-RUN] Skipping S3 operation: $@"
        return 0
    fi
    
    aws s3 "$@"
}

cfn_call() {
    if is_dry_run; then
        debug "[DRY-RUN] Skipping CloudFormation operation: $@"
        return 0
    fi
    
    aws cloudformation "$@"
}

cf_call() {
    if is_dry_run; then
        debug "[DRY-RUN] Skipping CloudFront operation: $@"
        return 0
    fi
    
    aws cloudfront "$@"
}

r53_call() {
    if is_dry_run; then
        debug "[DRY-RUN] Skipping Route53 operation: $@"
        return 0
    fi
    
    aws route53 "$@"
}

# ============================================================================
# T055 & T056: Comprehensive Pre-Flight Validation
# ============================================================================

run_comprehensive_validation() {
    local domain="$1"
    local subdomain="$2"
    local region="$3"
    local source_dir="$4"
    local aws_profile="$5"
    
    info "Running comprehensive pre-flight validation"
    echo ""
    
    local validation_passed=0
    local validation_failed=0
    
    # 1. AWS Credentials validation
    echo "Checking AWS credentials..."
    if validate_aws_credentials "$aws_profile"; then
        success "✓ AWS credentials valid"
        ((validation_passed++))
    else
        error "✗ AWS credentials invalid or missing"
        ((validation_failed++))
    fi
    echo ""
    
    # 2. Domain format validation
    echo "Validating domain format..."
    if validate_domain_format "$domain"; then
        success "✓ Domain format valid: $domain"
        ((validation_passed++))
    else
        error "✗ Invalid domain format: $domain (must be valid FQDN)"
        ((validation_failed++))
    fi
    echo ""
    
    # 3. Subdomain format validation
    echo "Validating subdomain format..."
    if validate_subdomain_format "$subdomain"; then
        success "✓ Subdomain format valid: $subdomain"
        ((validation_passed++))
    else
        error "✗ Invalid subdomain format: $subdomain"
        ((validation_failed++))
    fi
    echo ""
    
    # 4. Source directory validation
    echo "Validating source directory..."
    if [[ -d "$source_dir" ]]; then
        success "✓ Source directory exists: $source_dir"
        ((validation_passed++))
    else
        error "✗ Source directory not found: $source_dir"
        ((validation_failed++))
    fi
    echo ""
    
    # 5. Local files validation
    echo "Scanning local files..."
    if validate_local_files_exist "$source_dir"; then
        success "✓ Valid website files found in $source_dir"
        ((validation_passed++))
    else
        error "✗ No valid website files found in $source_dir"
        ((validation_failed++))
    fi
    echo ""
    
    # 6. IAM permissions validation
    echo "Checking IAM permissions..."
    if validate_iam_permissions "$aws_profile"; then
        success "✓ Required IAM permissions available"
        ((validation_passed++))
    else
        error "✗ Missing required IAM permissions"
        warn "  Required permissions: s3:*, cloudformation:*, cloudfront:*, route53:*, acm:*"
        ((validation_failed++))
    fi
    echo ""
    
    # 7. CloudFormation template validation
    echo "Validating CloudFormation template..."
    if validate_cfn_template "cloud/s3-static-website-validate.yaml"; then
        success "✓ CloudFormation template valid"
        ((validation_passed++))
    else
        error "✗ CloudFormation template has syntax errors"
        ((validation_failed++))
    fi
    echo ""
    
    # 8. Region availability validation
    echo "Checking region availability..."
    if validate_region_availability "$region" "$aws_profile"; then
        success "✓ Region is available: $region"
        ((validation_passed++))
    else
        error "✗ Region not available or not accessible: $region"
        ((validation_failed++))
    fi
    echo ""
    
    # 9. Stack naming validation
    echo "Validating stack name..."
    local stack_name="website-${subdomain}-${domain//./}-stack"
    stack_name="${stack_name:0:128}"  # Limit to 128 chars per CloudFormation spec
    
    if validate_stack_name "$stack_name"; then
        success "✓ Stack name valid: $stack_name"
        ((validation_passed++))
    else
        error "✗ Invalid stack name: $stack_name"
        ((validation_failed++))
    fi
    echo ""
    
    # 10. Existing stack check
    echo "Checking for existing deployment..."
    if stack_already_exists "$stack_name" "$region" "$aws_profile"; then
        warn "⊳ Stack already exists (will update existing stack)"
    else
        success "✓ No existing deployment found (will create new stack)"
    fi
    echo ""
    
    # Summary
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║ Validation Summary"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo "Passed: $validation_passed"
    echo "Failed: $validation_failed"
    echo ""
    
    if (( validation_failed == 0 )); then
        success "✓ All validation checks passed"
        return 0
    else
        error "✗ $validation_failed validation check(s) failed"
        return 1
    fi
}

validate_domain_format() {
    local domain="$1"
    
    # RFC 1123 domain validation
    if [[ $domain =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    
    return 1
}

validate_subdomain_format() {
    local subdomain="$1"
    
    if [[ $subdomain =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
        return 0
    fi
    
    return 1
}

validate_local_files_exist() {
    local source_dir="$1"
    
    # Check for at least one HTML file or common web file
    if find "$source_dir" -maxdepth 2 \( -name "*.html" -o -name "*.css" -o -name "*.js" \) -print -quit 2>/dev/null | grep -q .; then
        return 0
    fi
    
    return 1
}

validate_cfn_template() {
    local template_file="$1"
    
    if [[ ! -f "$template_file" ]]; then
        error "CloudFormation template not found: $template_file"
        return 1
    fi
    
    # Basic YAML syntax validation
    if ! grep -q "AWSTemplateFormatVersion" "$template_file"; then
        error "Template missing AWSTemplateFormatVersion"
        return 1
    fi
    
    # Try to validate with AWS CLI if not in dry-run mode
    if ! is_dry_run; then
        aws cloudformation validate-template \
            --template-body "file://$template_file" \
            --profile "${AWS_PROFILE:-default}" \
            >/dev/null 2>&1
        
        if (( $? != 0 )); then
            return 1
        fi
    fi
    
    return 0
}

validate_region_availability() {
    local region="$1"
    local aws_profile="$2"
    
    if is_dry_run; then
        return 0
    fi
    
    # Check if region is valid
    aws ec2 describe-regions \
        --region-names "$region" \
        --profile "$aws_profile" \
        >/dev/null 2>&1
    
    return $?
}

validate_stack_name() {
    local stack_name="$1"
    
    # CloudFormation stack name rules:
    # - Max 128 characters
    # - Can contain alphanumerics, hyphens, and underscores
    # - Must start with alphanumeric
    if [[ $stack_name =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,126}$ ]]; then
        return 0
    fi
    
    return 1
}

stack_already_exists() {
    local stack_name="$1"
    local region="$2"
    local aws_profile="$3"
    
    if is_dry_run; then
        return 1
    fi
    
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --profile "$aws_profile" \
        >/dev/null 2>&1
    
    return $?
}

# ============================================================================
# T057: Validate Subcommand
# ============================================================================

validate_command() {
    info "Running deployment validation"
    
    local domain=""
    local subdomain="www"
    local region="us-east-1"
    local source_dir="./"
    local aws_profile="default"
    local output_json=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)
                domain="$2"
                shift 2
                ;;
            --subdomain)
                subdomain="$2"
                shift 2
                ;;
            --region)
                region="$2"
                shift 2
                ;;
            --source-dir)
                source_dir="$2"
                shift 2
                ;;
            --aws-profile)
                aws_profile="$2"
                shift 2
                ;;
            --json)
                output_json=1
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: ./deploy.sh validate [OPTIONS]

Validate deployment configuration before execution.

Options:
  --domain DOMAIN              Domain name (required)
  --subdomain SUBDOMAIN        Subdomain to use (default: www)
  --region REGION              AWS region (default: us-east-1)
  --source-dir DIR             Source directory (default: ./)
  --aws-profile PROFILE        AWS profile (default: default)
  --json                       Output as JSON
  --help, -h                   Show this help message

Examples:
  ./deploy.sh validate --domain example.com
  ./deploy.sh validate --domain example.com --subdomain www --region us-east-1
  ./deploy.sh validate --domain example.com --json

EOF
                return 0
                ;;
            *)
                error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$domain" ]]; then
        error "Missing required argument: --domain"
        return 1
    fi
    
    if (( output_json )); then
        # Run validation silently and output JSON results
        run_comprehensive_validation "$domain" "$subdomain" "$region" "$source_dir" "$aws_profile" >/dev/null 2>&1
        local result=$?
        
        local validation_json=$(cat <<EOF
{
  "valid": $([ $result -eq 0 ] && echo "true" || echo "false"),
  "domain": "$domain",
  "subdomain": "$subdomain",
  "region": "$region",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
        echo "$validation_json" | jq '.'
    else
        # Run full validation with output
        run_comprehensive_validation "$domain" "$subdomain" "$region" "$source_dir" "$aws_profile"
    fi
}

# ============================================================================
# T058: Actionable Error Messages
# ============================================================================

suggest_resolution() {
    local error_code="$1"
    
    case "$error_code" in
        "missing_domain")
            echo "Add --domain parameter: ./deploy.sh deploy --domain example.com"
            ;;
        "invalid_domain_format")
            echo "Domain must be valid FQDN (e.g., example.com, not example or .com)"
            ;;
        "missing_credentials")
            echo "Configure AWS credentials: aws configure --profile default"
            ;;
        "missing_permissions")
            echo "Add this IAM policy to your role:"
            echo "  {
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Action\": [
        \"s3:*\",
        \"cloudformation:*\",
        \"cloudfront:*\",
        \"route53:*\",
        \"acm:*\",
        \"iam:PassRole\"
      ],
      \"Resource\": \"*\"
    }
  ]
}"
            ;;
        "file_not_found")
            echo "Create required files or specify correct source directory: --source-dir"
            ;;
        *)
            echo "Unknown error (code: $error_code)"
            ;;
    esac
}

export -f validate_command
export -f run_comprehensive_validation
export -f validate_domain_format
export -f validate_subdomain_format
export -f validate_local_files_exist
export -f validate_cfn_template
export -f validate_region_availability
export -f validate_stack_name
export -f stack_already_exists
export -f suggest_resolution
export -f is_dry_run
export -f set_dry_run
export -f aws_call
export -f s3_call
export -f cfn_call
export -f cf_call
export -f r53_call
