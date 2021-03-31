# Deploy 'request-unblock' app
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment
# https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
resource "kubernetes_deployment" "request-unblock" {
  metadata {
    name = "request-unblock"
    labels = {
      app = "request-unblock"
    }
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "request-unblock"
      }
    }
    template {
      metadata {
        labels = {
          app = "request-unblock"
        }
      }
      spec {
        container {
          image = "gcr.io/${local.gcp_project}/request-unblock:latest"
          name  = "request-unblock"
          env {
            name = "REDIS_HOST"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.redis.metadata.0.name
                key  = "redis_host"
              }
            }
          }
          env {
            name = "REDIS_PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.redis.metadata.0.name
                key  = "redis_port"
              }
            }
          }
          liveness_probe {
            http_get {
              path = "/health"
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

# Expose 'request-unblock' app as a service
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service
# https://kubernetes.io/docs/concepts/services-networking/service/
resource "kubernetes_service" "request-unblock" {
  metadata {
    name = "request-unblock"
  }
  spec {
    selector = {
      app = kubernetes_deployment.request-unblock.metadata.0.labels.app
    }
    session_affinity = "ClientIP"
    port {
      port = 80
    }
    type = "ClusterIP"
  }
}