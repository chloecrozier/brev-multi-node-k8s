# brev-multi-node-k8s

Multi-node K8s cluster on Brev. CPU and/or GPU workers.

Uses **K3s** (lightweight Kubernetes). It's a single binary that installs in seconds and runs the full K8s API. The scripts install the latest stable K3s release.

## 1. Set up control plane

SSH into a Brev CPU instance and run:

```bash
./setup-control-plane.sh
```

Prints the IP, token, and next steps. The token and IP are also saved as `K3S_TOKEN` and `K3S_CP_IP` env vars on the control plane.

To retrieve the token later:

```bash
# From the control plane
echo $K3S_TOKEN
# Or directly
sudo cat /var/lib/rancher/k3s/server/node-token
```

## 2. Add workers

Pass the IP and token from step 1, then as many worker IPs as you want. Run it once for CPU, once for GPU (or both, or just one).

```bash
# CPU workers
./add-workers.sh <cp-ip> <token> <ip> <ip> <ip>

# GPU workers (labels them so you can schedule GPU jobs to these nodes)
GPU=true ./add-workers.sh <cp-ip> <token> <ip> <ip>
```

## 3. Connect externally

Your cluster is on a private network. These two commands let you reach it from your laptop — first downloads the credentials, then opens a tunnel.

```bash
# Download cluster credentials (one time)
brev copy <cp-instance-name>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
# Open tunnel to the API server (keep this running)
brev port-forward <cp-instance-name> --port 6443:6443
# Test
kubectl get nodes
```

## Common commands

```bash
kubectl get nodes                         # list nodes
kubectl get pods -o wide                  # list pods + which node
kubectl get nodes -o wide --show-labels   # list pods + labels
kubectl logs <pod>                        # container output
kubectl apply -f <manifest.yaml>          # schedule a pod
kubectl delete pod <pod>                  # remove a pod
```

## Testing

See `test/README.md`. Two test manifests:

- **test-pod.yaml** — Minimal pod. Just checks that scheduling works (pod runs on a worker).
- **capsule-sim.yaml** — Simulates a real capsule workload (hypothesis, dataset, kernel, objective). Logs structured JSON so you can verify external log access.

## Requirements

Both control plane and workers need: Linux, `curl`, `systemd`. K3s handles the rest.

| | Control plane | Workers |
|---|---|---|
| **Ports** | 6443 | 10250, 8472/UDP |