# Argo CD
Argo CD is a declarative continuous deployment system built for Kubernetes. It uses a similar model to Kubernetes for deploying applications: a reconciliation loop that checks the observed state against the desired state and takes action to move the former closer to the latter (if one wishes to manually trigger syncing, automatic reconciliation can be turned off). A single instance of Argo CD can manage applications across numerous clusters and namespaces.

Argo CD provides two primary abstractions: Projects (AppProject type) and Applications (Application type).

Projects contain Applications, all of which share the Project's configurations. These configurations include things like a whitelist of Git repositories from which application charts can be downloaded, whitelists of cluster-level and namespace-level resources that Applications are allowed to deploy, and a whitelist of the clusters and namespaces Applications are allowed to deploy to.

Under the hood, Argo CD uses Helm (Argo CD supports both Helm 2 and Helm 3, but K8sPlayground uses Helm 3) to deploy applications. It uses the apiVersion of a chart's Chart.yaml to determine which version of Helm to use (v1 signals for Argo CD to use Helm 2 while v2 signals it to use Helm 3).

Applications are essentially wrappers around Helm charts that provide extra information such as where the chart should be retrieved from (e.g. which Git repository, which revision, and at what path), which cluster and namespace should it be deployed in, and whether Argo CD should automatically sync it. It is the rendered chart that is specified by an Application that serves as the desired state that Argo CD attempts to converge to.

By default, Argo CD polls the Git repositories specified by the Applications it manages every 3 minutes for changes, refreshing the respective applications if any changes are detected. Argo CD can also be configured to receive webhook requests from these repositories to notify it of changes (K8sPlayground does not have this feature enabled as it requires a stable URL to which to send the webhook requests).

Examples of things to experiment with:

- adding new users to Argo CD
- granting users project/Application-specific permissions via role bindings
- creating new projects and limiting the Git repos they can use, the cluster-level or namespace-level resources their applications can use, and the namespaces their applications can be deployed to
- creating new Applications
- updating underlying applications
- changing/deleting Argo CD-managed resources
- Argo CD recovery when it is deleted while still managing resources

## Argo apps
As the argo-cd chart contains the CustomResourceDefinitions for AppProject and Application, including the instantiations of AppProjects and Applications in the same chart leads to Helm attempting to deploy the AppProject and Application objects before their definitions, resulting in failure. For this reason, the instantiation of AppProjects and Applications has been broken off into the argo-apps chart which can be applied after the argo-cd chart has been applied.

In K8sPlayground, there are two Projects - apps and systems - with all managed applications being split between them. The creation of AppProject and Application objects has been templated out and their configurations, including which applications belong to which Project, can be found in apps/argo-apps/values.yaml.

## Authentication and authorization
Similar to Kubernetes, Argo CD uses RBAC to grant permissions to users and groups (roles with sets of permissions are defined and then mapped to users and groups; Argo CD also allows direct mapping of permissions to users and groups).

Similar to Rancher, only users managed by external user-management systems (e.g. OIDC) are associated with groups.

In K8sPlayground, user and role management are in the argo-cd chart in the argocd-cm and argocd-rbac-cm ConfigMaps and the argocd-secret Secret. One can also define and bind Project-scoped roles in AppProject manifests.

## Application deployment
Helm is used to bootstrap the argo-cd and argo-apps charts. The Makefile targets deploy argo-cd and argo-apps to the `argo-cd` namespace. You can apply argo-apps after argo-cd; however, it may take a couple of minutes for the Argo CD Pods to come up, thus delaying the start-up of the applications specified in argo-apps (sometimes, applications may get stuck deploying, in which case delete the associated Application and re-apply it).

In an effort to make Argo CD deployment mirror Helm-based application, the Applications in argo-apps are configured to deploy applications with the same release names and to the same namespaces as the Helm-based approach.

Additionally, the Makefile target to delete Argo CD is written such that it should leave the applications it managed intact (as argo-cd contains the AppProject and Application CRDs. However, AppProjects and Application objects from argo-apps will also be deleted). To delete an application that is managed by Argo CD, just delete its associated Application object while Argo CD is running.

There is an important difference between deploying applications through Argo CD compared to using Helm. Although applying argo-cd via Helm behaves the way one might expect (i.e. changes made to its chart are reflected after the next application), deploying applications through argo-apps behaves a little differently. When applying argo-apps through Helm, changes made to Projects or Application configuration will be reflected after the application but changes in the underlying application itself will not. This is because when Argo CD deploys an application, it deploys the chart from the specified Git repository at the specified revision. Thus, for Argo CD to pick up changes in underlying applications, changes to their charts must first be pushed to the Git repository.

## Testing
Among the applications configured to be deployed by Argo CD in K8sPlayground is nginx-ingress. If nginx-ingress is running, configuration changes can be verified from the Argo CD UI (https://localhost/argo-cd) on one's local machine (`admin`'s username/password is admin/password while `user`'s is user/password). admin has all permissions across all Projects while user has all permissions in the apps Project (except being able to manually create Applications since we want Applications to be defined in argo-apps) and view other Projects.

## Commands
```
Apply/update Argo CD:
make argo_apply

Apply/update Argo CD-managed applications:
make apps_apply

Delete Argo CD:
make argo_delete
```
