# VSLAM UAV — Jetson Setup

Automated setup and auto-start scripts for GPS-denied VSLAM flight on a Jetson Orin Nano. Uses [Isaac ROS Visual SLAM](https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_visual_slam) with an Intel RealSense D435i and a PX4 flight controller.

Based on the setup guide at [andrewbernas.com/docs/tutorials/robots/vslam/setup](https://www.andrewbernas.com/docs/tutorials/robots/vslam/setup).

---

## Hardware

| Component | Requirement |
|-----------|-------------|
| Companion computer | Jetson Orin Nano, JetPack 6.2 |
| Camera | Intel RealSense D435i, firmware **5.13.0.50** |
| Flight controller | PX4 v1.15.4 |
| FC ↔ Jetson link | USB-to-UART adapter (CP210x recommended) wired to TELEM2 |
| Storage | NVMe SSD mounted at `/ssd` |

### Wiring (TELEM2 → USB-to-UART adapter)

| PX4 TELEM2 Pin | Adapter Pin |
|----------------|-------------|
| UART5_TX (2) | RXD |
| UART5_RX (3) | TXD |
| GND (6) | GND |

---

## PX4 Parameters

Set these in QGroundControl before flight.

**MAVLink via TELEM2:**
```
MAV_1_CONFIG  = TELEM2
SER_TEL2_BAUD = 921600
UXRCE_DDS_CFG = 0
```

**GPS-denied vision pose fusion:**
```
EKF2_HGT_REF  = Vision
EKF2_EV_DELAY = 50.0ms
EKF2_EV_CTRL  = 15
EKF2_GPS_CTRL = 0
EKF2_BARO_CTRL = Disabled
EKF2_RNG_CTRL  = Disable range fusion
EKF2_MAG_TYPE  = None
MAV_USEHILGPS  = Enabled
```

---

## Setup — New Jetson

> Requires internet. Takes 60–120 min due to Docker image builds.

**1. Clone this repo**
```bash
mkdir -p /ssd/workspaces/isaac_ros-dev
git clone <this-repo> /ssd/workspaces/isaac_ros-dev
cd /ssd/workspaces/isaac_ros-dev
```

**2. Place the RealSense firmware file**

Put `Signed_Image_UVC_5_13_0_50.bin` in `/ssd/workspaces/isaac_ros-dev/`.
It can be downloaded from the Intel RealSense firmware archive.

**3. Run the setup script**
```bash
bash scripts/setup/00_setup_all.sh
```

The script is **idempotent** — if it fails partway through, fix the issue and re-run. Completed steps are skipped automatically.

> **Note:** If this is a fresh Jetson and Docker is still on eMMC, add `--include-ssd` to also set up the SSD and migrate Docker. This is destructive — it will format the NVMe drive.
> ```bash
> bash scripts/setup/00_setup_all.sh --include-ssd
> ```

**4. Reboot**
```bash
sudo reboot
```

Both containers start automatically on every boot without internet.

---

## What the Setup Script Does

| Script | Description |
|--------|-------------|
| `01_system.sh` | Sets max clocks and power mode, adds user to `docker`/`dialout` groups, installs `fake-hwclock` |
| `02_ssd_docker.sh` | Formats NVMe SSD, mounts to `/ssd`, migrates Docker data *(skipped by default)* |
| `03_isaac_ros_workspace.sh` | Installs dependencies, clones `isaac_ros_common` and `VSLAM-UAV`, downloads NGC assets |
| `04_build_images.sh` | Builds `isaac_ros_dev-aarch64`, `isaac_ros_vslam:latest`, and `mavrospy-vslam:latest` |
| `05_realsense_firmware.sh` | Checks and updates D435i firmware to 5.13.0.50 |
| `06_services.sh` | Installs and enables systemd auto-start services |

Individual scripts can be run standalone to re-run a specific step.

---

## Runtime

On boot, two Docker containers start automatically:

| Container | Image | What it runs |
|-----------|-------|-------------|
| `isaac_ros_dev-aarch64-container` | `isaac_ros_vslam:latest` | RealSense camera node + Isaac ROS cuVSLAM |
| `mavrospy-vslam-container` | `mavrospy-vslam:latest` | MAVROS + pose relay + mavrospy flight controller |

Both start in parallel immediately after Docker is ready (~3–5 seconds after boot). The pose relay automatically connects the VSLAM output to MAVROS once VSLAM begins publishing.

### Useful commands

```bash
# Check both containers are running
docker ps

# Watch live logs
journalctl -fu vslam.service
journalctl -fu mavrospy.service

# Manually start / stop
sudo systemctl start vslam.service mavrospy.service
sudo systemctl stop vslam.service mavrospy.service

# Restart after a change
sudo systemctl restart vslam.service
```

---

## IMU Calibration

The D435i IMU comes pre-calibrated but it is recommended to recalibrate and run Allan Variance to obtain noise parameters. See the full guide for instructions:
[andrewbernas.com/docs/tutorials/robots/vslam/setup](https://www.andrewbernas.com/docs/tutorials/robots/vslam/setup)

The resulting parameters go in `VSLAM-UAV/vslam/isaac_ros_vslam_realsense.py`:
```python
'gyro_noise_density':  <value>,
'gyro_random_walk':    <value>,
'accel_noise_density': <value>,
'accel_random_walk':   <value>,
```
