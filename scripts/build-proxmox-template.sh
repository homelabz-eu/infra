#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOFU_DIR="${REPO_ROOT}/images/proxmox-template-builder/tofu"
SSH_USER="suporte"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"

: "${BUILD_TARGET:=ubuntu-2404}"
: "${PROXMOX_NODE:=node03}"
: "${PROXMOX_STORAGE_POOL:=data2}"
: "${PROXMOX_ISO_POOL:=local}"
: "${PROXMOX_BRIDGE:=vmbr0}"
: "${DISK_FORMAT:=raw}"
: "${BUILDER_VM_IP:=192.168.1.170}"
: "${IMAGE_BUILDER_REPO:=https://github.com/kubernetes-sigs/image-builder.git}"
: "${IMAGE_BUILDER_REF:=main}"

cleanup() {
    echo "=== Cleaning up builder VM ==="
    cd "${TOFU_DIR}"
    tofu destroy -auto-approve \
        -var="proxmox_token_id=${PROXMOX_TOKEN_ID}" \
        -var="proxmox_token_secret=${PROXMOX_SECRET}" \
        -var="vm_ip=${BUILDER_VM_IP}" \
        -var="target_node=${PROXMOX_NODE}" || true
}
trap cleanup EXIT

echo "=== Provisioning builder VM ==="
cd "${TOFU_DIR}"
tofu init -reconfigure
tofu apply -auto-approve \
    -var="proxmox_token_id=${PROXMOX_TOKEN_ID}" \
    -var="proxmox_token_secret=${PROXMOX_SECRET}" \
    -var="vm_ip=${BUILDER_VM_IP}" \
    -var="target_node=${PROXMOX_NODE}"

echo "=== Waiting for builder VM SSH readiness ==="
for i in $(seq 1 60); do
    if ssh ${SSH_OPTS} "${SSH_USER}@${BUILDER_VM_IP}" "cloud-init status --wait 2>/dev/null || true; echo ready" 2>/dev/null | grep -q ready; then
        echo "Builder VM is ready after ~${i}0 seconds"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "ERROR: Builder VM did not become ready in time"
        exit 1
    fi
    sleep 10
done

echo "=== Installing dependencies on builder VM ==="
ssh ${SSH_OPTS} "${SSH_USER}@${BUILDER_VM_IP}" "sudo bash -s" <<'DEPS_EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git make python3 python3-pip python3-venv unzip curl openssl jq > /dev/null
DEPS_EOF

echo "=== Cloning image-builder and running Packer build ==="
ssh ${SSH_OPTS} "${SSH_USER}@${BUILDER_VM_IP}" "bash -s" <<BUILD_EOF
set -euo pipefail

git clone --depth 1 --branch "${IMAGE_BUILDER_REF}" "${IMAGE_BUILDER_REPO}" /tmp/image-builder
cd /tmp/image-builder/images/capi

export PROXMOX_URL="${PROXMOX_URL}"
export PROXMOX_USERNAME="${PROXMOX_TOKEN_ID}"
export PROXMOX_TOKEN="${PROXMOX_SECRET}"
export PROXMOX_NODE="${PROXMOX_NODE}"
export PROXMOX_STORAGE_POOL="${PROXMOX_STORAGE_POOL}"
export PROXMOX_ISO_POOL="${PROXMOX_ISO_POOL}"
export PROXMOX_BRIDGE="${PROXMOX_BRIDGE}"
export PACKER_FLAGS="-var disk_format=${DISK_FORMAT}"

make build-proxmox-${BUILD_TARGET}
BUILD_EOF

echo "=== Proxmox template build completed successfully ==="
