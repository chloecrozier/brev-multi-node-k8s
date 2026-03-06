# brev-multi-node-k8s

Multi-node K8s cluster on Brev. CPU and/or GPU workers.

Uses **K3s** (lightweight Kubernetes). It's a single binary that installs in seconds and runs the full K8s API. The scripts install the latest stable K3s release.

## 1. Create the control plane instance

1. Create a Brev CPU instance for the control plane
2. Open port **6443** on the instance
3. SSH in and clone the repo:

```bash
git clone https://github.com/chloecrozier/brev-multi-node-k8s
cd brev-multi-node-k8s
source ./setup-control-plane.sh
```

Prints the IP, token, and next steps. The token and IP are saved as `$K3S_TOKEN` and `$K3S_CP_IP` env vars (persisted in `/etc/environment`).

## 2. Create worker instances and add them

1. Create one or more Brev instances for workers (CPU or GPU)
2. Open port **10250** and **8472/UDP** on each worker
3. From the **control plane**, run:

```bash
# CPU workers
./add-workers.sh <worker-ip> [worker-ip] ...

# GPU workers
GPU=true ./add-workers.sh <worker-ip> [worker-ip] ...
```

The control plane IP and token are picked up automatically from step 1. Verify with:

```bash
kubectl get nodes -o wide
```

## 3. Schedule from your laptop

Your cluster is on a private network. These commands let you reach it from your laptop so you can schedule workloads with `kubectl`.

```bash
# Download cluster credentials (one time)
brev copy <brev-instance-name>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
# Open tunnel to the API server (keep this running in a terminal)
brev port-forward <brev-instance-name> --port 6443:6443
# In another terminal
kubectl get nodes
```

Use `brev list` to find your instance name.

## Common commands

```bash
kubectl get nodes                         # list nodes
kubectl get pods -o wide                  # list pods + which node
kubectl get nodes -o wide --show-labels   # list nodes + labels
kubectl logs <pod>                        # container output
kubectl apply -f <manifest.yaml>          # schedule a pod
kubectl delete pod <pod>                  # remove a pod
```

## Testing

See `test/README.md`. Test manifests:

- **test-pod.yaml** — Minimal pod. Just checks that scheduling works (pod runs on a worker).
- **test-gpu-pod.yaml** — Runs `nvidia-smi` inside a CUDA container to verify GPU access.
- **capsule-sim.yaml** — Simulates a real capsule workload (hypothesis, dataset, kernel, objective). Logs structured JSON so you can verify external log access.

## Requirements

Both control plane and workers need: Linux, `curl`, `systemd`. K3s handles the rest.

| | Control plane | Workers |
|---|---|---|
| **Ports** | 6443 | 10250, 8472/UDP |
