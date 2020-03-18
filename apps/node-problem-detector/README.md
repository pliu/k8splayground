# Node Problem Detector
Node problem detector is a framework that continuously runs tests against the nodes in a cluster.

It uses a daemon set to deploy onto all eligible nodes (some nodes may be tainted with properties that node problem detector does not tolerate). The pods then mount a ConfigMap object containing the test configurations and custom test scripts. If using custom test scripts, a non-zero return value indicates failure while a return value of 0 indicates the test passed. Additionally, it mounts /usr from the host's filesystem (the Docker "host", not the local machine), giving it access to the binaries in that path.

When tests fail, node problem detector emits events or marks the affected node with a condition. Node problem detector also has a metrics endpoint that exposes test status (problem_gauge) and failure counts (problem_counter) that is scraped by Prometheus (see prometheus-operator).

Examples of things to experiment with:

- the effects of node taints and pod tolerations
- the self-healing properties of daemon sets
- RBAC permissions (e.g. node-problem-detector needs permission to update nodes)
- mounting branches of the host's filesystem into a container
- adding new tests

## Testing
If prometheus-operator is running, the metrics will be viewable in Prometheus. Describing a node would show any conditions or events attached to it by the node problem detector.

To determine if mounting is working as intended, one can exec into the container to inspect the filesystem.

## Commands
```
Apply/update node problem detector:
make npd_apply

Delete node problem detector:
make npd_delete

Get a shell into the node-problem-detector container:
kubectl exec -it <pod name [`kubectl get pods -n kube-system` to find it]> -n kube-system /bin/bash
```
