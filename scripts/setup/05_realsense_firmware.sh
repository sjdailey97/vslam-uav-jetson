#!/bin/bash
# Step 5: RealSense D435i firmware update
#
# Ensures the camera is running firmware 5.13.0.50, which is required by
# the Isaac ROS Docker image. Other versions may not work correctly.
#
# Requires: Signed_Image_UVC_5_13_0_50.bin in $ISAAC_ROS_WS/

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_not_root

ISAAC_ROS_WS="${ISAAC_ROS_WS:-/ssd/workspaces/isaac_ros-dev}"
FIRMWARE_BIN="${ISAAC_ROS_WS}/Signed_Image_UVC_5_13_0_50.bin"
TARGET_FW="5.13.0.50"

# --- Check firmware file exists ---
if [ ! -f "${FIRMWARE_BIN}" ]; then
    log_error "Firmware file not found: ${FIRMWARE_BIN}"
    log_error "Download Signed_Image_UVC_5_13_0_50.bin and place it in ${ISAAC_ROS_WS}/"
    exit 1
fi

# --- Check camera is connected ---
if ! lsusb | grep -q "8086:0b3a"; then
    log_error "Intel RealSense D435i not detected. Connect the camera and re-run."
    exit 1
fi

# --- Check current firmware version ---
log_step "Check current firmware version"
CURRENT_FW=$(docker run --rm --privileged --network host \
    isaac_ros_vslam:latest \
    bash -c "rs-fw-update -l 2>/dev/null | grep -i 'firmware version:' | awk '{print \$NF}'" 2>/dev/null || echo "unknown")

log_info "Current firmware: ${CURRENT_FW}"

if [ "${CURRENT_FW}" = "${TARGET_FW}" ]; then
    log_info "Already at firmware ${TARGET_FW}. No update needed."
    mark_step_done "realsense_firmware"
    exit 0
fi

# --- Flash firmware ---
log_step "Updating firmware to ${TARGET_FW} (camera will disconnect briefly)"
docker run --rm --privileged --network host \
    -v "${FIRMWARE_BIN}":/tmp/fw.bin \
    isaac_ros_vslam:latest \
    bash -c "rs-fw-update -f /tmp/fw.bin"

log_info "Firmware update complete. Verifying..."
sleep 3

NEW_FW=$(docker run --rm --privileged --network host \
    isaac_ros_vslam:latest \
    bash -c "rs-fw-update -l 2>/dev/null | grep -i 'firmware version:' | awk '{print \$NF}'" 2>/dev/null || echo "unknown")

if [ "${NEW_FW}" = "${TARGET_FW}" ]; then
    log_info "Firmware verified: ${NEW_FW}"
    mark_step_done "realsense_firmware"
else
    log_warn "Firmware shows '${NEW_FW}' — may need a camera replug to complete update."
fi
