# Distributor
Distributor is a proof-of-concept, distributed semaphore that can be run as a sidecar alongside other workloads.

It uses annotations on a ConfigMap object to store the total resource counts as well as current resource assignments (in both cases, using string-serialized JSON). Furthermore, it makes use of Kubernetes' ordering guarantees - each object is associated with a version and when trying to write a new version to etcd, the API server ensures the new version is based off of the latest version. It is this property that distributor leans on to ensure concurrent writers do not stomp on each other.

Distributor currently has the following behaviour (in all below cases, hosts refers to individual Pods):

- each instance of distributor runs every 50-70s
- each run starts by cleaning existing assignments (i.e., removing assignments to hosts that no longer exist)
- each run then looks for free resources and, if there are any, claims one for its host

The above results in a decentralized system that automatically distributes resources across a set of hosts, even as hosts join and leave the set.

The two annotation fields distributor makes use of are:

- distributor_capacity whose entries are of the form \<resource name>: \<resource count>
- distributor_assignment whose entries are of the form \<hostname>: \<resource name assigned to this host>

Examples of things to experiment with:

- using ServiceAccounts, Roles, and RoleBindings to provide permissions to apps running within Kubernetes
- determining the concurrency model of Kubernetes objects (e.g., can writes stomp on each other)
- modifying the system to support requesting multiple resources (currently, each host will only be assigned at most one resource)
- modifying the system to support subscribing to multiple ConfigMaps, each with its own set of resources

## Testing
The tests contained in client/tests/distributor_tests.go test the core functionality of this app including tests of concurrent behaviour.

To run the app locally, you can run `make distributor_run`, which will also apply and use the ConfigMap defined at templates/configmap.yaml. Thus, you can edit the ConfigMap manually, modifying the distributor_capacity and distributor_assignment keys, to test the behaviour of a single run of the app.

If you wish to observe it operating in its entirety, you can apply the accompanying Chart (`make distributor_apply`). As above, you can modify the Configmap at templates/configmap.yaml. Additionally, you can adjust concurrency by changing the number of replicas by modifying the Deployment at templates/deployment.yaml.

The above approaches are mutually isolated from each others' side effects as they run in different namespaces (the tests run in an ephemeral namespace, the local run runs in "default", and the Chart runs in the "distributor" namespace).

## Commands
```
Run distributor locally:
make distributor_run

Test distributor:
make distributor_test

Apply/update distributor:
make distributor_apply

Delete distributor:
make distributor_delete
```
