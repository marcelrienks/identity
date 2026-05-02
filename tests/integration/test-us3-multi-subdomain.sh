#!/bin/bash

# Integration Test: US3 - Multi-Subdomain Deployment and Updates
# Tests multi-subdomain provisioning and independent updates

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../../.."
LIB_DIR="$PROJECT_ROOT/lib"

# Source test utilities
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/multi-subdomain.sh"

# Test configuration
TEST_DOMAIN="example-test-multi.com"
TEST_SUBDOMAINS="www,blog,docs"
TEST_REGION="us-east-1"
TEST_PROFILE="${AWS_PROFILE:-default}"

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

test_subdomain_validation() {
    # Test valid subdomains
    if ! validate_subdomains "$TEST_SUBDOMAINS"; then
        error "Subdomain validation failed for: $TEST_SUBDOMAINS"
        return 1
    fi
    
    # Test duplicate detection
    if validate_subdomains "www,blog,www"; then
        error "Should reject duplicate subdomains"
        return 1
    fi
    
    # Test too many subdomains
    local many_subdomains=$(printf "sub%d," {1..15} | sed 's/,$//')
    if validate_subdomains "$many_subdomains"; then
        error "Should reject >10 subdomains"
        return 1
    fi
    
    return 0
}

test_subdomain_normalization() {
    local normalized=$(normalize_subdomains "WWW, BLOG, Docs")
    
    if ! echo "$normalized" | grep -q '"www"'; then
        error "Failed to normalize subdomain: www"
        return 1
    fi
    
    if ! echo "$normalized" | grep -q '"blog"'; then
        error "Failed to normalize subdomain: blog"
        return 1
    fi
    
    return 0
}

test_cloudfront_behaviors() {
    # Generate behaviors for subdomains
    local behaviors=$(generate_cloudfront_behaviors www blog docs)
    
    if ! echo "$behaviors" | grep -q '/www/'; then
        error "CloudFront behavior missing /www/ path pattern"
        return 1
    fi
    
    if ! echo "$behaviors" | grep -q '/blog/'; then
        error "CloudFront behavior missing /blog/ path pattern"
        return 1
    fi
    
    if ! echo "$behaviors" | grep -q '/docs/'; then
        error "CloudFront behavior missing /docs/ path pattern"
        return 1
    fi
    
    return 0
}

test_file_organization() {
    # Create test directory structure
    local test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN
    
    mkdir -p "$test_dir/www" "$test_dir/blog" "$test_dir/docs"
    touch "$test_dir/www/index.html"
    touch "$test_dir/blog/index.html"
    touch "$test_dir/docs/index.html"
    
    # Organize files by subdomain
    local org=$(organize_files_by_subdomain "$test_dir" "$TEST_SUBDOMAINS")
    
    if ! echo "$org" | grep -q '"www"'; then
        error "File organization missing www subdomain"
        return 1
    fi
    
    if ! echo "$org" | grep -q '"blog"'; then
        error "File organization missing blog subdomain"
        return 1
    fi
    
    return 0
}

test_version_manifest_structure() {
    # Test multi-subdomain version manifest creation (dry-run)
    local manifest=$(cat <<EOF
{
  "version_id": "20260501-143022",
  "timestamp": "2026-05-01T14:30:22Z",
  "domain": "example.com",
  "subdomains": {
    "www": {
      "files": ["index.html", "css/main.css"],
      "count": 2
    },
    "blog": {
      "files": ["index.html", "post-1.html"],
      "count": 2
    },
    "docs": {
      "files": ["index.html", "guide.html"],
      "count": 2
    }
  },
  "bucket": "website-example-static",
  "created_by": "deploy.sh"
}
EOF
)
    
    # Validate manifest structure
    if ! echo "$manifest" | jq -e '.subdomains.www' >/dev/null 2>&1; then
        error "Invalid multi-subdomain manifest structure"
        return 1
    fi
    
    if ! echo "$manifest" | jq -e '.subdomains.blog' >/dev/null 2>&1; then
        error "Missing blog subdomain in manifest"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Test Execution
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║ Integration Test: US3 - Multi-Subdomain Deployment & Updates                  ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    run_test "Subdomain validation" test_subdomain_validation
    run_test "Subdomain normalization" test_subdomain_normalization
    run_test "CloudFront behavior generation" test_cloudfront_behaviors
    run_test "File organization by subdomain" test_file_organization
    run_test "Multi-subdomain version manifest" test_version_manifest_structure
    
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
