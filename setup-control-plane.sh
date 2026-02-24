#!/usr/bin/env bash
#
# Run this ON the Brev instance you want as your control plane.
# It installs K3s in server mode and prints the join command for workers.
#
set -euo pipefail

EXTERNAL_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "")
INTERNAL_IP=$(hostname -I | awk '{print $1}')

EXTRA_FLAGS=""
if [[ -n "$EXTERNAL_IP" ]]; then
  EXTRA_FLAGS="--node-external-ip ${EXTERNAL_IP}"
fi

echo "==> Installing K3s server (control plane)..."
echo "    Internal IP: ${INTERNAL_IP}"
echo "    External IP: ${EXTERNAL_IP:-none detected}"
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - server ${EXTRA_FLAGS}

echo "==> Waiting for node to be ready..."
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 2; done

kubectl get nodes

TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)

# Save token and IPs as env vars so they can be referenced later
grep -q 'K3S_TOKEN=' /etc/environment 2>/dev/null && sudo sed -i "/K3S_TOKEN=/d" /etc/environment
grep -q 'K3S_CP_IP=' /etc/environment 2>/dev/null && sudo sed -i "/K3S_CP_IP=/d" /etc/environment
grep -q 'K3S_CP_EXTERNAL_IP=' /etc/environment 2>/dev/null && sudo sed -i "/K3S_CP_EXTERNAL_IP=/d" /etc/environment
echo "K3S_TOKEN=${TOKEN}" | sudo tee -a /etc/environment > /dev/null
echo "K3S_CP_IP=${INTERNAL_IP}" | sudo tee -a /etc/environment > /dev/null
echo "K3S_CP_EXTERNAL_IP=${EXTERNAL_IP}" | sudo tee -a /etc/environment > /dev/null
export K3S_TOKEN="$TOKEN"
export K3S_CP_IP="$INTERNAL_IP"
export K3S_CP_EXTERNAL_IP="$EXTERNAL_IP"

# Copy token to user-readable location so `brev copy` can grab it
cp /var/lib/rancher/k3s/server/node-token "$HOME/.k3s-token" 2>/dev/null || \
  sudo cp /var/lib/rancher/k3s/server/node-token "$HOME/.k3s-token"
chmod 644 "$HOME/.k3s-token"

echo ""
echo "============================================"
echo "  Control plane is ready!"
echo "============================================"
echo ""
echo "To add workers, SSH into each worker node and run:"
echo ""
echo "  curl -sfL https://get.k3s.io | K3S_URL=https://${IP}:6443 K3S_TOKEN=${TOKEN} sh -"
echo ""
echo "Or use the add-workers script from your laptop:"
echo ""
echo "  ./add-workers.sh ${IP} ${TOKEN} <worker-ip-1> <worker-ip-2> ..."
echo ""
echo "To connect from your laptop (via Brev):"
echo ""
echo "  brev copy $(hostname):/etc/rancher/k3s/k3s.yaml ~/.kube/config"
echo "  brev port-forward $(hostname) --port 6443:6443"
echo "  kubectl get nodes"
echo ""