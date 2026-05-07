#!/bin/bash
# Step 1: System configuration
# - Verifies JetPack 6.2
# - Sets max clocks and power mode
# - Adds user to docker and dialout groups
# - Installs fake-hwclock to maintain time across reboots without internet

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_not_root
require_sudo_access

# --- Verify JetPack 6.2 ---
log_step "Verify JetPack 6.2"
if ! grep -q "R36.*REVISION: 4.3" /etc/nv_tegra_release 2>/dev/null; then
    log_error "JetPack 6.2 (R36, REVISION: 4.3) is required."
    log_error "Current: $(cat /etc/nv_tegra_release 2>/dev/null || echo 'not found')"
    exit 1
fi
log_info "JetPack 6.2 confirmed."

# --- Max clocks ---
if ! check_step "jetson_clocks"; then
    log_step "Set max CPU/GPU clocks"
    sudo /usr/bin/jetson_clocks
    mark_step_done "jetson_clocks"
else
    log_info "jetson_clocks already set."
fi

# --- Power mode MAXN SUPER ---
if ! check_step "nvpmodel"; then
    log_step "Set power mode to MAXN SUPER (mode 2)"
    sudo /usr/sbin/nvpmodel -m 2
    mark_step_done "nvpmodel"
else
    log_info "nvpmodel already set."
fi

# --- Docker group ---
if ! groups "${USER}" | grep -q '\bdocker\b'; then
    log_step "Add ${USER} to docker group"
    sudo usermod -aG docker "${USER}"
    log_warn "Log out and back in (or run 'newgrp docker') for docker group to take effect."
else
    log_info "User already in docker group."
fi

# --- Dialout group (for /dev/ttyUSB0) ---
if ! groups "${USER}" | grep -q '\bdialout\b'; then
    log_step "Add ${USER} to dialout group"
    sudo adduser "${USER}" dialout
    log_warn "Reboot or re-login for dialout group to take effect."
else
    log_info "User already in dialout group."
fi

# --- fake-hwclock ---
if ! check_step "fake_hwclock"; then
    log_step "Install fake-hwclock (enables boot without internet)"
    sudo apt install -y fake-hwclock
    sudo systemctl enable fake-hwclock
    sudo fake-hwclock save
    mark_step_done "fake_hwclock"
else
    log_info "fake-hwclock already installed."
fi

log_info "System configuration complete."
