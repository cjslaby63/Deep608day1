# Retrieve a GCP access token (used below)
data "google_client_config" "provider" {}

# Initialize Kubernetes Terraform Provider
# This will be used to deploy our Containers
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
provider "kubernetes" {
  host  = "https://${google_container_cluster.gke.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.gke.master_auth[0].cluster_ca_certificate,
  )
}

# Initialize the Kubernetes Alpha Terraform Provider
# This is used to apply CRDs to our Kubernetes cluster (not yet supported in main Kubernetes Provider)
# https://registry.terraform.io/providers/hashicorp/kubernetes-alpha/latest/docs
provider "kubernetes-alpha" {
  version = "0.2.0"
  host    = "https://${google_container_cluster.gke.endpoint}"
  token   = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.gke.master_auth[0].cluster_ca_certificate,
  )
}

# Initialize Helm Terraform Provider
# This is used to deploy Helm Charts to our Kubernetes cluster
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs
# https://helm.sh/
provider "helm" {
  kubernetes {
    host  = "https://${google_container_cluster.gke.endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      google_container_cluster.gke.master_auth[0].cluster_ca_certificate,
    )
  }
}