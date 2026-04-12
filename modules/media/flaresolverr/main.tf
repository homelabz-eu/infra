module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

module "helm" {
  source = "../../base/helm"

  release_name     = "flaresolverr"
  namespace        = module.namespace.name
  chart            = "app-template"
  repository       = "oci://registry.homelabz.eu/helm-charts"
  chart_version    = var.chart_version
  timeout          = 600
  create_namespace = false

  values_files = [
    <<-EOT
      controllers:
        main:
          containers:
            main:
              image:
                repository: registry.homelabz.eu/mirror-dockerhub/flaresolverr/flaresolverr
                tag: "${var.image_tag}"
              env:
                TZ: "${var.timezone}"
                LOG_LEVEL: "info"
              resources:
                requests:
                  cpu: 100m
                  memory: 256Mi
                limits:
                  memory: 1Gi

      service:
        main:
          controller: main
          ports:
            http:
              port: 8191
    EOT
  ]
}
