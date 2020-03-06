# K8sPlayground

K8sPlayground is a self-contained repo consisting of resources to set up and play around with k8s, related tooling (e.g. Helm), and k8s apps (e.g., Prometheus operator, node problem detector).

## Components used in setting up this project
```
kind 0.7.0 (0.7.0+ is required for disk access)
helm v3.1.1 (v3+ is required due to folding requirements.yaml into Chart.yaml)
kubectl 1.17.3
promtool (for Prometheus operator alerting rules' unit tests)
```

## Commands
```
Create the k8s cluster:
make kind_create

Destroy the k8s cluster:
make kind_destroy

Check which apps are currently deployed:
helm list --all-namespaces
```
