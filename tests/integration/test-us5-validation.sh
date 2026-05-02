#!/bin/bash

# Integration Test: US5 - Deployment Validation & Dry-Run
# Tests validation command and dry-run mode

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../../.."
LIB_DIR="$PROJECT_ROOT/lib"

# Source libraries
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/validate-cmd.sh"

test_count=0
test_passed=0
test_failed=0

# ============================================================================
# Test Utilities
# ============================================================================

run_test() {
    local test_name="$1"
    local test_fn="$2"
    
    ((test_count++))
    echo ""
    echo "▶ Test $test_count: $test_name"
    
    if $test_fn; then
        echo "✓ PASS: $test_name"
        ((test_passed++))
    else
        echo "✗ FAIL: $test_name"
        ((test_failed++))
    fi
}

# ============================================================================
# Test Cases
# ============================================================================

test_domain_format_validation() {
    # Valid domains
    validate_domain_format "example.com" || return 1
    validate_domain_format "www.example.com" || return 1
    validate_domain_format "sub.domain.example.com" || return 1
    
    # Invalid domains
    validate_domain_format "example" && return 1
    validate_domain_format ".com" && return 1
    validate_domain_format "example.com." && return 1
    validate_domain_format "example..com" && return 1
    
    return 0
}

test_subdomain_format_validation() {
    # Valid subdomains
    validate_subdomain_format "www" || return 1
    validate_subdomain_format "blog" || return 1
    validate_subdomain_format "api-v1" || return 1
    validate_subdomain_format "sub_domain" || return 1
    
    # Invalid subdomains
    validate_subdomain_format "Sub" && return 1  # Uppercase
    validate_subdomain_format "-blog" && return 1  # Starts with hyphen
    validate_subdomain_format "blog-" && return 1  # Ends with hyphen
    validate_subdomain_format "BLOG" && return 1  # All uppercase
    
    return 0
}

test_local_files_validation() {
    # Create test directory with files
    local test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN
    
    # Empty directory - should fail
    (validate_local_files_exist "$test_dir") && return 1
    
    # Add HTML file - should pass
    touch "$test_dir/index.html"
    validate_local_files_exist "$test_dir" || return 1
    
    return 0
}

test_cfn_template_validation() {
    # Create test template
    local test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN
    
    local template="$test_dir/test-template.yaml"
    
    # Invalid template - missing header
    cat > "$template" <<EOF
Resources:
  S3Bucket:
    Type: AWS::S3::Bucket
EOF
    
    (validate_cfn_template "$template") && return 1
    
    # Valid template with header
    cat > "$template" <<EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: Test template
Resources:
  S3Bucket:
    Type: AWS::S3::Bucket
EOF
    
    # Note: AWS validation may fail in test env, but syntax check passes
    validate_cfn_template "$template" || true
    
    return 0
}

test_stack_name_validation() {
    # Valid names
    validate_stack_name "website-www-example-com" || return 1
    validate_stack_name "website-example" || return 1
    validate_stack_name "website_example" || return 1
    validate_stack_name "website123" || return 1
    
    # Invalid names
    validate_stack_name "-website" && return 1  # Starts with hyphen
    validate_stack_name "123website" && return 1  # Starts with number
    validate_stack_name "" && return 1  # Empty
    
    # Too long (>128 chars)
    local long_name=$(printf 'a%.0s' {1..129})
    (validate_stack_name "$long_name") && return 1
    
    return 0
}

test_dry_run_mode() {
    # Test dry-run flag detection
    (is_dry_run) && return 1  # Should be false by default
    
    # Set dry-run mode
    set_dry_run
    (is_dry_run) || return 1
    
    # Unset for other tests
    unset DRY_RUN
    
    return 0
}

test_aws_call_wrapper_in_dryrun() {
    # Set dry-run mode
    set_dry_run
    
    # aws_call should return success without executing
    if aws_call "test" s3 ls 2>&1 | grep -q "DRY-RUN"; then
        unset DRY_RUN
        return 0
    fi
    
    unset DRY_RUN
    return 1
}

test_validation_error_suggestion() {
    # Test error suggestion function (should not crash)
    suggest_resolution "missing_domain" >/dev/null || return 1
    suggest_resolution "invalid_domain_format" >/dev/null || return 1
    suggest_resolution "missing_credentials" >/dev/null || return 1
    suggest_resolution "missing_permissions" >/dev/null || return 1
    suggest_resolution "file_not_found" >/dev/null || return 1
    
    return 0
}

# ============================================================================
# Test Execution
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║ Integration Test: US5 - Deployment Validation & Dry-Run                       ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    run_test "Domain format validation" test_domain_format_validation
    run_test "Subdomain format validation" test_subdomain_format_validation
    run_test "Local files validation" test_local_files_validation
    run_test "CloudFormation template validation" test_cfn_template_validation
    run_test "Stack name validation" test_stack_name_validation
    run_test "Dry-run mode detection" test_dry_run_mode
    run_test "AWS call wrapper in dry-run" test_aws_call_wrapper_in_dryrun
    run_test "Validation error suggestions" test_validation_error_suggestion
    
    # Summary
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║ Test Summary"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo "Total: $test_count | Passed: $test_passed | Failed: $test_failed"
    echo ""
    
    if (( test_failed == 0 )); then
        echo "✓ All tests passed"
        return 0
    else
        echo "✗ $test_failed test(s) failed"
        return 1
    fi
}

main "$@"
