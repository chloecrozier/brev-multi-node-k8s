# Submitting workloads from an external device

All commands run from your laptop. Make sure you've connected first (main README step 3).

## 1. Quick test — schedule a single pod

```bash
kubectl apply -f test/test-pod.yaml
kubectl get pod sandbox-test -o wide       # check it landed on a worker
kubectl delete pod sandbox-test
```

## 2. Capsule simulation — submit, monitor, read results, clean up

Submits two capsule pods. Each runs a hypothesis evaluation (load dataset, run kernel, evaluate objective) and logs structured JSON.

**Submit:**

```bash
kubectl apply -f test/capsule-sim.yaml
```

**Monitor the pool:**

```bash
kubectl get pods -l role=sandbox -o wide
```

**Read results (from your laptop):**

```bash
kubectl logs capsule-1
kubectl logs capsule-2
```

Example output:

```json
{"event": "capsule_start", "hypothesis": "Gene X expression correlates with treatment response", "dataset": "patient_rnaseq_batch_42", "objective": "Validate correlation via DE analysis", "kernel": "python3"}
{"event": "loading_dataset", "status": "complete"}
{"event": "running_kernel", "status": "complete"}
{"event": "evaluating_objective", "status": "complete"}
{"event": "capsule_done", "result": "hypothesis_supported", "p_value": 0.003}
```

**Deallocate:**

```bash
kubectl delete pod capsule-1 capsule-2
```

## 3. Get status programmatically

For scripts or a dataset server that needs machine-readable output:

```bash
# JSON status of all sandbox pods
kubectl get pods -l role=sandbox -o json

# Just names and phases
kubectl get pods -l role=sandbox -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Stream logs in real time
kubectl logs -f <pod-name>
```
