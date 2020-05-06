variable "name" {
  type        = string
  description = "The project's name"
}

variable "cluster_id" {
  type        = string
  description = "The id of the cluster to which the project belongs"
}

variable "namespaces" {
  type        = set(string)
  description = "A list of namespaces to be created under this project"
  default     = []
}

# Create the project with the specified name under the given cluster
resource "rancher2_project" "project" {
  cluster_id = var.cluster_id
  name       = var.name
}

# Loop through "namespaces", creating each namespace under the project
resource "rancher2_namespace" "namespace" {
  for_each   = var.namespaces
  name       = each.value
  project_id = rancher2_project.project.id
}

output "project_id" {
  value = rancher2_project.project.id
}
