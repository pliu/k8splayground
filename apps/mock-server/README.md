# Mock Server
Mock server currently serves two purposes:

- It provides a POST REST endpoint that can be called by other services. It then dumps the JSON payload into its logs. This can be used for debugging whether a webhook has been called and can also be used to inspect the schema of the payload.
- It is an example of how to package an app into a Docker image, upload it to the kind cluster, deploy it using a deployment, and serve it from a service

Examples of things to experiment with:

- different rollout strategies on the deployment when deploying a new version of mock server
- liveness/readiness checks and their effects on whether a pod is routed to
- how to route k8s-external and -internal traffic to the mock-server pods through its service
- how the Dockerfile definition translates to layers in a Docker image and the effect of layers (requires changing the Makefile)

For how ingress works, see the nginx-ingress app's README.

## Testing
The expected behavior of the mock-server is to print any JSON payload to its logs after logging the request and to return "Hey, we have Flask in a Docker container!".

If nginx-ingress is running, you can GET or POST to the mock server at localhost:80/mock-server. Otherwise, it can be accessed via port-forwarding at localhost:\<chosen-port>.

## Commands
```
Apply/update mock server:
make mock_apply

Delete mock server:
make mock_delete

Tail logs:
kubectl logs <pod name [`kubectl get pods` to find it]> --follow

Port-forward:
kubectl port-forward svc/mock-service <chosen port>:80
```
