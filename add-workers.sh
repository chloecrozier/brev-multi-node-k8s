#!/usr/bin/env bash
#
# Add worker nodes to your K3s cluster.
# Run this from the control plane after setup-control-plane.sh.
#
# Usage:
#   ./add-workers.sh <worker-ip-1> [worker-ip-2] ...
#   GPU=true ./add-workers.sh <worker-ip-1> [worker-ip-2] ...
#
# The control-plane IP and token are read from $K3S_CP_IP and $K3S_TOKEN
# (set automatically by setup-control-plane.sh via /etc/environment).
# Override with env vars if needed:
#   CP_IP=10.0.0.1 TOKEN=abc ./add-workers.sh <worker-ip> ...
#
# Options (via env vars):
#   SSH_USER     - SSH user for worker nodes (default: ubuntu)
#   GPU          - Set to "true" to label workers as gpu nodes (default: false)
#   NODE_LABELS  - Extra comma-separated labels (e.g. "role=sandbox,team=bio")
#
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: ./add-workers.sh <worker-ip> [worker-ip] ..."
  echo "       GPU=true ./add-workers.sh <worker-ip> [worker-ip] ..."
  echo ""
  echo "  Run from the control plane. IP and token are read automatically"
  echo "  from \$K3S_CP_IP and \$K3S_TOKEN (set by setup-control-plane.sh)."
  echo ""
  echo "Env vars:"
  echo "  SSH_USER=ubuntu    SSH user for workers"
  echo "  GPU=true           Label workers with node-role=gpu"
  echo "  NODE_LABELS=k=v    Extra K3s node labels"
  echo "  CP_IP=<ip>         Override control plane IP"
  echo "  TOKEN=<token>      Override join token"
  exit 1
fi

CP_IP="${CP_IP:-${K3S_CP_IP:-}}"
TOKEN="${TOKEN:-${K3S_TOKEN:-}}"

if [[ -z "$CP_IP" || -z "$TOKEN" ]]; then
  echo "Error: Could not find control plane IP or token."
  echo "  Run 'source /etc/environment' or set CP_IP and TOKEN env vars."
  exit 1
fi

echo "  Control plane : ${CP_IP}"
echo "  Token         : ${TOKEN:0:20}..."
echo ""

SSH_USER="${SSH_USER:-ubuntu}"
GPU="${GPU:-false}"

LABELS=""
if [[ "$GPU" == "true" ]]; then
  LABELS="--node-label node-role=gpu"
fi
if [[ -n "${NODE_LABELS:-}" ]]; then
  for lbl in $(echo "$NODE_LABELS" | tr ',' ' '); do
    LABELS="$LABELS --node-label $lbl"
  done
fi

K3S_URL="https://${CP_IP}:6443"

WORKER_NAMES=()
for WORKER_IP in "$@"; do
  echo "==> Joining ${WORKER_IP} to cluster at ${CP_IP}..."

  if [[ "$GPU" == "true" ]]; then
    echo "    Installing NVIDIA Container Toolkit on ${WORKER_IP}..."
    ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${WORKER_IP}" bash -s <<'NVIDIA_SETUP'
      set -euo pipefail
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg --yes
      curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
      sudo apt-get update -qq && sudo apt-get install -y -qq nvidia-container-toolkit
      sudo nvidia-ctk runtime configure --runtime=containerd
NVIDIA_SETUP
  fi

  # Detect the worker's external IP and pass it to K3s so it shows in kubectl get nodes -o wide
  WORKER_EXT_IP=$(ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${WORKER_IP}" \
    "curl -s ifconfig.me || curl -s icanhazip.com || echo ''")
  EXT_FLAG=""
  if [[ -n "$WORKER_EXT_IP" ]]; then
    EXT_FLAG="--node-external-ip ${WORKER_EXT_IP}"
    echo "    External IP: ${WORKER_EXT_IP}"
  fi

  ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${WORKER_IP}" \
    "curl -sfL https://get.k3s.io | K3S_URL=${K3S_URL} K3S_TOKEN=${TOKEN} sh -s - agent ${EXT_FLAG} ${LABELS}"

  # After K3s join, configure its containerd to use nvidia as default runtime
  if [[ "$GPU" == "true" ]]; then
    echo "    Configuring K3s containerd for NVIDIA runtime on ${WORKER_IP}..."
    ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${WORKER_IP}" bash -s <<'GPU_CONTAINERD'
      set -euo pipefail
      TMPL="/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl"
      if [[ ! -f "$TMPL" ]]; then
        sudo cp /var/lib/rancher/k3s/agent/etc/containerd/config.toml "$TMPL"
      fi
      if ! sudo grep -q 'default_runtime_name = "nvidia"' "$TMPL"; then
        sudo sed -i '/\[plugins."io.containerd.cri.v1.runtime".containerd\]/a\      default_runtime_name = "nvidia"' "$TMPL"
      fi
      if ! sudo grep -q 'nvidia-container-runtime' "$TMPL"; then
        sudo tee -a "$TMPL" > /dev/null <<'EOF'

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.nvidia]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.nvidia.options]
    BinaryName = "/usr/bin/nvidia-container-runtime"
    SystemdCgroup = true
EOF
      fi
      sudo systemctl restart k3s-agent
GPU_CONTAINERD
  fi

  NODE_NAME=$(ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${WORKER_IP}" "hostname")
  WORKER_NAMES+=("$NODE_NAME")
  echo "    ${WORKER_IP} (${NODE_NAME}) joined."
done

echo ""
echo "==> Labeling workers..."
# Use local kubectl if available (e.g. running from laptop with tunnel), otherwise SSH to control plane
if kubectl get nodes &>/dev/null; then
  for NAME in "${WORKER_NAMES[@]}"; do
    kubectl label node "${NAME}" node-role.kubernetes.io/worker=true --overwrite
  done
else
  for NAME in "${WORKER_NAMES[@]}"; do
    ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${CP_IP}" \
      "sudo kubectl label node ${NAME} node-role.kubernetes.io/worker=true --overwrite"
  done
fi

if [[ "$GPU" == "true" ]]; then
  echo ""
  echo "==> Deploying NVIDIA device plugin (enables GPU scheduling)..."
  if kubectl get nodes &>/dev/null; then
    kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.0/deployments/static/nvidia-device-plugin.yml
  else
    ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${CP_IP}" \
      "sudo kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.0/deployments/static/nvidia-device-plugin.yml"
  fi
fi

echo ""
echo "Done. Verify: kubectl get nodes -o wide"