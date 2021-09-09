variable "name" {
  type        = string
  description = "The project's name"
}

variable "cluster_id" {
  type        = string
  description = "The id of the cluster to which the project belongs"
}

variable "resource_quota" {
  type        = map(string)
  description = "Resource quota for the namespace"
  default     = null
}

# Create the project with the specified name under the given cluster
resource "rancher2_project" "project" {
  cluster_id = var.cluster_id
  name       = var.name
  dynamic "resource_quota" {
    for_each = var.resource_quota != null ? [var.resource_quota] : []

    content {
      namespace_default_limit {
        limits_cpu    = lookup(resource_quota.value, "limits_cpu", null)
        limits_memory = lookup(resource_quota.value, "limits_memory", null)
      }

      project_limit {
        limits_cpu    = lookup(resource_quota.value, "limits_cpu", null)
        limits_memory = lookup(resource_quota.value, "limits_memory", null)
      }
    }
  }
}

# Create the namespace associated with the project
resource "rancher2_namespace" "namespace" {
  name       = lower(var.name)
  project_id = rancher2_project.project.id
  dynamic "resource_quota" {
    for_each = var.resource_quota != null ? [var.resource_quota] : []

    content {
      limit {
        limits_cpu    = lookup(resource_quota.value, "limits_cpu", null)
        limits_memory = lookup(resource_quota.value, "limits_memory", null)
      }
    }
  }
}

output "project_id" {
  value = rancher2_project.project.id
}
