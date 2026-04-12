resource "helm_release" "cloudnative_pg" {
  name       = "cnpg"
  repository = "oci://registry.homelabz.eu/helm-charts"
  chart      = "cloudnative-pg"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = var.create_namespace

  values = [
    yamlencode({
      image = {
        repository = "registry.homelabz.eu/mirror-ghcr/cloudnative-pg/cloudnative-pg"
      }
      crds = {
        create = true
      }
    })
  ]
}
