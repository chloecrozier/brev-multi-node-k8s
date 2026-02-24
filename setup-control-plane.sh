#!/usr/bin/env bash
#
# Run this ON the Brev instance you want as your control plane.
# It installs K3s in server mode and prints the join command for workers.
#
set -euo pipefail

echo "==> Installing K3s server (control plane)..."
curl -sfL https://get.k3s.io | sh -

echo "==> Waiting for node to be ready..."
until sudo kubectl get nodes | grep -q " Ready"; do sleep 2; done

sudo kubectl get nodes

TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
IP=$(hostname -I | awk '{print $1}')

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
echo "To use kubectl from your laptop, copy the kubeconfig:"
echo ""
echo "  scp $(whoami)@${IP}:/etc/rancher/k3s/k3s.yaml ./kubeconfig"
echo "  sed -i '' 's/127.0.0.1/${IP}/g' ./kubeconfig   # macOS"
echo "  export KUBECONFIG=./kubeconfig"
echo ""