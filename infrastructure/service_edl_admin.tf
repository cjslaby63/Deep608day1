# Deploy 'edl-admin' app
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment
# https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
resource "kubernetes_deployment" "edl-admin" {
  metadata {
    name = "edl-admin"
    labels = {
      app = "edl-admin"
    }
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "edl-admin"
      }
    }
    template {
      metadata {
        labels = {
          app = "edl-admin"
        }
      }
      spec {
        container {
          image = "gcr.io/${local.gcp_project}/edl-admin:latest"
          name  = "edl-admin"
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

# Expose 'edl-admin' app as a service
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service
# https://kubernetes.io/docs/concepts/services-networking/service/
resource "kubernetes_service" "edl-admin" {
  metadata {
    name = "edl-admin"
  }
  spec {
    selector = {
      app = kubernetes_deployment.edl-admin.metadata.0.labels.app
    }
    session_affinity = "ClientIP"
    port {
      port = 80
    }
    type = "ClusterIP"
  }
}