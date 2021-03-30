# Deploy Redis Instance
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance
resource "google_redis_instance" "redis" {
  name           = local.redis_name
  memory_size_gb = 1
  region         = local.gcp_region
  location_id    = local.gcp_zone
}