# Mock Server
Mock server currently serves three purposes:

- It provides a REST endpoint for GET and POST requests that can be called by other services. It then dumps the JSON payload into its logs. This can be used for debugging whether a webhook has been called and can also be used to inspect the schema of the payload.
- It is an example of how to package an application into a Docker image, upload it to the kind cluster, deploy it using a deployment, and serve it from a service
- It is an example of using selectors to restrict the nodes that Pods can be scheduled on (the kind config specifies that k8splayground-worker is labelled with `mock-server=true`, which mock server selects for; mock server has the same toleration as node-problem-detector, allowing it to run on both workers, to ensure that the reason it is always scheduled on k8splayground-worker is not because it cannot be scheduled on k8splayground-worker2)

Examples of things to experiment with:

- labels and selectors
- the self-healing properties of deployments
- different rollout strategies on the deployment when deploying a new version of mock server
- how to route Kubernetes-internal traffic to the mock-server Pods through its service
- how the Dockerfile definition translates to layers in a Docker image and the effect of layers (requires changing the Makefile)

For how ingress works, see the nginx-ingress application's README.

## Testing
The expected behaviour of the mock-server is to log the JSON payload after logging the request and to return "You hit: \<path the request was directed to>".

If nginx-ingress is running, one can GET or POST to the mock server at http://localhost:80/mock-server from the local machine.

Finally, mock server also logs the signal it receives from Kubernetes when being terminated.

## Commands
```
Apply/update mock server:
make mock_apply

Delete mock server:
make mock_delete

Tail logs:
kubectl logs <Pod name [`kubectl get pods` to find it]> --follow
```
