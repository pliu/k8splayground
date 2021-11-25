# K8sPlayground
K8sPlayground is a kind-based (Kubernetes in Docker) environment built to facilitate experimentation with a tight feedback loop, thus accelerating learning and understanding of containers, Kubernetes, and related tooling and applications.

As its name suggests, kind works by spinning up Docker containers to act as "hosts" in a Kubernetes cluster. These Docker "hosts" are subsequently managed by kubeadm to set up Kubernetes components (e.g., kubelet, etcd, api-server, controller-manager, scheduler, coreDNS, kube-proxy). We have disabled kindnet - the default kind CNI plugin - in favor of using Calico, which is installed as part of the Makefile target after the kind cluster is created.

When the cluster is started, localhost ports 80 and 443 will be mapped to one of the Docker worker "hosts" and localhost port 2379 will be mapped to the Docker control plane "host" (specified in kind/config.yaml).

Examples of things to experiment with:

- kubectl commands
- how Kubernetes networking works (e.g., look at ip routes on the Docker "hosts")
- how Helm works
- how kubeadm works
- explore various kubectl plugins
- using a GUI (lens) to explore Kubernetes state

You can destroy and recreate the cluster to reset it if during the course of experimentation the cluster gets into a bad state - a major benefit of having such a local test environment.

## Components used in setting up this project
```
docker 19.03.6
kind 0.11.1
helm v3.1.1 (v3+ is required due to folding requirements.yaml into Chart.yaml)
kubectl 1.17.3
promtool (for Prometheus rules' tests)
conftest 0.17.1 (for checking Helm-generated manifests against Rego rules)
kubectl-krew v0.3.4 (for installing kubectl plugins)
terraform v0.12.24
provider.rancher2 v1.8.3 (for managing Rancher through Terraform)
etcdctl 3.4.9
lens 3.5.1
go 1.13.5, 1.17.1
fluent-bit v1.5.6
```

## Repository structure
```
root
|- apps
|  |- ...
|     |- templates?
|     |  |- ...
|     |- Chart.yaml
|     |- README.md?
|     |- values.yaml?
|     |- ...
|- auth
|  |- terraform
|  |  |- README.md
|  |  |- ...
|  |- README.md
|  |- ...
|- conftest-checks
|  |- README.md
|  |- ...
|- k8s-behaviour
|  |- README.md
|  |- ...
|- kind
|  |- config.yaml
|- pod-behaviour
|  |- README.md
|  |- ...
|- Makefile
|- README.md
```
The kind folder contains the cluster configuration (config.yaml).

Current applications include:
- [NGINX Ingress](apps/nginx-ingress/README.md)
- [Argo CD](apps/argo-cd/README.md)
- [kube-prometheus-stack](apps/kube-prometheus-stack/README.md)
- [node-problem-detector](apps/node-problem-detector/README.md)
- [mock server](apps/mock-server/README.md)
- [Airflow](apps/airflow/README.md)
- [distributor](apps/distributor/README.md)
- [logging](apps/logging/README.md)

Each application folder contains, at the very least, its own README - with more information on what the application does and how to use it - and Chart.yaml. The Chart.yaml contains some basic metadata about the chart (the package of Kubernetes manifests that defines the Kubernetes objects required to deploy the application) such as name, version, and any dependencies. In addition, it may contain a templates folder that contains the templates from which the actual manifests are rendered. The values used in the rendering are found in the values.yaml file. If none of the templates require rendering, then no values.yaml is needed (e.g., mock-server). If including another chart as a dependency, one can configure the imported chart using the values.yaml file (e.g., kube-prometheus-stack, nginx-ingress).

auth contains documentation and tools to learn about authentication and authorization in Kubernetes and Rancher, an external cluster manager. The scripts folder contains helper scripts related to user creation and permissioning through Kubernetes and accessing Kubernetes directly as these newly-created users. The config folder contains the kubeconfig files for these users. Documentation related to authentication and authorization can be found [here](auth/README.md). Additionally, Terraform can be used to manage Rancher with examples located in the terraform folder (with documentation [here](auth/terraform/README.md)).

conftest-checks contains a suite of Rego rules against which Helm-generated manifests should be checked for correctness. Documentation can be found [here](conftest-checks/README.md).

k8s-behaviour contains a set of manifests, scripts, and instructions for experimenting with Kubernetes behaviour (e.g., dangling resources, kubelet failure) and internal state. After the pod-behaviour module, this is a good module to continue with. Documentation can be found [here](k8s-behaviour/README.md).

pod-behaviour contains a set of Dockerfiles, manifests, and instructions for experimenting with container and Pod behaviour (e.g., termination grace period, shutdown hooks and signals, exit codes and restart policies). This is a good module to start with as containers are at the heart of Kubernetes. Documentation can be found [here](pod-behaviour/README.md).

## Application deployment
There are two ways to deploy applications in K8sPlayground: Helm and Argo CD. The two methods, as set up in this project, are mutually exclusive as they are configured to deploy the same applications with the same names in the same namespaces.

The Makefile targets for applying/deleting applications found in the READMEs of the various applications use Helm-driven deployment. These targets are written to create the application if it doesn't exist and to update it otherwise.

The Argo CD Makefile targets are no different and use Helm to apply/delete Argo CD, which subsequently deploys other applications. For more information on how to manage Argo CD-driven application deployment, see Argo CD's README.

## Image caching and preloading
As K8sPlayground has expanded, the aggregate size of the applications' images has increased substantially (~1.5 GB when last checked). Since destroying the kind cluster wipes the "hosts"' state, everytime the cluster is created and applications deployed to it, all applicable images must be redownloaded. On a good connection (~15 MB/s), it would take a bit under 2 minutes to download the images, with times increasing to over 10 minutes if the speed drops below 2.5 MB/s.

To address this issue, all Makefile targets for applying applications pull the images required for their respective charts (as determined by the "images" file located in the application's folder) to the local Docker store. This pull only happens once per image so long as the image isn't deleted from the local Docker store as Docker will recognize that it has already cached the image on subsequent pull attempts. Under normal circumstances, though, the kind "hosts" will still directly pull the images they require. However, by setting the PRELOAD environment variable (e.g., `PRELOAD=on make apply_all`, `PRELOAD=on make argo_apply`), the Makefile targets will preload the required images to the kind "hosts" from the local Docker store using `kind load`, essentially eliminating their need to pull images.

On a good connection, it is still recommended to have the kind "hosts" pull their required images directly. This is because `kind load` loads the image onto all of the kind "hosts" regardless of whether it is used on a given "host". As the majority of applications in K8sPlayground, including the three largest images, only run on a single host, this extra copying is both wasteful and itself fairly slow.

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
```
