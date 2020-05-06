terraform {
  backend "pg" {
    conn_str = "postgres://postgres:password@localhost/terraform_backend?sslmode=disable"
  }
}

# Provider to connect to new Rancher instance
# The api_url uses Rancher's Docker IP as this is the address that the Kubernetes cluster will attempt to connect to
provider "rancher2" {
  alias     = "bootstrap"
  api_url   = format("https://%s:443/v3", trim(var.rancher_docker_ip, "\""))
  bootstrap = true
  insecure  = true
}

# Bootstrap resources that sets admin's password and gets API token
resource "rancher2_bootstrap" "admin" {
  provider = rancher2.bootstrap
  password = "password"
}

variable "rancher_docker_ip" {
  type        = string
  description = "Rancher container's Docker IP"
}

output "admin_token" {
  value = rancher2_bootstrap.admin.token
}
