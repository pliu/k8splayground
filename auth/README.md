# Authentication and Authorization
Authentication and authorization are crucial components in most production systems. Authentication allows the system to identify clients and authorization permits them, based on their identity or the groups they belong to, to perform certain actions. This module documents and provides examples of Kubernetes' authentication and authorization system as well as that of Rancher, a cluster manager that can manage authentication and authorization across multiple clusters.

Examples of things to experiment with:

- "creating" Kubernetes users and groups
- creating new Rancher users
- creating namespaced and cluster-wide custom roles through Kubernetes or Rancher
- granting namedspaced and cluster-wide permissions to users and groups via role bindings through Kubernetes or Rancher

## Kubernetes' authentication and authorization model
Kubernetes has two primary ways to identify clients: "users" and service accounts ("users" are used by external clients whereas service accounts are used by services internal to Kubernetes). Users are not explicitly represented as a Kubernetes objects but are instead implicitly derived from the Common Name field in the subject of the Kubernetes-signed certificate a client uses to authenticate with the cluster. Group membership is similarly implicit and found in the Organization fields.

Role-based access control (RBAC) is the most popular authorization model used by Kubernetes. In this model, permissions (i.e. which actions are allowed on which resources) are captured as roles (Roles are namespace-specific permissions whereas ClusterRoles are cluster-wide). RoleBindings and ClusterRoleBindings are then used to bind roles to entities (e.g. "users", "groups", and service accounts) with RoleBindings binding roles to entities in specific namespaces whereas ClusterRoleBindings bind the roles to entities across the entire cluster.

## Rancher
Rancher is a Kubernetes cluster manager. It can be used to launch new Kubernetes clusters, manage existing ones (explore Kubernetes in a manner similar to kubectl but graphically), deploy and manage applications via Helm charts, monitor, alert, and aggregate logs across clusters, and provides user and group management and authorization capabilities. We will use Rancher primarily for its user management and authorization capabilities as group management requires external identity providers, we use Helm directly to deploy and manage applications, and we use Prometheus Operator for monitoring and alerting.

We run Rancher in a Docker container alongside the kind "hosts". When creating the Rancher container, we port-forward localhost:444 on the local machine to port 443 on the Rancher container (specified in the Makefile), allowing us to access the Rancher UI.

In this README, the instructions for working with Rancher use its UI. Unfortunately, this is manual which is why there are no Makefile targets. For more information of managing Rancher using Terraform, documentation can be found [here](terraform/README.md)

To import the kind cluster into Rancher:

1. Start the Rancher server. Note down its Docker network IP. If you forgot to do this, you can find it later by running
```
docker inspect <container name> -f '{{ json .NetworkSettings.Networks.bridge.IPAddress }}'
```
2. Go to its UI (https://localhost:444) and set an admin password
3. Set the Rancher Server URL to be the Rancher Docker network IP from step 1 (the Rancher container sits in the same network as the kind "hosts" and this is its IP within that network, thus allowing the kind "hosts" to connect to it)
4. Add Cluster -> Import an existing cluster -> give the cluster a name -> Create
5. Run the 'curl --insecure' command to add the cluster

## Rancher's authentication and authorization model
Rancher builds on top of the Kubernetes model and has the following main abstractions:

- cluster: the clusters managed by Rancher
- user/group: Rancher users and the groups they belong to
- role: a set of permissions (i.e. which actions are allowed on which resources)
- project: a collection of namespaces within a Cluster

Only users managed by external user-management systems (e.g. OpenLDAP) can be associated with groups.

There are three categories of roles: global, cluster, and project. Global roles are generally for Rancher-specific permissions (e.g., logging into Rancher, managing users, roles, and clusters), although the admin role also grants all Kubernetes permissions across all clusters. Cluster and project roles grant Kubernetes permissions (like those described in Kubernetes' authentication and authorization model) in addition to Rancher-specific permissions related to managing clusters and projects (e.g., managing projects within a cluster, managing cluster/project membership), respectively.

Projects are a novel abstraction that extends the base Kubernetes model. It encapsulates a set of namespaces such that a user/group granted project-level Kubernetes permissions is granted those permissions across all of that project's namespaces. Similarly, a user/group granted cluster-level Kubernetes permissions is granted those permissions across all of the cluster's namespaces.

## Tying the Kubernetes and Rancher models together
The Rancher user is essentially a composition of Kubernetes users across various clusters and Rancher-specific permissions. When connecting to a Kubernets cluster through Rancher, Rancher proxies it to the desired Kubernetes cluster, mapping the Rancher user to its Kubernetes user/groups for that cluster by setting impersonation headers. You can test this by downloading a Rancher user's cluster-specific kubeconfig (described in Creating and testing a user through Rancher) and modifying it to access the Kubernetes cluster directly - it will fail. In fact, if you look at the user in the downloaded kubeconfig, it is the Rancher username and not its Kubernetes username. However, this means that if we create a kubeconfig for the Kubernetes username of a Rancher user in the given cluster (described in Creating and testing a user through Kubernetes), we could then access the Kubernetes cluster directly with the same permissions we assigned through Rancher.

The Kubernetes permissions portion of Rancher roles is implemented as Kubernetes ClusterRoles. Cluster roles are bound using ClusterRoleBindings while project roles are bound using RoleBindings in a project's namespaces.

## Creating and testing a user through Kubernetes
To help test user creation and permissioning through Kubernetes, there are two Makefile targets: one to create new users (and specify the groups to which they belong) and one to permit users/groups read-only permissions within specific namespaces (see Commands below). When a new user is created, its kubeconfig file is placed in auth/config. These configs are used by auth/scripts/user_kubectl.sh (see Commands below) to access Kubernetes as any of the created users.

When a new user is created, if it or any of the groups it belongs to have not been granted the necessary permissions, you will notice that kubectl commands executed as the user will fail.
```
$ auth/scripts/user_kubectl.sh test get pods
Error from server (Forbidden): pods is forbidden: User "test" cannot list resource "pods" in API group "" in the namespace "default"
```
Granting the relevant permissions to the user or a group it belongs to resolves this.
```
$ NAMESPACE=default USERS=test make permissions_apply
auth/scripts/read_only_permissions.sh default test User
rolebinding.rbac.authorization.k8s.io/default-User-test-ro created
$ auth/scripts/user_kubectl.sh test get pods
NAME                                                      READY   STATUS    RESTARTS   AGE
...
```
It is recommended to examine auth/scripts/create_user.sh and auth/scripts/read_only_permissions.sh, called by make create_user and make permissions_apply, respectively, to understand how client certificates and kubeconfigs are generated and to see an example of RoleBinding. In the case of role binding, instead of creating and binding a custom role, we bind the "view" role that comes with Kubernetes.

who-can is an extremely useful kubectl plugin for exploring which users, groups, and service accounts have permitted to execute any given command. It also shows the RoleBindings/ClusterRoleBindings responsible for binding the permission to these entities.

## Creating and testing a user through Rancher
Use the following flows to test creation of new users, granting them permissions, and accessing Kubernetes through Rancher (similar to setting up Rancher, many of these steps must be done through Rancher's UI and thus do not have Makefile targets like those in the previous section).

Each of the following flows starts from the "Global" view (https://localhost:444/g/clusters).
```
Add/delete users:
Security -> Users -> Add User
                 |-> select users to delete -> Delete

Add/delete roles:
Security -> Roles -> Clusters/Projects -> Create Cluster/Project Role
                                      |-> select roles to delete -> Delete

Add/remove a user to/from a project (removal of a user from a project does not delete the user):
Global -> <cluster name> -> <project name> -> Members -> Add Member
                                          |-> select members to delete -> Delete

Add/remove a user to/from a cluster (removal of a user from a cluster does not delete the user nor remove it from projects in the cluster):
Global -> <cluster name> -> Members -> Add Member
                                   |-> select members to delete -> Delete

Access Kubernetes through Rancher as a user:
1. Login as the desired user
2. Global -> <cluster name> -> Launch kubectl

Obtain a user's kubeconfig for local use:
1. Login as the desired user
2. Global -> <cluster name> -> Kubeconfig File
```

## Commands
```
Start Rancher server:
make rancher_start

Stop Rancher server:
make rancher_stop

Create user through Kubernetes:
USER=<username> [GROUPS=<comma-separated list of groups>; optional] make user_create

Clear users:
make users_clear

Apply read-only permissions for users/groups in a given namespace:
NAMESPACE=<namespace> [USERS=<comma-separated list of users> GROUPS=<comma-separated list of groups>; one is required] make permissions_apply

Delete all K8sPlayground-applied permissions:
make permissions_delete

Access Kubernetes directly as a user:
auth/scripts/user_kubectl.sh <username> <kubectl command>

Query which users, groups, and service accounts are permitted to execute a given command:
kubectl who-can <kubectl command>
```

## Rancher internals
Under the hood, Rancher stores its settings as objects in its own dedicated Kubernetes (the Rancher Docker container runs the stripped-down k3s Kubernetes distribution). You can browse these resources by exec-ing into the Rancher container (`docker exec -it <container name [`docker ps` to find it]> /bin/bash`) and using kubectl. The mapping of Rancher settings to resources is not intuitive and will require some exploration. As a starting point:

- there are Cluster, Project, User, GlobalRole, ClusterRole, Role, GlobalRoleBinding, ClusterRoleBinding, and RoleBinding resources
- there are namespaces for each cluster and project
- some associations make sense (e.g. namespaces associated with clusters contain Project resources) while others are a bit harder to understand (e.g. when are RoleBindings, ClusterRoleBindings, or GlobalRoleBindings used)

Additionally, as Rancher manages Kubernetes clusters through the creation and deletion of various Kubernetes resources (e.g., ClusterRoles, ClusterRoleBindings, RoleBindings), it is important to understand how, if at all, it stays synchronized with the underlying clusters' states, which could shift beneath it.

Examples of Rancher-related things to experiment with:

- explore Rancher's internal state representation
- determine Rancher's reconciliation behaviour (i.e. when and how does it query the cluster's state and reconcile against the Rancher-defined desired state)
- play around with Rancher's other capabilities (e.g., application deployment and management, monitoring and alerting)
