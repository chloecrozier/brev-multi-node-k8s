#!/usr/bin/env bash
#
# Run this ON the Brev instance you want as your control plane.
# It installs K3s in server mode and prints the join command for workers.
#
set -euo pipefail

echo "==> Installing K3s server (control plane)..."
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -

echo "==> Waiting for node to be ready..."
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 2; done

kubectl get nodes

TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
IP=$(hostname -I | awk '{print $1}')

# Save token and IP as env vars so they can be referenced later
grep -q 'K3S_TOKEN=' /etc/environment 2>/dev/null && sudo sed -i "/K3S_TOKEN=/d" /etc/environment
grep -q 'K3S_CP_IP=' /etc/environment 2>/dev/null && sudo sed -i "/K3S_CP_IP=/d" /etc/environment
echo "K3S_TOKEN=${TOKEN}" | sudo tee -a /etc/environment > /dev/null
echo "K3S_CP_IP=${IP}" | sudo tee -a /etc/environment > /dev/null
export K3S_TOKEN="$TOKEN"
export K3S_CP_IP="$IP"

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