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
# Setup our subdomain with Ambassador and request an SSL certificate from Lets Encrypt
# https://www.getambassador.io/docs/latest/topics/running/host-crd/
resource "kubernetes_manifest" "edl-admin-host" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "Host"
    "metadata" = {
      "name"      = "edl-admin-host"
      "namespace" = "ambassador"
    }
    "spec" = {
      "hostname" = local.edl_admin_dns
      "acmeProvider" = {
        "email" = local.acme_contact
      }
    }
  }
}

# Create a Layer 7 route that maps our subdomain to the 'edl-admin' Kubernetes Service
# https://www.getambassador.io/docs/latest/topics/using/intro-mappings/
resource "kubernetes_manifest" "edl-admin-mapping" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "Mapping"
    "metadata" = {
      "name"      = "edl-admin-backend"
      "namespace" = "ambassador"
    }
    "spec" = {
      "host"       = local.edl_admin_dns
      "prefix"     = "/"
      "service"    = "edl-admin.default" # <Service Name>.<Namespace>
      "timeout_ms" = 30000
    }
  }
}
# Setup an Ambassador Filter that requires authentication via Okta
# https://www.getambassador.io/docs/latest/topics/using/filters/
# https://www.getambassador.io/docs/latest/howtos/sso/okta/
resource "kubernetes_manifest" "edl-admin-filter" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "Filter" # This is a Filter object
    "metadata" = {
      "name"      = "edl-admin-filter" # Name of our Filter object
      "namespace" = "ambassador" # Kubernetes Namespace for our Filter object
    }
    "spec" = { # Specification for our Filter object
      "OAuth2" = { # We will be using the OAuth2 standard to integrate with Okta
        "authorizationURL" = local.okta_auth_url # This is the Okta authentication URL, defined in our variables.tf
        "audience"         = "api://default" # Required boilerplate
        "clientID"         = var.okta_admin_app_client_id # The Okta Client ID
        "secret"           = var.okta_admin_app_client_secret # The Okta Client Secret
        "injectRequestHeaders" = [{ # We are adding the 'X-USERNAME' header so that our micro-service knows the username of the authenticated user!
          "name"  = "X-USERNAME"
          "value" = "{{ .token.Claims.sub }}"
        }]
        "protectedOrigins" = [{
          "origin" = "https://${local.edl_admin_dns}"
        }]
      }
    }
  }
}

# Map our Okta Filter to the 'edl-admin' subdomain
# https://www.getambassador.io/docs/latest/topics/using/filters/
# https://www.getambassador.io/docs/latest/howtos/sso/okta/
resource "kubernetes_manifest" "edl-admin-filter-policy" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "getambassador.io/v2"
    "kind"       = "FilterPolicy" # This is a FilterPolicy object
    "metadata" = {
      "name"      = "edl-admin-filter-policy" # Name of our FilterPolicy object
      "namespace" = "ambassador" # Kubernetes Namespace for our FilterPolicy object
    }
    "spec" = { # Specification for our FilterPolicy object
      "rules" = [{
        "host" = local.edl_admin_dns # Map to our admin.edl.###.deep608lab.com hostname
        "path" = "*" # Any HTTP path
        "filters" = [{ # Attach our Filter object, defined above
          "name" = "edl-admin-filter"
          "arguments" = {
            "scope" = ["openid", "profile"]
          }
        }]
      }]
    }
  }
}