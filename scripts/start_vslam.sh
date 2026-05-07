#!/bin/bash

CONTAINER_NAME="isaac_ros_dev-aarch64-container"
IMAGE_NAME="isaac_ros_vslam:latest"
ISAAC_ROS_WS="/ssd/workspaces/isaac_ros-dev"

# Remove any stopped container with this name
if [ "$(docker ps -a --quiet --filter status=exited --filter name=${CONTAINER_NAME})" ]; then
    docker rm "${CONTAINER_NAME}" > /dev/null
fi

# Exit if already running
if [ "$(docker ps --quiet --filter status=running --filter name=${CONTAINER_NAME})" ]; then
    echo "Container ${CONTAINER_NAME} is already running."
    exit 0
fi

exec docker run --rm \
    --privileged \
    --network host \
    --ipc=host \
    --pid=host \
    --runtime nvidia \
    -e NVIDIA_VISIBLE_DEVICES=nvidia.com/gpu=all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -e ROS_DOMAIN_ID=1 \
    -e ISAAC_ROS_WS=/workspaces/isaac_ros-dev \
    -e HOST_USER_UID=1000 \
    -e HOST_USER_GID=1000 \
    -v "${ISAAC_ROS_WS}":/workspaces/isaac_ros-dev \
    -v /usr/bin/tegrastats:/usr/bin/tegrastats \
    -v /tmp/:/tmp/ \
    -v /usr/lib/aarch64-linux-gnu/tegra:/usr/lib/aarch64-linux-gnu/tegra \
    -v /usr/src/jetson_multimedia_api:/usr/src/jetson_multimedia_api \
    -v /usr/share/vpi3:/usr/share/vpi3 \
    -v /dev/input:/dev/input \
    -v /etc/localtime:/etc/localtime:ro \
    --name "${CONTAINER_NAME}" \
    --entrypoint /usr/local/bin/scripts/workspace-entrypoint.sh \
    --workdir /workspaces/isaac_ros-dev/VSLAM-UAV/vslam \
    "${IMAGE_NAME}" \
    /bin/bash -c "source /opt/ros/humble/setup.bash && export ROS_DOMAIN_ID=1 && cd /workspaces/isaac_ros-dev/VSLAM-UAV/vslam && ros2 launch isaac_ros_vslam_realsense.py"
