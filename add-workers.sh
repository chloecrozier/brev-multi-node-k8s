#!/usr/bin/env bash
#
# Add worker nodes to your K3s cluster.
#
# Usage:
#   ./add-workers.sh <control-plane-ip> <token> <worker-ip-1> [worker-ip-2] ...
#
# Options (via env vars):
#   SSH_USER     - SSH user for worker nodes (default: ubuntu)
#   GPU          - Set to "true" to label workers as gpu nodes (default: false)
#   NODE_LABELS  - Extra comma-separated labels (e.g. "role=sandbox,team=bio")
#
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: ./add-workers.sh <control-plane-ip> <token> <worker-ip> [worker-ip] ..."
  echo ""
  echo "  control-plane-ip : IP of the control plane node"
  echo "  token            : K3s node token (printed by setup-control-plane.sh)"
  echo "  worker-ip        : one or more worker IPs to join"
  echo ""
  echo "Env vars:"
  echo "  SSH_USER=ubuntu    SSH user for workers"
  echo "  GPU=true           Label workers with node-role=gpu"
  echo "  NODE_LABELS=k=v    Extra K3s node labels"
  exit 1
fi

CP_IP="$1"; shift
TOKEN="$1"; shift

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
  ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${WORKER_IP}" \
    "curl -sfL https://get.k3s.io | K3S_URL=${K3S_URL} K3S_TOKEN=${TOKEN} sh -s - agent ${LABELS}"
  NODE_NAME=$(ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${WORKER_IP}" "hostname")
  WORKER_NAMES+=("$NODE_NAME")
  echo "    ${WORKER_IP} (${NODE_NAME}) joined."
done

echo ""
echo "==> Labeling workers with role=worker..."
for NAME in "${WORKER_NAMES[@]}"; do
  ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${CP_IP}" \
    "sudo kubectl label node ${NAME} node-role.kubernetes.io/worker=true --overwrite"
done

echo ""
echo "Done. Verify from control plane: kubectl get nodes"