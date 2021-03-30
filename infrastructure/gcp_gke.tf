# Kubernetes Cluster
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "gke" {
  provider                 = google-beta
  name                     = local.gke_name
  location                 = local.gcp_region
  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"
  network                  = "default"
  subnetwork               = "default"
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/16"
    services_ipv4_cidr_block = "/22"
  }
}

# Kubernetes Cluster - Node Pool
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "gke_pool" {
 name       = "${local.gke_name}-pool"
 location   = local.gcp_region
 cluster    = google_container_cluster.gke.name
 node_count = 1
 node_config {
   preemptible  = true
   machine_type = local.gke_node_size
   oauth_scopes = [
     "https://www.googleapis.com/auth/cloud-platform"
   ]
 }
}