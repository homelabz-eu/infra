module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

module "helm" {
  source = "../../base/helm"

  release_name     = "bazarr"
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
                repository: registry.homelabz.eu/mirror-dockerhub/linuxserver/bazarr
                tag: "${var.image_tag}"
              env:
                PUID: "${var.puid}"
                PGID: "${var.pgid}"
                TZ: "${var.timezone}"
              resources:
                requests:
                  cpu: 100m
                  memory: 128Mi
                limits:
                  memory: 512Mi

      service:
        main:
          controller: main
          ports:
            http:
              port: 6767

      persistence:
        config:
          enabled: true
          type: persistentVolumeClaim
          storageClass: ${var.storage_class}
          accessMode: ReadWriteOnce
          size: ${var.config_storage_size}
          globalMounts:
            - path: /config
        media:
          enabled: true
          type: persistentVolumeClaim
          existingClaim: ${var.media_pvc_name}
          globalMounts:
            - path: /data

%{if var.ingress_enabled~}
      ingress:
        main:
          enabled: true
          className: ${var.ingress_class_name}
          annotations:
            external-dns.alpha.kubernetes.io/hostname: ${var.ingress_host}
            cert-manager.io/cluster-issuer: letsencrypt-prod
          hosts:
            - host: ${var.ingress_host}
              paths:
                - path: /
                  pathType: Prefix
                  service:
                    identifier: main
                    port: http
          tls:
            - secretName: ${replace(var.ingress_host, ".", "-")}-tls
              hosts:
                - ${var.ingress_host}
%{endif~}
    EOT
  ]
}
