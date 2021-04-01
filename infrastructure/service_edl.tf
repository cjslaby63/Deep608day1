# Deploy 'edl' app
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment
# https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
resource "kubernetes_deployment" "edl" {
  metadata {
    name = "edl"
    labels = {
      app = "edl"
    }
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "edl"
      }
    }
    template {
      metadata {
        labels = {
          app = "edl"
        }
      }
      spec {
        container {
          image = "gcr.io/${local.gcp_project}/edl:latest"
          name  = "edl"
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

# Expose 'edl' app as a service
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service
# https://kubernetes.io/docs/concepts/services-networking/service/
resource "kubernetes_service" "edl" {
  metadata {
    name = "edl"
  }
  spec {
    selector = {
      app = kubernetes_deployment.edl.metadata.0.labels.app
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
resource "kubernetes_manifest" "edl-host" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "Host"
    "metadata" = {
      "name"      = "edl-host"
      "namespace" = "ambassador"
    }
    "spec" = {
      "hostname" = local.edl_dns
      "acmeProvider" = {
        "email" = local.acme_contact
      }
    }
  }
}

# Create a Layer 7 route that maps our subdomain to the 'edl' Kubernetes Service
# https://www.getambassador.io/docs/latest/topics/using/intro-mappings/
resource "kubernetes_manifest" "edl-mapping" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "Mapping"
    "metadata" = {
      "name"      = "edl-backend"
      "namespace" = "ambassador"
    }
    "spec" = {
      "host"       = local.edl_dns
      "prefix"     = "/"
      "service"    = "edl.default" # <Service Name>.<Namespace>
      "timeout_ms" = 30000
    }
  }
}