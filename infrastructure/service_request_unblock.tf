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
# Setup our subdomain with Ambassador and request an SSL certificate from Lets Encrypt
# https://www.getambassador.io/docs/latest/topics/running/host-crd/
resource "kubernetes_manifest" "request-unblock-host" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "Host"
    "metadata" = {
      "name"      = "request-unblock-host"
      "namespace" = "ambassador"
    }
    "spec" = {
      "hostname" = local.request_unblock_dns
      "acmeProvider" = {
        "email" = local.acme_contact
      }
    }
  }
}

# Create a Layer 7 route that maps our subdomain to the 'request-unblock' Kubernetes Service
# https://www.getambassador.io/docs/latest/topics/using/intro-mappings/
resource "kubernetes_manifest" "request-unblock-mapping" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "Mapping"
    "metadata" = {
      "name"      = "request-unblock-backend"
      "namespace" = "ambassador"
    }
    "spec" = {
      "host"       = local.request_unblock_dns
      "prefix"     = "/"
      "service"    = "request-unblock.default" # <Service Name>.<Namespace>
      "timeout_ms" = 30000
    }
  }
}

# Setup an Ambassador Filter that requires authentication via Okta
# https://www.getambassador.io/docs/latest/topics/using/filters/
# https://www.getambassador.io/docs/latest/howtos/sso/okta/
resource "kubernetes_manifest" "request-unblock-filter" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "Filter"
    "metadata" = {
      "name"      = "request-unblock-filter"
      "namespace" = "ambassador"
    }
    "spec" = {
      "OAuth2" = {
        "authorizationURL" = local.okta_auth_url
        "audience"         = "api://default"
        "clientID"         = var.okta_user_app_client_id
        "secret"           = var.okta_user_app_client_secret
        "injectRequestHeaders" = [{
          "name"  = "X-USERNAME"
          "value" = "{{ .token.Claims.sub }}"
        }]
        "protectedOrigins" = [{
          "origin" = "https://${local.request_unblock_dns}"
        }]
      }
    }
  }
}

# Map our Okta Filter to the 'request-unblock' subdomain
# https://www.getambassador.io/docs/latest/topics/using/filters/
# https://www.getambassador.io/docs/latest/howtos/sso/okta/
resource "kubernetes_manifest" "request-unblock-filter-policy" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "FilterPolicy"
    "metadata" = {
      "name"      = "request-unblock-filter-policy"
      "namespace" = "ambassador"
    }
    "spec" = {
      "rules" = [{
        "host" = local.request_unblock_dns
        "path" = "*"
        "filters" = [{
          "name" = "request-unblock-filter"
          "arguments" = {
            "scope" = ["openid", "profile"]
          }
        }]
      }]
    }
  }
}