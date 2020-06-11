# Node Problem Detector
Node problem detector is a framework that continuously runs tests against the nodes in a cluster.

It uses a daemon set to deploy onto all eligible nodes. The kind config specifies that k8splayground-worker2 is tainted with `playground_test=ensure_only_tolerations_run_here:NoSchedule` (NoExecute is also possible) and k8splayground-control-plane, by virtue of being a control plane node, comes tainted with `node-role.kubernetes.io/master:NoSchedule`. As node-problem-detector is configured to tolerate `playground_test:NoSchedule`, it can be scheduled on k8splayground-worker and k8splayground-worker2, though not on k8splayground-control-plane, whereas Pods without a toleration for `playground_test:NoSchedule` would not even be schedulable on k8splayground-worker2 (you can use the `-o wide` option with `kubectl get pods` to display the node that each Pod runs on).

The Pods then mount a ConfigMap object containing the test configurations and custom test scripts. If using custom test scripts, a non-zero return value indicates failure while a return value of 0 indicates the test passed. Additionally, it mounts /usr from the host's filesystem (the Docker "host", not the local machine), giving it access to the binaries in that path.

When tests fail, node problem detector emits events or marks the affected node with a condition. Node problem detector also has a metrics endpoint that exposes test status (problem_gauge) and failure counts (problem_counter) that is scraped by Prometheus (see prometheus-operator).

Examples of things to experiment with:

- the effects of node taints and Pod tolerations (and the difference between NoSchedule and NoExecute)
- the self-healing properties of daemon sets
- RBAC permissions (e.g. node-problem-detector needs permission to update nodes)
- mounting branches of the host's filesystem into a container
- adding new tests to node-problem-detector

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
kubectl exec -it <Pod name [`kubectl get pods -n kube-system` to find it]> -n kube-system /bin/bash
```
