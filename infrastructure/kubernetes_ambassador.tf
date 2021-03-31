# Create a Kubernetes Namespace for Ambassador
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace
# https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
resource "kubernetes_namespace" "ambassador" {
  metadata {
    name = "ambassador"
  }
}

# Deploy Ambassador via a Helm Chart
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
# https://www.getambassador.io/docs/latest/topics/concepts/architecture/
resource "helm_release" "ambassador" {
  name       = "ambassador"
  repository = "https://www.getambassador.io/"
  chart      = "ambassador"
  namespace  = kubernetes_namespace.ambassador.metadata.0.name
}