# Enable the GCP Terraform Provider
# This will be used to deploy our Kubernetes cluster and other related cloud resources
# https://registry.terraform.io/providers/hashicorp/google/latest/docs
provider "google" {
  project     = local.gcp_project
  region      = local.gcp_region
  zone        = local.gcp_zone
}

# The GCP Beta Provider is being used for GKE's 'VPC_NATIVE' mode
# (necessary to integrate with Redis)
# https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs
provider "google-beta" {
  project     = local.gcp_project
  region      = local.gcp_region
  zone        = local.gcp_zone
}