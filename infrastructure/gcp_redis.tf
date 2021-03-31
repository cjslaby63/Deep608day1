# Deploy Redis Instance
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance
resource "google_redis_instance" "redis" {
  name           = local.redis_name
  memory_size_gb = 1
  region         = local.gcp_region
  location_id    = local.gcp_zone
}
# Store Redis Host & Port in a Kubernetes ConfigMap
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map
# https://kubernetes.io/docs/concepts/configuration/configmap/
resource "kubernetes_config_map" "redis" {
  metadata {
    name = "redis-env"
  }
  data = {
    redis_host = google_redis_instance.redis.host
    redis_port = google_redis_instance.redis.port
  }
}