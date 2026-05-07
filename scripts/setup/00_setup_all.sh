#!/bin/bash
# Master setup orchestrator for VSLAM UAV on Jetson Orin Nano
#
# Usage: ./00_setup_all.sh [OPTIONS]
#
# Options:
#   --include-ssd    Run SSD + Docker migration step (DESTRUCTIVE, skipped by default)
#   --skip-images    Skip Docker image builds (use to resume after images are built)
#   --yes            Non-interactive: accept all prompts automatically
#
# To resume after a failure, re-run with the same flags — completed steps are skipped.
# To re-run a specific step manually: ./scripts/setup/0N_step.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_not_root

INCLUDE_SSD=0
SKIP_IMAGES=0
YES=0

for arg in "$@"; do
    case $arg in
        --include-ssd)  INCLUDE_SSD=1 ;;
        --skip-images)  SKIP_IMAGES=1 ;;
        --yes)          YES=1 ;;
    esac
done

export AUTO_YES=$YES

run_step() {
    local script="$1"
    local name="$2"
    log_step "${name}"
    bash "${SCRIPT_DIR}/${script}" || {
        log_error "Step '${name}' failed. Fix the issue and re-run to continue."
        exit 1
    }
}

log_info "Starting VSLAM UAV Jetson setup"
log_warn "Completed steps are tracked in ~/.vslam_setup_state/ and will be skipped on re-run."

run_step "01_system.sh"              "System configuration"

if [ $INCLUDE_SSD -eq 1 ]; then
    run_step "02_ssd_docker.sh"      "SSD + Docker migration"
else
    log_warn "Skipping SSD/Docker migration (pass --include-ssd to run it)"
fi

run_step "03_isaac_ros_workspace.sh" "Isaac ROS workspace"

if [ $SKIP_IMAGES -eq 0 ]; then
    run_step "04_build_images.sh"    "Docker image builds"
else
    log_warn "Skipping image builds (--skip-images)"
fi

run_step "05_realsense_firmware.sh"  "RealSense firmware"
run_step "06_services.sh"            "Systemd services"

log_info "Setup complete! Reboot to verify auto-start: sudo reboot"
