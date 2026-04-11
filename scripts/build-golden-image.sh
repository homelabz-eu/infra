#!/bin/bash
set -euo pipefail

K8S_VERSION="${K8S_VERSION:?K8S_VERSION is required (e.g. 1.33.0)}"
K8S_VERSION_SANITIZED="${K8S_VERSION//./-}"
PVC_NAME="${PVC_NAME:-golden-image-k8s-${K8S_VERSION_SANITIZED}}"
NAMESPACE="${NAMESPACE:-vm-templates}"
STORAGE_CLASS="${STORAGE_CLASS:-longhorn}"
STORAGE_SIZE="${STORAGE_SIZE:-10Gi}"
CDI_UPLOADPROXY_URL="${CDI_UPLOADPROXY_URL:-https://cdi-uploadproxy.toolz.homelabz.eu}"
BASE_IMAGE="ubuntu-22.04-server-cloudimg-amd64.img"
OUTPUT_IMAGE="golden-image-k8s-${K8S_VERSION_SANITIZED}.qcow2"

echo "=== Building golden image for Kubernetes ${K8S_VERSION} ==="
echo "PVC name: ${PVC_NAME}"
echo "Namespace: ${NAMESPACE}"

SSH_PUB_KEY_FILE=$(mktemp)
trap "rm -f ${SSH_PUB_KEY_FILE}" EXIT

if [ -n "${SSH_PRIVATE_KEY:-}" ]; then
    PRIV_KEY_FILE=$(mktemp)
    echo "${SSH_PRIVATE_KEY}" > "${PRIV_KEY_FILE}"
    chmod 600 "${PRIV_KEY_FILE}"
    ssh-keygen -y -f "${PRIV_KEY_FILE}" > "${SSH_PUB_KEY_FILE}"
    rm -f "${PRIV_KEY_FILE}"
    echo "SSH public key derived from SSH_PRIVATE_KEY"
elif [ -n "${SSH_PUB_KEY:-}" ]; then
    echo "${SSH_PUB_KEY}" > "${SSH_PUB_KEY_FILE}"
    echo "SSH public key provided via SSH_PUB_KEY"
else
    echo "ERROR: Either SSH_PRIVATE_KEY or SSH_PUB_KEY must be set"
    exit 1
fi

echo "=== Downloading base image ==="
if [ ! -f "${BASE_IMAGE}" ]; then
    wget -q "https://cloud-images.ubuntu.com/releases/22.04/release/${BASE_IMAGE}"
fi
cp "${BASE_IMAGE}" "${OUTPUT_IMAGE}"

echo "=== Resizing image ==="
qemu-img resize "${OUTPUT_IMAGE}" +5G
virt-customize -a "${OUTPUT_IMAGE}" \
  --run-command "growpart /dev/sda 1" \
  --run-command "resize2fs /dev/sda1"

echo "=== Customizing image ==="
virt-customize -a "${OUTPUT_IMAGE}" \
  --update \
  --install apt-transport-https,ca-certificates,curl,gnupg,lsb-release,net-tools,ipvsadm,jq,ncat,vim,nano,software-properties-common,cloud-utils,qemu-guest-agent,acpid \
  --run-command "systemctl enable qemu-guest-agent" \
  --run-command "systemctl enable acpid" \
  --run-command "echo 'overlay' > /etc/modules-load.d/containerd.conf" \
  --run-command "echo 'br_netfilter' >> /etc/modules-load.d/containerd.conf" \
  --run-command "echo 'net.bridge.bridge-nf-call-iptables = 1' > /etc/sysctl.d/99-kubernetes-cri.conf" \
  --run-command "echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/99-kubernetes-cri.conf" \
  --run-command "echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-kubernetes-cri.conf" \
  --run-command "install -m 0755 -d /etc/apt/keyrings" \
  --run-command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg" \
  --run-command "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null" \
  --run-command "apt-get update" \
  --run-command "apt-get install -y containerd.io" \
  --run-command "mkdir -p /etc/containerd" \
  --run-command "containerd config default > /etc/containerd/config.toml" \
  --run-command "sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml" \
  --run-command "sed -i 's|sandbox_image = \"registry.k8s.io/pause:3.8\"|sandbox_image = \"registry.k8s.io/pause:3.10\"|g' /etc/containerd/config.toml" \
  --run-command "systemctl enable containerd" \
  --run-command "curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/deb/Release.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/k8s.gpg" \
  --run-command "echo \"deb [signed-by=/etc/apt/trusted.gpg.d/k8s.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/deb/ /\" | tee /etc/apt/sources.list.d/kubernetes.list" \
  --run-command "apt-get update" \
  --run-command "apt-get install -y kubelet=${K8S_VERSION}-1.1 kubeadm=${K8S_VERSION}-1.1 kubectl=${K8S_VERSION}-1.1" \
  --run-command "apt-mark hold kubelet kubeadm kubectl" \
  --run-command "curl -L -o /tmp/kube-bench.deb https://github.com/aquasecurity/kube-bench/releases/download/v0.10.1/kube-bench_0.10.1_linux_amd64.deb" \
  --run-command "dpkg -i /tmp/kube-bench.deb" \
  --run-command "rm /tmp/kube-bench.deb" \
  --run-command "swapoff -a" \
  --run-command "sed -i '/swap/s/^/#/' /etc/fstab" \
  --run-command "useradd suporte" \
  --run-command "mkdir -p /home/suporte/.kube" \
  --run-command "chown -R suporte:suporte /home/suporte/.kube" \
  --run-command "echo 'suporte ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/suporte" \
  --ssh-inject suporte:file:"${SSH_PUB_KEY_FILE}" \
  --root-password password:suporte

echo "=== Image customization complete ==="
qemu-img info "${OUTPUT_IMAGE}"

echo "=== Checking for existing PVC ==="
if kubectl get pvc "${PVC_NAME}" -n "${NAMESPACE}" &>/dev/null; then
    echo "PVC ${PVC_NAME} already exists in ${NAMESPACE}, deleting it first..."
    kubectl delete pvc "${PVC_NAME}" -n "${NAMESPACE}" --wait=true --timeout=120s
    sleep 5
fi

echo "=== Uploading image to CDI ==="
virtctl image-upload dv "${PVC_NAME}" \
  --namespace="${NAMESPACE}" \
  --size="${STORAGE_SIZE}" \
  --image-path="${OUTPUT_IMAGE}" \
  --storage-class="${STORAGE_CLASS}" \
  --access-mode=ReadWriteMany \
  --uploadproxy-url="${CDI_UPLOADPROXY_URL}" \
  --insecure \
  --force-bind

echo "=== Verifying upload ==="
kubectl get pvc "${PVC_NAME}" -n "${NAMESPACE}"

echo "=== Golden image ${PVC_NAME} ready in ${NAMESPACE} ==="
echo "To use this image, update GOLDEN_IMAGE_NAME in cks-backend configmap to: ${PVC_NAME}"
