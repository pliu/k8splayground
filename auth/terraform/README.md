# Terraform
Terraform is an application that allows for declarative management of other systems (e.g., AWS, Rancher). It does this by using providers, plugins that allow it to communicate with the system it is managing and that define a set of Terraform resources that correspond to resources in the managed system (e.g. rancher2_cluster is a resource provided by the rancher2 Terraform provider that represents clusters in Rancher; for more information on Rancher, go [here](../README.md#Rancher)).

Using these Terraform resources, users can define in code (.tf files) the desired state of the managed system. Terraform queries the managed system for its state and reconciles any differences between the queried state and the desired state. For example, if you've defined cluster A using a Terraform resource but it does not exist in Rancher, then Terraform will create the cluster in Rancher. Likewise, if Terraform is currently managing cluster A through a Terraform resource in a .tf file, if the resource is deleted, Terraform will delete the cluster from Rancher. If this sounds familiar, it's probably because this is very similar to how Kubernetes manages cluster. Terraform's reconciliation is triggered by a call to `terraform apply`. Upon calling `terraform apply`, Terraform will run `terraform plan`, displaying the changes that would be made, and ask for confirmation prior to making any changes.

Terraform treats each directory as a single module - combining all .tf files within the directory to form a single, combined state. Modules can take in variables (e.g. the rancher_docker_ip variable in auth/terraform/init/main.tf) to customize behavior. Similarly, they can also output information for use by the caller (e.g. the admin_token output in auth/terraform/init/main.tf). In the case of auth/terraform/init/main.tf, both the input and output is provided by and consumed by, respectively, the CLI. However, modules can call other modules as well, providing a way to factor out repeated logic into separate, reusable modules much as one might factor out repeated logic into a function when programming (e.g. creation of the "Test" project in auth/terraform/manage/main.tf).

Terraform supports a number of backends (e.g., S3, Postgres) for storing its state - its view of the state of systems it manages and, importantly, their mapping to resources defined in the .tf files. In our case, we use Postgres which is run in a Docker container alongside the Rancher container. When bringing up the Postgres container, we port-forward localhost:5432 on the local machine to port 5432 on the Postgres container (specified in the Makefile), allowing the locally-running Terraform to connect to it (see the conn_str field of terraform backend block in the .tf files). You can explore this state by exec-ing into the Postgres container (`docker exec -it <container name [`docker ps` to find it]> /bin/bash`) and running `psql -U postgres`. Terraform's state is stored under the terraform_backend schema (all of this information is contained in the conn_str field).

To isolate different Terraform states (e.g. states representing two separate Rancher instances), even when using the same backend, Terraform uses workspaces, which serve to namespace the different states. Workspaces can be created using `terraform workspace new <workspace name>` and switched to using `terraform workspace select <workspace name>`.

In addition to this remote state, Terraform also maintains some local state. This state is localized per directory in which Terraform is run and can be found in .terraform under these directory. As this state is independent between directories, `terraform init` needs to be run in each folder in which Terraform will be run. Terraform uses this state to track which workspace is currently selected and for some other miscellaneous purposes.

Examples of things to experiment with:

- setting up Terraform's local state
- creating and deleting Rancher resources (and in some cases, by extension, Kubernetes resources) through Terraform
- observing what happens to manually-changed Rancher resources that are managed by Terraform on the next terraform apply
- creating and calling Terraform modules
- importing unmanaged Rancher resources to be managed by Terraform
- selectively applying Terraform resources
- removing Rancher resources from being managed by Terraform
- using workspaces to isolate Terraform states

## Managing Rancher through Terraform
We use Terraform to bootstraps Rancher (auth/terraform/init), setting Rancher's API endpoint and admin password and retrieving an API token for subsequent communication between Terraform and Rancher (the admin password is set to `password` should you wish to log in to Rancher's UI). The initialization Makefile target (`make rancher_tf_init`) generates provider.tf from provider.template in auth/terraform/manage, populating the provider with the API token.

Once Rancher has been bootstrapped, subsequent manipulation of Rancher through Terraform is done through auth/terraform/manage. We have a provided a Makefile target for applying the Terraform state specified auth/terraform/manage: `make rancher_tf_apply`.

In main.tf, we have already defined a cluster resource and the default projects that Rancher creates along with every cluster. As Terraform's view of Rancher's state is that it is empty, if you try to apply this state from a clean initialization, it will create a Rancher cluster but fail when it tries to create the default projects specified in main.tf in a non-active cluster (a Rancher cluster is itself just a representation and must enroll an actual Kubernetes cluster to become active).

One option is to enroll the kind cluster into the Terraform-created Rancher cluster after the initial failure.

Another option is to, before running `make rancher_tf_apply`, manually create the cluster using the Rancher UI, enroll the kind cluster (as detailed [here](../README.md#Rancher)), and import it into Terraform's state so it can be mapped to the Terraform cluster resource. As `make rancher_tf_apply` normally initializes Terraform in auth/terraform/manage, this approach requires manual initialization, which can be done by running the following commands in auth/terraform/manage:
```
terraform init                  # Initializes terraform with the 'default' workspace'
terraform workspace new manage  # Creates a new 'manage' workspace
terraform init                  # Re-initializes terraform using the new 'manage' workspace
```
Once terraform has been initialized in this folder, you can run Terraform commands directly from this folder. To import the Rancher cluster state and map it to the defined cluster resource, run `terraform import rancher2_cluster.test <id of the Rancher cluster; takes the form c-xxxxx>`.

Once the Rancher cluster has been mapped to the Terraform cluster resource through either of the above approaches, we need to import the default projects that Rancher created into the Terraform state. If we do not, Terraform will create two new projects and any modifications to these projects in the .tf files will affect the Terraform-created projects and not the Rancher-created default projects. To do this, run `terraform state show rancher2_cluster.test` (`terraform state list` lists showable resources) to view the state of the rancher2_cluster.test resource, within which the fields default_project_id and system_project_id contain the IDs for the default Default and System projects, respectively. To import these into Terraform's state, run `terraform import rancher2_project.<default/system> <project id>`.

A third option is to use resource targeting. As in the second option, rather than call `make rancher_tf_apply` initially, we manually initialize the workspace as above. Then, instead of creating the cluster using the Rancher UI, we selectively apply the cluster resource using `terraform apply -target rancher2_cluster.test`, creating the Rancher cluster through Terraform without all of the failures associated with trying to create all of the other resources that are dependent on the cluster resource being ready. From here, enroll the kind cluster into the Terraform-created Rancher cluster (as in the first option) and import the default projects into the Terraform state as above.

Once this initial setup is complete, subsequent calls to `make rancher_tf_apply` should correctly synchronize Rancher with the desired state specified in the .tf files. By default, the Terraform-specified state creates another project with two namespaces, a user, and grants project-level permissions to the user. (Data blocks import state for Terraform to use but are read-only unlike the imports we used above, which imported the state into as a Terraform resource. In this case, the import is done via matching the roles' names.)

## Testing
As there are multiple levels of control (i.e. Terraform controls Rancher which controls the actual Kubernetes cluster), it is recommended that you play around at all levels to get a sense of how configurations in the .tf files cascade down through the other levels.

After making modifications to the desired state and applying the changes, the changes should be reflected in Rancher's UI. If the changes affect Kubernetes (e.g., permissions), you can use kubectl to examine Kubernetes' state to ensure that these are implemented. Specifically, for permissions-related changes, you can test specific users' permissions by logging in as the desired user as detailed [here](../README.md#Creating&#32and&#32testing&#32a&#32user&#32through&#32Rancher).

## Commands
```
Initialize Postgres and Rancher in a clean state:
make rancher_tf_init

Apply the state specified in .tf files in auth/terraform/manage:
make rancher_tf_apply

Destroy Postgres and Rancher:
make rancher_tf_destroy
```
