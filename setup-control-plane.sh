#!/usr/bin/env bash
#
# Run this ON the Brev instance you want as your control plane.
# It installs K3s in server mode and prints the join command for workers.
#
# Usage:  source ./setup-control-plane.sh
#         (use "source" so $K3S_TOKEN is available in your shell after)
#
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Sourced — don't set -e or it will kill the parent shell on error
  set -uo pipefail
else
  set -euo pipefail
fi

EXTERNAL_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "")
INTERNAL_IP=$(hostname -I | awk '{print $1}')

EXTRA_FLAGS=""
if [[ -n "$EXTERNAL_IP" ]]; then
  EXTRA_FLAGS="--node-external-ip ${EXTERNAL_IP}"
fi

echo "==> Installing K3s server (control plane)..."
echo "    Internal IP: ${INTERNAL_IP}"
echo "    External IP: ${EXTERNAL_IP:-none detected}"
if [[ -x /usr/local/bin/k3s-killall.sh ]]; then
  echo "    Cleaning up previous K3s processes..."
  sudo /usr/local/bin/k3s-killall.sh
fi

curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - server ${EXTRA_FLAGS}
sudo systemctl restart k3s

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

# Copy token to user-readable location so `brev copy` can grab it
sudo cp /var/lib/rancher/k3s/server/node-token "$HOME/.k3s-token"
sudo chown "$(id -u):$(id -g)" "$HOME/.k3s-token"
sudo chmod 644 "$HOME/.k3s-token"

HOSTNAME=$(hostname)

cat <<EOF

============================================
  Control plane is ready!
============================================

  Internal IP : ${INTERNAL_IP}
  External IP : ${EXTERNAL_IP:-none}
  Hostname    : ${HOSTNAME}
  Token       : ${SHORT_TOKEN}
  Full token  : echo \$K3S_TOKEN  or  cat ~/.k3s-token

--------------------------------------------
  NEXT STEPS
--------------------------------------------

  1) Add workers (run from this control plane):

     ./add-workers.sh <worker-ip> [worker-ip] ...

     GPU workers:
     GPU=true ./add-workers.sh <worker-ip> [worker-ip] ...

  2) Schedule from your laptop:

     Replace <brev-instance-name> with your Brev instance name
     (run "brev list" to find it — it is NOT the hostname above).

     brev copy <brev-instance-name>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
     brev port-forward <brev-instance-name> --port 6443:6443
     kubectl get nodes    # run in a second terminal

EOF

source /etc/environment