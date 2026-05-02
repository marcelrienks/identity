#!/bin/bash

# Integration Test: US4 - Rollback Functionality
# Tests version history, rollback commands, and recovery

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../../.."
LIB_DIR="$PROJECT_ROOT/lib"

# Source libraries
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/rollback-cmd.sh"
source "$LIB_DIR/versions-cmd.sh"

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

test_version_validation() {
    # Create mock version directory
    local test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN
    
    mkdir -p "$test_dir/.deploy/versions"
    
    # Create sample version manifest
    cat > "$test_dir/.deploy/versions/20260501-143022.json" <<EOF
{
  "version_id": "20260501-143022",
  "timestamp": "2026-05-01T14:30:22Z",
  "domain": "example.com",
  "subdomain": "www",
  "files": ["index.html", "css/main.css", "js/main.js"],
  "bucket": "website-www-example-com-static"
}
EOF
    
    # Test version exists
    (cd "$test_dir" && validate_version_exists "20260501-143022") || return 1
    
    # Test non-existent version fails
    (cd "$test_dir" && validate_version_exists "20260401-120000") && return 1
    
    return 0
}

test_version_file_count() {
    # Create test version manifest
    local test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN
    
    mkdir -p "$test_dir/.deploy/versions"
    
    cat > "$test_dir/.deploy/versions/20260501-143022.json" <<EOF
{
  "version_id": "20260501-143022",
  "timestamp": "2026-05-01T14:30:22Z",
  "domain": "example.com",
  "files": ["file1.html", "file2.css", "file3.js", "file4.png", "file5.jpg"],
  "bucket": "test-bucket"
}
EOF
    
    # Test file count extraction
    (cd "$test_dir" && local count=$(get_version_file_count "20260501-143022") && \
        [[ "$count" == "5" ]] && return 0)
    
    return 1
}

test_version_timestamp() {
    # Create test version manifest
    local test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN
    
    mkdir -p "$test_dir/.deploy/versions"
    
    cat > "$test_dir/.deploy/versions/20260501-143022.json" <<EOF
{
  "version_id": "20260501-143022",
  "timestamp": "2026-05-01T14:30:22Z",
  "domain": "example.com",
  "files": ["index.html"],
  "bucket": "test-bucket"
}
EOF
    
    # Test timestamp extraction
    local timestamp=$(cd "$test_dir" && get_version_timestamp "20260501-143022")
    [[ "$timestamp" == "2026-05-01T14:30:22Z" ]] || return 1
    
    return 0
}

test_version_list_output() {
    # Create test version directory
    local test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN
    
    mkdir -p "$test_dir/.deploy/versions"
    
    # Create multiple version files
    for i in 1 2 3; do
        cat > "$test_dir/.deploy/versions/20260501-14300$i.json" <<EOF
{
  "version_id": "20260501-14300$i",
  "timestamp": "2026-05-01T14:30:0${i}Z",
  "domain": "example.com",
  "files": ["file1.html", "file2.css"],
  "bucket": "test-bucket"
}
EOF
    done
    
    # Test version list output
    (cd "$test_dir" && list_versions 10 0 | grep -q "VERSION") || return 1
    
    return 0
}

test_version_show_details() {
    # Create test version manifest
    local test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN
    
    mkdir -p "$test_dir/.deploy/versions"
    
    cat > "$test_dir/.deploy/versions/20260501-143022.json" <<EOF
{
  "version_id": "20260501-143022",
  "timestamp": "2026-05-01T14:30:22Z",
  "domain": "example.com",
  "subdomain": "www",
  "files": ["index.html", "style.css", "script.js"],
  "bucket": "website-www-example-com-static"
}
EOF
    
    # Test showing version details
    (cd "$test_dir" && show_version_details "20260501-143022" 0 | grep -q "index.html") || return 1
    
    return 0
}

test_version_json_output() {
    # Create test version manifest
    local test_dir=$(mktemp -d)
    trap "rm -rf $test_dir" RETURN
    
    mkdir -p "$test_dir/.deploy/versions"
    
    cat > "$test_dir/.deploy/versions/20260501-143022.json" <<EOF
{
  "version_id": "20260501-143022",
  "timestamp": "2026-05-01T14:30:22Z",
  "domain": "example.com",
  "files": ["index.html"],
  "bucket": "test-bucket"
}
EOF
    
    # Test JSON output
    (cd "$test_dir" && show_version_details "20260501-143022" 1 | jq -e '.version_id' >/dev/null) || return 1
    
    return 0
}

# ============================================================================
# Test Execution
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║ Integration Test: US4 - Rollback & Versioning                                 ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    run_test "Version validation" test_version_validation
    run_test "Version file count extraction" test_version_file_count
    run_test "Version timestamp extraction" test_version_timestamp
    run_test "Version list output" test_version_list_output
    run_test "Version show details" test_version_show_details
    run_test "Version JSON output format" test_version_json_output
    
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
