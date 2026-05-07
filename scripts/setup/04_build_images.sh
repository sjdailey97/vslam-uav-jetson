#!/bin/bash
# Step 4: Build Docker images
# - isaac_ros_dev-aarch64  (base Isaac ROS image with RealSense support)
# - isaac_ros_vslam:latest (base + pre-installed VSLAM packages, no apt at runtime)
# - mavrospy-vslam:latest  (MAVROS + mavrospy flight control)
#
# Requires internet. Takes 30-90 min on first run. Safe to re-run — built images are skipped.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_not_root

ISAAC_ROS_WS="${ISAAC_ROS_WS:-/ssd/workspaces/isaac_ros-dev}"
COMMON_SCRIPTS="${ISAAC_ROS_WS}/src/isaac_ros_common/scripts"

# --- Check D435i is connected (warn only) ---
if ! lsusb | grep -q "8086:0b3a"; then
    log_warn "Intel RealSense D435i not detected on USB. The base image build requires it."
    log_warn "Connect the camera and re-run, or continue at your own risk."
    if [ "${AUTO_YES:-0}" -ne 1 ]; then
        read -rp "Continue anyway? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || exit 1
    fi
fi

# --- Build base Isaac ROS image ---
if ! docker image inspect isaac_ros_dev-aarch64:latest &>/dev/null; then
    log_step "Build isaac_ros_dev-aarch64 (this takes 30-60 min)"
    bash "${COMMON_SCRIPTS}/build_image_layers.sh" \
        --image_key "aarch64.ros2_humble.realsense" \
        --image_name "isaac_ros_dev-aarch64"
    log_info "Base image built."
else
    log_info "isaac_ros_dev-aarch64 already exists."
fi

# --- Build VSLAM image ---
if ! docker image inspect isaac_ros_vslam:latest &>/dev/null; then
    log_step "Build isaac_ros_vslam:latest"
    docker build --network host \
        -t isaac_ros_vslam:latest \
        -f "${ISAAC_ROS_WS}/docker/Dockerfile.vslam" \
        "${ISAAC_ROS_WS}/docker/"
    log_info "VSLAM image built."
else
    log_info "isaac_ros_vslam:latest already exists."
fi

# --- Build mavrospy image ---
if ! docker image inspect mavrospy-vslam:latest &>/dev/null; then
    log_step "Build mavrospy-vslam:latest (this takes 20-40 min)"
    docker build --network host \
        -t mavrospy-vslam:latest \
        -f "${ISAAC_ROS_WS}/VSLAM-UAV/docker/mavrospy/Dockerfile" \
        "${ISAAC_ROS_WS}/VSLAM-UAV/docker/mavrospy/"
    log_info "Mavrospy image built."
else
    log_info "mavrospy-vslam:latest already exists."
fi

log_info "All Docker images ready."
