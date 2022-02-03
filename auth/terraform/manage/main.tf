# Load default Rancher Pod Security Policy named "restricted"
data "rancher2_pod_security_policy_template" "rancher-restricted" {
  name = "restricted"
}

# Create or import cluster
resource "rancher2_cluster" "test" {
  name                                    = "test"
  description                             = "This test cluster that was either created manually and imported or created by Terraform"
  default_pod_security_policy_template_id = data.rancher2_pod_security_policy_template.rancher-restricted.id
}

# Import System project
resource "rancher2_project" "system" {
  cluster_id = rancher2_cluster.test.id
  name       = "System"
}

# Import Default project
resource "rancher2_project" "default" {
  cluster_id = rancher2_cluster.test.id
  name       = "Default"
}

# Create "Test" project containing a namespace of the same name (lowercased)
module "test_project" {
  source     = "./project2"
  name       = "Test"
  cluster_id = rancher2_cluster.test.id
  resource_quota = {
    limits_cpu = "3"
  }
}

module "test_project2" {
  source     = "./project2"
  name       = "Test2"
  cluster_id = rancher2_cluster.test.id
}

# Create "test" user
resource "rancher2_user" "test" {
  username = "test"
  password = "password"
}

# Grant "test" user "user-base" global role
resource "rancher2_global_role_binding" "test-global" {
  global_role_id = "user-base"
  user_id        = rancher2_user.test.id
}

# Load default Kubernetes Cluster Role named "edit"
data "rancher2_role_template" "edit" {
  name = "Kubernetes edit"
}

# Load default Kubernetes Cluster Role named "view"
data "rancher2_role_template" "view" {
  name = "Kubernetes view"
}

# Grant "test" user "view" role in "default" project
resource "rancher2_project_role_template_binding" "test-default-view" {
  name             = "test-default-view"
  project_id       = rancher2_project.default.id
  role_template_id = data.rancher2_role_template.view.id
  user_id          = rancher2_user.test.id
}

# Grant "test" user "edit" role in "test" project
resource "rancher2_project_role_template_binding" "test-test-edit" {
  name             = "test-test-edit"
  project_id       = module.test_project.project_id
  role_template_id = data.rancher2_role_template.edit.id
  user_id          = rancher2_user.test.id
}
