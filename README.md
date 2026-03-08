# brev-multi-node-k8s

Multi-node K8s cluster on Brev with CPU and/or GPU workers. Uses [K3s](https://k3s.io) (lightweight, CNCF-certified Kubernetes).

## Setup

**Control plane** — create a Brev instance, open port 6443, then SSH in:

```bash
git clone https://github.com/chloecrozier/brev-multi-node-k8s
cd brev-multi-node-k8s
source ./setup-control-plane.sh
```

**Workers** — create worker instances and open port **10250** on each one. Then from the control plane:

```bash
./add-workers.sh <worker-ip> [worker-ip] ...
GPU=true ./add-workers.sh <gpu-worker-ip> [gpu-worker-ip] ...
```

**Schedule from your personal laptop:**
Use `brev list` to find your instance name.

```bash
brev copy <instance-name>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
brev port-forward <instance-name> --port 6443:6443
kubectl get nodes    # in another terminal
```

## GPU Workloads

See `test/README.md`. Example manifests using NVIDIA NGC containers:

- **gpu-smoke-test.yaml** — `nvidia-smi`
- **cuda-nbody.yaml** — CUDA n-body simulation benchmark
- **pytorch-bench.yaml** — matmul TFLOPS benchmark (NGC PyTorch)
- **multi-gpu.yaml** — 2-GPU enumeration and device transfer
- **llm-ollama.yaml** — run any LLM locally on a GPU