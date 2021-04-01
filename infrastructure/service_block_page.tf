# Deploy 'block-page' app
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment
# https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
resource "kubernetes_deployment" "block-page" {
  metadata {
    name = "block-page"
    labels = {
      app = "block-page"
    }
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "block-page"
      }
    }
    template {
      metadata {
        labels = {
          app = "block-page"
        }
      }
      spec {
        container {
          image = "gcr.io/${local.gcp_project}/block-page:latest"
          name  = "block-page"
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}

# Expose 'block-page' app as a service
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service
# https://kubernetes.io/docs/concepts/services-networking/service/
resource "kubernetes_service" "block-page" {
  metadata {
    name = "block-page"
  }
  spec {
    selector = {
      app = kubernetes_deployment.block-page.metadata.0.labels.app
    }
    session_affinity = "ClientIP"
    port {
      port = 80
    }
    type = "ClusterIP"
  }
}
# Setup our subdomain with Ambassador and request an SSL certificate from Lets Encrypt
# https://www.getambassador.io/docs/latest/topics/running/host-crd/
resource "kubernetes_manifest" "block-page-host" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "Host" # This is a Host object
    "metadata" = {
      "name"      = "block-page-host" # Name of our Host object
      "namespace" = "ambassador" # Kubernetes Namespace for our Host object
    }
    "spec" = { # Specification for our Host object
      "hostname" = local.block_page_dns # Reference our Block Page DNS from our variables.tf file
      "acmeProvider" = {             # This enables SSL by using an ACME provider to generate a certificate automatically; Lets Encrypt is used by default
        "email" = local.acme_contact # Administrative contact email for the generated SSL certificate
      }
    }
  }
}
# Create a Layer 7 route that maps our subdomain to the 'block-page' Kubernetes Service
# https://www.getambassador.io/docs/latest/topics/using/intro-mappings/
resource "kubernetes_manifest" "block-page-mapping" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "Mapping" # This is a Mapping object
    "metadata" = {
      "name"      = "block-page-backend" # Name of our Mapping object
      "namespace" = "ambassador" # Kubernetes Namespace for our Mapping object
    }
    "spec" = {
      "host"    = local.block_page_dns # The hostname to map; sourced from our variables.tf file
      "prefix"  = "/" # The URL path to map; in this case the root URL
      "service" = "block-page.default" # The name of the Kubernetes Service we are mapping the hostname to
    }
  }
}