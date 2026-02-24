# brev-multi-node-k8s

Turn Brev instances into a K8s cluster. Two scripts.

## Requirements

| | Control plane | Workers |
|---|---|---|
| **Brev instance type** | CPU (no GPU needed) | CPU and/or GPU |
| **OS** | Linux (Ubuntu recommended) | Linux (Ubuntu recommended) |
| **Ports open** | 6443 (K8s API) | outbound to control plane :6443 |
| **SSH** | you can SSH in | control plane (or your laptop) can SSH in |

Both need: `curl`, `systemd`. That's it — K3s handles everything else.

## Usage

### 1. Control plane

SSH into your Brev CPU instance and run:

```bash
./setup-control-plane.sh
```

It prints the **IP** and **token** needed to join workers.

### 2. Add workers

From your laptop (or the control plane):

```bash
# CPU workers
./add-workers.sh <cp-ip> <token> <worker-ip-1> <worker-ip-2> ...

# GPU workers
GPU=true ./add-workers.sh <cp-ip> <token> <gpu-ip-1> ...
```

### 3. Verify

```bash
kubectl get nodes
```

## Options for `add-workers.sh`

| Env var | Default | Description |
|---------|---------|-------------|
| `SSH_USER` | `ubuntu` | SSH user for workers |
| `GPU` | `false` | Label workers `node-role=gpu` |
| `NODE_LABELS` | — | Extra labels, comma-separated |

## Kubeconfig

```bash
scp ubuntu@<cp-ip>:/etc/rancher/k3s/k3s.yaml ./kubeconfig
sed -i '' 's/127.0.0.1/<cp-ip>/g' ./kubeconfig
export KUBECONFIG=./kubeconfig
```