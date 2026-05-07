#!/bin/bash
# Step 6: Install and enable systemd auto-start services
#
# Installs vslam.service and mavrospy.service to /etc/systemd/system/
# and enables them to start on boot.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_not_root
require_sudo_access

ISAAC_ROS_WS="${ISAAC_ROS_WS:-/ssd/workspaces/isaac_ros-dev}"
SCRIPTS_DIR="${ISAAC_ROS_WS}/scripts"

# --- Ensure start scripts are executable ---
log_step "Set permissions on start scripts"
chmod +x "${SCRIPTS_DIR}/start_vslam.sh"
chmod +x "${SCRIPTS_DIR}/start_mavrospy.sh"

# --- Install service files ---
log_step "Install systemd service files"
sudo cp "${SCRIPTS_DIR}/vslam.service"    /etc/systemd/system/vslam.service
sudo cp "${SCRIPTS_DIR}/mavrospy.service" /etc/systemd/system/mavrospy.service

# --- Reload and enable ---
sudo systemctl daemon-reload
sudo systemctl enable vslam.service mavrospy.service
log_info "Services enabled for auto-start on boot."

mark_step_done "services"

log_info ""
log_info "To start services now:    sudo systemctl start vslam.service"
log_info "To watch live logs:       journalctl -fu vslam.service"
log_info "To check both services:   systemctl status vslam.service mavrospy.service"
