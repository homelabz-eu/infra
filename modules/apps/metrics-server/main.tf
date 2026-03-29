module "helm" {
  source = "../../base/helm"

  release_name     = "metrics-server"
  namespace        = var.namespace
  chart            = "metrics-server"
  repository       = "oci://registry.homelabz.eu/helm-charts"
  chart_version    = var.chart_version
  timeout          = 300
  create_namespace = false

  values_files = [
    <<-EOT
      image:
        repository: registry.homelabz.eu/mirror-k8s/metrics-server/metrics-server
      args:
        - --cert-dir=/tmp
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s

      resources:
        limits:
          cpu: 100m
          memory: 200Mi
        requests:
          cpu: 10m
          memory: 50Mi

      serviceMonitor:
        enabled: ${var.enable_service_monitor}
    EOT
  ]

  set_values = []
}
