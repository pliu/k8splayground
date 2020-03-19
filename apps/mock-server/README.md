# Mock Server
Mock server currently serves four purposes:

- It provides a POST REST endpoint that can be called by other services. It then dumps the JSON payload into its logs. This can be used for debugging whether a webhook has been called and can also be used to inspect the schema of the payload.
- It is an example of how to package an app into a Docker image, upload it to the kind cluster, deploy it using a deployment, and serve it from a service
- It is an example of how Kubernetes signals to applications within a pod that is about to be terminated (it sends SIGTERM and then waits for a configurable grace period)
- It is an example of using selectors to restrict the nodes that pods can be scheduled on

Examples of things to experiment with:

- labels and selectors
- the self-healing properties of deployments
- different rollout strategies on the deployment when deploying a new version of mock server
- liveness/readiness checks and their effects on whether a pod is routed to
- how to route Kubernetes-internal traffic to the mock-server pods through its service
- how the Dockerfile definition translates to layers in a Docker image and the effect of layers (requires changing the Makefile)
- how to handle SIGTERM and gracefully shutdown an application

For how ingress works, see the nginx-ingress app's README.

## Testing
The expected behavior of the mock-server is to log the JSON payload after logging the request and to return "You hit: <path the request was directed to>".

If nginx-ingress is running, one can GET or POST to the mock server at localhost:80/mock-server from the local machine.

Finally, mock server also logs the signal it receives from Kubernetes when being terminated.

## Commands
```
Apply/update mock server:
make mock_apply

Delete mock server:
make mock_delete

Tail logs:
kubectl logs <pod name [`kubectl get pods` to find it]> --follow
```
