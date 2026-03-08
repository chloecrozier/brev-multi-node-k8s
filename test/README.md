# GPU Workloads

All manifests use NVIDIA containers from [NGC](https://catalog.ngc.nvidia.com) and run on GPU worker nodes.

## Smoke test — `nvidia-smi`

```bash
kubectl apply -f test/gpu-smoke-test.yaml
kubectl logs gpu-smoke-test
```

## CUDA nbody simulation

NVIDIA's n-body gravitational sim benchmark (512k bodies).

```bash
kubectl apply -f test/cuda-nbody.yaml
kubectl logs -f cuda-nbody
```

## PyTorch matmul benchmark

Matrix multiply at increasing sizes, reports TFLOPS. Uses NVIDIA NGC PyTorch.

```bash
kubectl apply -f test/pytorch-bench.yaml
kubectl logs -f pytorch-bench
```

## Multi-GPU test (2 GPUs)

Enumerates GPUs and tests device-to-device transfer.

```bash
kubectl apply -f test/multi-gpu.yaml
kubectl logs multi-gpu
```

## LLM inference — Ollama

Run any LLM on a GPU.

```bash
kubectl apply -f test/llm-ollama.yaml
kubectl exec ollama -- ollama pull llama3.2:1b
kubectl exec ollama -- ollama run llama3.2:1b "What is Kubernetes?"
```

## Cleanup

```bash
kubectl delete pod gpu-smoke-test cuda-nbody pytorch-bench multi-gpu ollama
```