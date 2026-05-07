#!/bin/bash

CONTAINER_NAME="mavrospy-vslam-container"
IMAGE_NAME="mavrospy-vslam:latest"

# Remove any stopped container with this name
if [ "$(docker ps -a --quiet --filter status=exited --filter "name=^/${CONTAINER_NAME}$")" ]; then
    docker rm "${CONTAINER_NAME}" > /dev/null
fi

# Exit if already running
if [ "$(docker ps --quiet --filter status=running --filter "name=^/${CONTAINER_NAME}$")" ]; then
    echo "Container ${CONTAINER_NAME} is already running."
    exit 0
fi

exec docker run --rm \
    --name "${CONTAINER_NAME}" \
    --device=/dev/ttyUSB0 \
    --network host \
    --ipc=host \
    -e ROS_DOMAIN_ID=1 \
    -e FCU_URL=/dev/ttyUSB0:921600 \
    "${IMAGE_NAME}" \
    -c "source /opt/ros/humble/setup.bash && \
        source /home/jetson/ros2_ws/install/setup.bash && \
        cd /home/jetson/VSLAM-UAV/vslam && \
        ros2 launch mavrospy.launch.py"
