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