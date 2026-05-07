#!/bin/bash
# Step 2: SSD setup and Docker data migration (DESTRUCTIVE — skipped by default)
#
# Only needed on a fresh Jetson where Docker is still on eMMC.
# Formats the NVMe SSD, mounts it to /ssd, and migrates Docker data.
#
# Usage: ./02_ssd_docker.sh [--yes]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_not_root
require_sudo_access

YES="${AUTO_YES:-0}"
for arg in "$@"; do [ "$arg" = "--yes" ] && YES=1; done

# --- Check if already done ---
DOCKER_ROOT=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "")
if [[ "$DOCKER_ROOT" == /ssd/* ]]; then
    log_info "Docker data root is already on SSD (${DOCKER_ROOT}). Skipping."
    exit 0
fi

log_warn "This step will FORMAT the NVMe SSD and migrate Docker data."
log_warn "All existing data on the SSD will be DESTROYED."

if [ "$YES" -ne 1 ]; then
    read -rp "Type CONFIRM to proceed: " confirmation
    [ "$confirmation" = "CONFIRM" ] || { log_info "Aborted."; exit 0; }
fi

# --- Detect SSD ---
log_step "Detect NVMe SSD"
SSD_DEVICE=$(lsblk -J | python3 -c "
import json,sys
data=json.load(sys.stdin)
for d in data['blockdevices']:
    if d['type']=='disk' and d['name'].startswith('nvme'):
        print('/dev/'+d['name'])
        break
" 2>/dev/null || echo "")

if [ -z "$SSD_DEVICE" ]; then
    log_error "No NVMe device found. Check 'lsblk' output."
    exit 1
fi
log_info "Found SSD: ${SSD_DEVICE}"

# --- Format and mount ---
log_step "Format ${SSD_DEVICE} as ext4"
sudo mkfs.ext4 "${SSD_DEVICE}"

log_step "Mount to /ssd"
sudo mkdir -p /ssd
sudo mount "${SSD_DEVICE}" /ssd

SSD_UUID=$(lsblk -f "${SSD_DEVICE}" -o UUID -n | head -1)
if ! grep -q "${SSD_UUID}" /etc/fstab; then
    echo "UUID=${SSD_UUID} /ssd ext4 defaults 0 2" | sudo tee -a /etc/fstab > /dev/null
    log_info "Added SSD to /etc/fstab (UUID: ${SSD_UUID})"
fi

sudo chown "${USER}:${USER}" /ssd

# --- Migrate Docker data ---
log_step "Migrate Docker data to SSD"
sudo systemctl stop docker

sudo mkdir -p /ssd/docker
sudo rsync -axPS /var/lib/docker/ /ssd/docker/

echo '{"runtimes":{"nvidia":{"path":"nvidia-container-runtime","runtimeArgs":[]}},"default-runtime":"nvidia","data-root":"/ssd/docker"}' \
    | sudo tee /etc/docker/daemon.json > /dev/null

sudo mv /var/lib/docker /var/lib/docker.old
sudo systemctl daemon-reload
sudo systemctl restart docker

log_info "Docker migrated to /ssd/docker. Old data at /var/lib/docker.old (safe to delete after verification)."
mark_step_done "ssd_docker"
