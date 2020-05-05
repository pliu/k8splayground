# K8sPlayground
K8sPlayground is a kind-based (Kubernetes in Docker) environment built to facilitate experimentation with a tight feedback loop, thus accelerating learning and understanding of k8s, related tooling, and k8s applications.

As its name suggests, kind works by spinning up Docker containers to act as "hosts" in a Kubernetes cluster. These Docker "hosts" are subsequently managed by kubeadm to set up Kubernetes components (e.g., kubelet, etcd, api-server, controller-manager, scheduler, kindnet [CNI implementation], coreDNS, kube-proxy).

When the cluster is started, localhost ports 80 and 443 will be mapped to one of the Docker worker "hosts" (specified in kind/config.yaml).

Examples of things to experiment with:

- kubectl commands
- how Kubernetes networking works (e.g. look at ip routes on the Docker "hosts")
- the effect of deleting hosts (Docker "hosts", in this case)
- how Helm works
- how kubeadm works
- explore various kubectl plugins

You can destroy and recreate the cluster to reset it if during the course of experimentation the cluster gets into a bad state - a major benefit of having such a local test environment.

## Components used in setting up this project
```
docker 19.03.6
kind 0.7.0 (0.7.0+ is required for disk access)
helm v3.1.1 (v3+ is required due to folding requirements.yaml into Chart.yaml)
kubectl 1.17.3
promtool (for Prometheus operator rules' tests)
conftest 0.17.1 (for checking Helm-generated manifests against Rego rules)
kubectl-krew v0.3.4 (for installing kubectl plugins)
terraform v0.12.24
provider.rancher2 v1.8.3 (for managing Rancher through Terraform)
```

## Repository structure
```
root
|- apps
|  |- ...
|     |- templates?
|     |  |- ...
|     |- Chart.yaml
|     |- README.md
|     |- values.yaml?
|- auth
|  |- config
|  |  |- ...
|  |- scripts
|  |  |- ...
|  |- terraform
|  |- |- init
|  |  |  |- ...
|  |  |- manage
|  |  |  |- ...
|  |  |- README.md
|  |- README.md
|- conftest-checks
|  |- README.md
|  |- ...
|- kind
|  |- config.yaml
|- Makefile
|- README.md
```
The kind folder contains the cluster configuration (config.yaml).

Current applications include:
- [NGINX Ingress](apps/nginx-ingress/README.md)
- [Argo CD](apps/argo-cd/README.md)
- [Prometheus Operator](apps/prometheus-operator/README.md)
- [node-problem-detector](apps/node-problem-detector/README.md)
- [mock server](apps/mock-server/README.md)

Each application folder contains, at the very least its own README, with more information on what the application does and how to use it, and Chart.yaml. The Chart.yaml contains some basic metadata about the chart (the package of Kubernetes manifests that defines the Kubernetes objects required to deploy the application) such as name, version, and any dependencies. In addition, it may contain a templates folder that contains the templates from which the actual manifests are rendered. The values used in the rendering are found in the values.yaml file. If none of the templates require rendering, then no values.yaml is needed (e.g. mock-server). If including another chart as a dependency, one can configure the imported chart using the values.yaml file (e.g. prometheus-operator, nginx-ingress).

auth contains documentation and tools to learn about authentication and authorization in Kubernetes and Rancher, an external cluster manager. The scripts folder contains helper scripts related to user creation and permissioning through Kubernetes and accessing Kubernetes directly as these newly-created users. The config folder contains the kubeconfig files for these users. Documentation can be found [here](auth/README.md).

conftest-checks contains a suite of Rego rules against which Helm-generated manifests should be checked for correctness. Documentation can be found [here](conftest-checks/README.md).

The Makefile contains targets for creating and destroying the cluster, applying and deleting the various applications, and other helpers (e.g. running Prometheus rule tests).

## Application deployment
There are two ways to deploy applications in K8sPlayground: Helm and Argo CD. The two methods, as set up in this project, are mutually exclusive as they are configured to deploy the same applications with the same names in the same namespaces. 

The Makefile targets for applying/deleting applications found in the READMEs of the various applications use Helm-driven deployment. These targets are written to create the application if it doesn't exist and to update it otherwise.

The Argo CD Makefile targets are no different and use Helm to apply/delete Argo CD, which subsequently deploys other applications. For more information on how to manage Argo CD-driven application deployment, see Argo CD's README.

## Commands
```
Create kind cluster:
make kind_create

Destroy kind cluster:
make kind_destroy

Apply all applications with Helm (except argo-cd and argo-apps):
make apply_all

Check which applications are currently applied with Helm:
helm list --all-namespaces

Run all conftest checks:
make conftest_all

Discover kubectl plugins:
kubectl krew update && kubectl krew search

Install kubectl plugin:
kubectl krew install <plugin name>

List installed kubectl plugins:
kubectl krew list

Uninstall kubectl plugin:
kubectl krew uninstall <plugin name>

Get a shell into a Docker "host":
docker exec -it <container name [`docker ps` to find it]> /bin/bash
```
