# K8sPlayground

K8sPlayground is a kind-based (Kubernetes in Docker) environment built to facilitate experimentation with a tight feedback loop, thus accelerating learning and understanding of k8s, related tooling, and k8s apps.

As its name suggests, kind works by spinning up Docker containers to act as "hosts" in a Kubernetes cluster. These Docker "hosts" are subsequently managed by kubeadm to set up Kubernetes components (e.g., kubelet, etcd, api-server, controller-manager, scheduler, kindnet [CNI implementation], coreDNS, kube-proxy).

When the cluster is started, localhost:80 will be mapped to one of the Docker worker "hosts" (specified in kind/config.yaml).

Examples of things to experiment with:

- kubectl commands
- how Kubernetes networking works (e.g. look at ip routes on the Docker "hosts")
- the effect of deleting hosts (Docker "hosts", in this case)
- how Helm works
- how kubeadm works

You can destroy and recreate the cluster to reset it if during the course of experimentation the cluster gets into a bad state - a major benefit of having such a local test environment.

## Components used in setting up this project
```
kind 0.7.0 (0.7.0+ is required for disk access)
helm v3.1.1 (v3+ is required due to folding requirements.yaml into Chart.yaml)
kubectl 1.17.3
promtool (for Prometheus operator alerting rules' unit tests)
```

## Repository structure
```
root
|- kind
|- |- config.yaml
|- apps
|  |- README.md
|  |- Chart.yaml
|  |- templates?
|  |  |- ...
|  |- values.yaml?
|- Makefile
```
The kind folder contains the cluster configuration (config.yaml).

Current apps include:
```
NGINX Ingress
Prometheus Operator
node-problem-detector
mock server
```
Each app folder contains, at the very least its own README, with more information on what the app does and how to use it, and Chart.yaml. The Chart.yaml contains some basic metadata about the chart (the package of Kubernetes manifests that defines the Kubernetes objects required to deploy the app) such as name, version, and any dependencies. In addition, it may contain a templates folder that contains the templates from which the actual manifests are rendered. The values used in the rendering are found in the values.yaml file. If none of the templates require rendering, then no values.yaml is needed (e.g. mock-server). If including another chart as a dependency, one can configure the imported chart using the values.yaml file (e.g. prometheus-operator, nginx-ingress).

The Makefile contains targets for creating and destroying the cluster, applying and deleting the various apps, and other helpers (e.g. running Prometheus rule unit tests). The app application targets are written to create the app if it doesn't exist and to update it otherwise.

## Commands
```
Create the k8s cluster:
make kind_create

Destroy the k8s cluster:
make kind_destroy

Apply all apps:
make apply_all

Check which apps are currently deployed:
helm list --all-namespaces
```
