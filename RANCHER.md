# Rancher
Rancher is a Kubernetes cluster manager. It can be used to launch new Kubernetes clusters, manage existing ones (explore Kubernetes in manner similar to kubectl but graphically), deploy and manage applications via Helm charts, monitor, alert, and aggregate logs across clusters, and provides user and group management and authorization capabilities. We will use Rancher primarily for its user and group management and authorization capabilities as we use Helm directly to deploy and manage applications and Prometheus Operator for monitoring and alerting.

We run Rancher in a Docker container alongside the kind "hosts". When creating the Rancher container, we port-forward localhost ports 81 and 443 to ports 80 and 443 of the Rancher container (specified in the Makefile), allowing us to access the Rancher UI.

Unfortunately, many of the steps to set up Rancher must be done through its UI, which is why there are no Makefile targets to execute them. To import the kind cluster into Rancher:

1. Start the Rancher server. Note down its Docker network IP. If you forgot to do this, you can find it later by running
```
docker inspect <container name> -f '{{json .NetworkSettings.Networks.bridge.IPAddress }}'
```
2. Go to its UI (localhost:81/) and set an admin password
3. Set the Rancher Server URL to be the Rancher Docker network IP from step 1 (the Rancher container sits in the same network as the kind "hosts" and this is its IP within that network, thus allowing the kind "hosts" to connect to it)
4. Add Cluster -> Import an existing cluster -> give the cluster a name -> Create
5. Run the 'curl --insecure' command to add the cluster

Examples of things to experiment with:

- creating new users and user groups
- adding permissions to users and groups

## Managing users, groups, and permissions


## Commands
```
Start Rancher server:
make rancher_start

Stop Rancher server:
make rancher_stop
```
