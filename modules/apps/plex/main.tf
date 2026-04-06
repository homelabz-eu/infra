module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
}

module "helm" {
  source = "../../base/helm"

  release_name     = "plex"
  namespace        = module.namespace.name
  chart            = "plex-media-server"
  repository       = "oci://registry.homelabz.eu/helm-charts"
  chart_version    = var.chart_version
  timeout          = 600
  create_namespace = false

  values_files = [
    <<-EOT
      image:
        registry: registry.homelabz.eu
        repository: mirror-dockerhub/plexinc/pms-docker
        tag: "${var.image_tag}"

      hostNetwork: ${var.host_network}

      pms:
        storageClassName: ${var.storage_class}
        configStorage: ${var.config_storage_size}
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            memory: 4Gi

      extraVolumes:
        - name: media-data
          persistentVolumeClaim:
            claimName: ${var.media_pvc_name}

      extraVolumeMounts:
        - name: media-data
          mountPath: /data
          readOnly: true

%{if var.ingress_enabled~}
      ingress:
        enabled: true
        ingressClassName: ${var.ingress_class_name}
        url: "https://${var.ingress_host}"
        annotations:
          external-dns.alpha.kubernetes.io/hostname: ${var.ingress_host}
          cert-manager.io/cluster-issuer: letsencrypt-prod
        tls:
          - secretName: ${replace(var.ingress_host, ".", "-")}-tls
            hosts:
              - ${var.ingress_host}
%{endif~}
    EOT
  ]

  set_sensitive_values = var.claim_token != "" ? [
    {
      name  = "extraEnv.PLEX_CLAIM"
      value = var.claim_token
    }
  ] : []
}
