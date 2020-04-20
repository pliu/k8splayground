# NGINX Ingress
NGINX Ingress is the NGINX implementation of Kubernetes' ingress functionality. Ingress is Kubernetes' mechanism for routing external traffic to internal endpoints. In this project, it is used to simplify interacting with the UIs of many of the other deployed applications (e.g. Prometheus, Grafana, and Alertmanager from prometheus-operator).

As mentioned in the root README, when creating the cluster, we port-forward localhost ports 80 and 443 on the local machine to ports 30000 and 30001 on one of the Docker worker "hosts". nginx-ingress is configured as a NodePort service such that all host traffic on ports 30000 and 30001 is sent to it. NGINX then routes the traffic to its destination based on the configured NGINX rules (configured in Ingress objects), thus completing the routing of traffic from the local machine to a Kubernetes-hosted application.

The convention for this project is for applications that wish to expose endpoints via ingress to supply their own Ingress manifest (e.g., mock-server, prometheus-operator). This is because Ingress is a native Kubernetes type which has no effect in the absense of an Ingress implementation.

Examples of things to experiment with:

- NGINX routing configurations, including target rewrites
- how traffic on the local machine gets routed through the Docker "hosts" into the Kubernetes network and finally to its destination
- how source IP is handled by different configurations of a service
- how the ingress-nginx kubectl plugin can be used to debug

## Testing
See the READMEs of mock-server, prometheus-operator, or argo-cd for how to test that nginx-ingress is routing traffic correctly.

Specifically, mock-server logs the source IP of incoming requests and thus is a good resource for exploring the behavior of various service configurations.

The ingress-nginx kubectl plugin is helpful to explore the state of the NGINX Ingress controller (e.g. the NGINX routing config that is generated based on associated Ingresses, the list of dynamically-discovered backends to which traffic is routed).

## Commands
```
Apply/update NGINX Ingress:
make nginx_apply

Delete NGINX Ingress:
make nginx_delete

View NGINX routing config:
kubectl ingress-nginx conf

View current list of discovered backends:
kubectl ingress-nginx backends
```
