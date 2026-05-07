#!/bin/bash
# Step 3: Isaac ROS workspace setup
# - Installs git-lfs and dependencies
# - Creates workspace at /ssd/workspaces/isaac_ros-dev
# - Clones isaac_ros_common and VSLAM-UAV
# - Generates GPU CDI spec
# - Downloads Isaac ROS assets from NGC

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_not_root
require_sudo_access

ISAAC_ROS_WS="${ISAAC_ROS_WS:-/ssd/workspaces/isaac_ros-dev}"

# --- Dependencies ---
if ! check_step "workspace_deps"; then
    log_step "Install dependencies"
    sudo apt install -y git-lfs curl jq tar
    git lfs install --skip-repo
    mark_step_done "workspace_deps"
else
    log_info "Dependencies already installed."
fi

# --- Workspace directory ---
log_step "Create workspace"
mkdir -p "${ISAAC_ROS_WS}/src"

if ! grep -q "ISAAC_ROS_WS" "${HOME}/.bashrc"; then
    echo "export ISAAC_ROS_WS=${ISAAC_ROS_WS}" >> "${HOME}/.bashrc"
    log_info "Added ISAAC_ROS_WS to ~/.bashrc"
fi
export ISAAC_ROS_WS

# --- Clone isaac_ros_common ---
if ! check_step "isaac_ros_common"; then
    log_step "Clone isaac_ros_common (release-3.2)"
    COMMON_DIR="${ISAAC_ROS_WS}/src/isaac_ros_common"
    if [ -d "${COMMON_DIR}/.git" ]; then
        log_info "isaac_ros_common already cloned."
    else
        git clone -b release-3.2 \
            https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_common.git \
            "${COMMON_DIR}"
    fi

    # Configure for RealSense
    CONFIG_FILE="${COMMON_DIR}/scripts/.isaac_ros_common-config"
    echo "CONFIG_IMAGE_KEY=ros2_humble.realsense" > "${CONFIG_FILE}"
    log_info "Set CONFIG_IMAGE_KEY=ros2_humble.realsense"

    mark_step_done "isaac_ros_common"
else
    log_info "isaac_ros_common already set up."
fi

# --- CDI spec ---
if ! check_step "cdi_spec"; then
    log_step "Generate GPU CDI spec"
    sudo nvidia-ctk cdi generate --mode=csv --output=/etc/cdi/nvidia.yaml
    mark_step_done "cdi_spec"
else
    log_info "CDI spec already generated."
fi

# --- Clone VSLAM-UAV ---
if ! check_step "vslam_uav"; then
    log_step "Clone VSLAM-UAV"
    VSLAM_DIR="${ISAAC_ROS_WS}/VSLAM-UAV"
    if [ ! -d "${VSLAM_DIR}/.git" ]; then
        git clone https://github.com/bandofpv/VSLAM-UAV.git "${VSLAM_DIR}"
    else
        log_info "VSLAM-UAV already cloned."
    fi

    # Copy our customized launch files over the upstream versions
    log_info "Installing custom launch files..."
    cp "${ISAAC_ROS_WS}/launch/isaac_ros_vslam_realsense.py" "${VSLAM_DIR}/vslam/"
    cp "${ISAAC_ROS_WS}/launch/mavrospy.launch.py"           "${VSLAM_DIR}/vslam/"

    mark_step_done "vslam_uav"
else
    log_info "VSLAM-UAV already cloned."
fi

# --- Download NGC assets ---
if ! check_step "ngc_assets"; then
    log_step "Download Isaac ROS assets from NGC"
    bash "${ISAAC_ROS_WS}/VSLAM-UAV/vslam/setup/isaac_vslam_assets.sh"
    mark_step_done "ngc_assets"
else
    log_info "NGC assets already downloaded."
fi

log_info "Isaac ROS workspace setup complete."
