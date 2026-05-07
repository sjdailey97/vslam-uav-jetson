#!/bin/bash
# Shared utilities for VSLAM setup scripts

STATE_DIR="${HOME}/.vslam_setup_state"
mkdir -p "${STATE_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}====${NC} $* ${BLUE}====${NC}"; }

check_step() {
    [ -f "${STATE_DIR}/$1" ]
}

mark_step_done() {
    touch "${STATE_DIR}/$1"
    log_info "Step '$1' complete."
}

require_sudo_access() {
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo access. Run: sudo -v"
        exit 1
    fi
}

require_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        log_error "Do not run this script as root. Run as your normal user."
        exit 1
    fi
}
