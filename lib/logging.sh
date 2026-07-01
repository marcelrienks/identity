#!/bin/bash

# Logging functions for unified deployment script
# Provides: info, warn, error, debug, trace output with timestamps

set -o pipefail

# Color codes
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Log level: DEBUG, INFO, WARN, ERROR (default: INFO)
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Log file path (if set, also write to file)
LOG_FILE="${LOG_FILE:-}"

# Flag to control verbose output
DEBUG_MODE="${DEBUG_MODE:-0}"

# Helper: Write timestamp
_log_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Helper: Convert log level string to numeric value
_log_level_to_num() {
    case "$1" in
        DEBUG) echo 0 ;;
        INFO) echo 1 ;;
        WARN) echo 2 ;;
        ERROR) echo 3 ;;
        *) echo 1 ;;
    esac
}

# Helper: Check if message should be logged based on LOG_LEVEL
_should_log() {
    local msg_level_num=$(_log_level_to_num "$1")
    local log_level_num=$(_log_level_to_num "$LOG_LEVEL")
    [[ $msg_level_num -ge $log_level_num ]]
}

# Helper: Write message to log file (if enabled)
_write_log_file() {
    local level="$1"
    local message="$2"
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(_log_timestamp)] [$level] $message" >> "$LOG_FILE"
    fi
}

# INFO level logging (default)
info() {
    local message="$*"
    if _should_log "INFO"; then
        echo -e "${COLOR_GREEN}ℹ${COLOR_RESET}  $message"
    fi
    _write_log_file "INFO" "$message"
}

# DEBUG level logging (verbose)
debug() {
    local message="$*"
    if _should_log "DEBUG"; then
        echo -e "${COLOR_CYAN}➜${COLOR_RESET}  $message" >&2
    fi
    _write_log_file "DEBUG" "$message"
}

# WARN level logging (warnings)
warn() {
    local message="$*"
    if _should_log "WARN"; then
        echo -e "${COLOR_YELLOW}⚠${COLOR_RESET}  $message" >&2
    fi
    _write_log_file "WARN" "$message"
}

# ERROR level logging (errors)
error() {
    local message="$*"
    if _should_log "ERROR"; then
        echo -e "${COLOR_RED}✗${COLOR_RESET}  $message" >&2
    fi
    _write_log_file "ERROR" "$message"
}

# Section header (bold blue)
section() {
    local title="$*"
    echo
    echo -e "${COLOR_BLUE}━━━ $title ━━━${COLOR_RESET}"
}

# Success message (green checkmark)
success() {
    local message="$*"
    echo -e "${COLOR_GREEN}✓${COLOR_RESET}  $message"
    _write_log_file "INFO" "SUCCESS: $message"
}

# Failure message (red X)
failure() {
    local message="$*"
    echo -e "${COLOR_RED}✗${COLOR_RESET}  $message" >&2
    _write_log_file "ERROR" "FAILURE: $message"
}

# Print a separator line
separator() {
    echo "---"
}

export LOG_LEVEL LOG_FILE DEBUG_MODE
