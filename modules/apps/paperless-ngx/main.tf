module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
}

module "helm" {
  source = "../../base/helm"

  release_name     = "paperless-ngx"
  namespace        = module.namespace.name
  chart            = "paperless-ngx"
  repository       = "oci://registry.homelabz.eu/helm-charts"
  chart_version    = var.chart_version
  timeout          = 600
  create_namespace = false

  values_files = [
    <<-EOT
      image:
        repository: registry.homelabz.eu/mirror-ghcr/paperless-ngx/paperless-ngx

      env:
        PAPERLESS_DBENGINE: postgresql
        PAPERLESS_DBHOST: "${var.db_host}"
        PAPERLESS_DBPORT: "5432"
        PAPERLESS_DBNAME: "${var.db_name}"
        PAPERLESS_DBUSER: "${var.db_user}"
        PAPERLESS_TIME_ZONE: "${var.time_zone}"
        PAPERLESS_OCR_LANGUAGE: "eng"
        PAPERLESS_TASK_WORKERS: "${var.task_workers}"
        PAPERLESS_CONSUMER_RECURSIVE: "true"
        PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS: "true"
        PAPERLESS_URL: "https://${var.ingress_host}"
        PAPERLESS_ADMIN_USER: "${var.admin_user}"
%{if var.secret_key != ""~}
        PAPERLESS_SECRET_KEY: "${var.secret_key}"
%{endif~}

      redis:
        enabled: false

      postgresql:
        enabled: false

      persistence:
        data:
          enabled: true
          retain: true
          storageClass: ${var.storage_class}
          accessMode: ReadWriteOnce
          size: 10Gi
        media:
          enabled: true
          retain: true
          storageClass: ${var.storage_class}
          accessMode: ReadWriteOnce
          size: ${var.media_storage_size}
        consume:
          enabled: true
          retain: true
          storageClass: ${var.storage_class}
          accessMode: ReadWriteOnce
          size: ${var.consume_storage_size}
        export:
          enabled: true
          retain: true
          storageClass: ${var.storage_class}
          accessMode: ReadWriteOnce
          size: 10Gi

      resources:
        requests:
          cpu: 500m
          memory: 512Mi
        limits:
          cpu: 2000m
          memory: 2Gi

%{if var.ingress_enabled~}
      ingress:
        main:
          enabled: true
          annotations:
            external-dns.alpha.kubernetes.io/hostname: ${var.ingress_host}
            cert-manager.io/cluster-issuer: letsencrypt-prod
          ingressClassName: ${var.ingress_class_name}
          hosts:
            - host: ${var.ingress_host}
              paths:
                - path: /
                  pathType: Prefix
          tls:
            - secretName: ${replace(var.ingress_host, ".", "-")}-tls
              hosts:
                - ${var.ingress_host}
%{endif~}
    EOT
  ]

  set_sensitive_values = concat(
    [
      {
        name  = "env.PAPERLESS_DBPASS"
        value = var.db_pass
      },
      {
        name  = "env.PAPERLESS_REDIS"
        value = var.redis_url
      },
    ],
    var.admin_password != "" ? [
      {
        name  = "env.PAPERLESS_ADMIN_PASSWORD"
        value = var.admin_password
      },
    ] : []
  )
}
