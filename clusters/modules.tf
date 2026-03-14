module "local_path_provisioner" {
  count  = contains(local.workload, "local-path-provisioner") ? 1 : 0
  source = "../modules/apps/local-path-provisioner"

  namespace                 = "local-path-storage"
  storage_class_name        = "local-path"
  set_default_storage_class = true
}

module "metrics_server" {
  count  = contains(local.workload, "metrics-server") ? 1 : 0
  source = "../modules/apps/metrics-server"

  namespace              = "kube-system"
  enable_service_monitor = contains(local.workload, "observability-box")
}

module "metallb" {
  count  = contains(local.workload, "metallb") ? 1 : 0
  source = "../modules/apps/metallb"

  namespace      = "metallb-system"
  chart_version  = "0.14.9"
  create_ip_pool = var.config[terraform.workspace].metallb_create_ip_pool
  ip_pool_name   = "default-pool"
  ip_pool_addresses = lookup(
    var.config[terraform.workspace],
    "metallb_ip_pool_addresses",
    []
  )
  l2_advertisement_name = "default-l2"
}

module "externaldns" {
  count  = contains(local.workload, "externaldns") ? 1 : 0
  source = "../modules/apps/externaldns"

  deployment_name      = "external-dns-pihole"
  dns_provider         = "pihole"
  create_pihole_secret = terraform.workspace == "sandbox" ? true : false
  pihole_password      = terraform.workspace == "sandbox" ? local.secrets_json["kv/cluster-secret-store/secrets/EXTERNAL_DNS_PIHOLE_PASSWORD"]["PIHOLE_PASSWORD"] : ""

  crds_installed = var.config[terraform.workspace].crds_installed
  container_args = contains(local.workload, "istio") ? [
    "--pihole-tls-skip-verify",
    "--source=ingress",
    "--source=istio-gateway",
    "--source=istio-virtualservice",
    "--registry=noop",
    "--policy=sync",
    "--provider=pihole",
    "--pihole-server=http://192.168.1.3",
    ] : [
    "--pihole-tls-skip-verify",
    "--source=ingress",
    "--source=service",
    "--registry=noop",
    "--policy=sync",
    "--provider=pihole",
    "--pihole-server=http://192.168.1.3",
  ]
}

module "externaldns_cloudflare" {
  count  = contains(local.workload, "externaldns") ? 1 : 0
  source = "../modules/apps/externaldns"

  crds_installed           = var.config[terraform.workspace].crds_installed
  deployment_name          = "external-dns-cloudflare"
  dns_provider             = "cloudflare"
  create_cloudflare_secret = true
  cloudflare_api_token     = local.secrets_json["kv/cloudflare"]["api-token"]
  container_args = !contains(local.workload, "istio") ? [
    "--source=ingress",
    "--registry=txt",
    "--txt-owner-id=k8s-${terraform.workspace}",
    "--policy=sync",
    "--provider=cloudflare",
    ] : [
    "--source=ingress",
    "--source=istio-gateway",
    "--source=istio-virtualservice",
    "--registry=txt",
    "--txt-owner-id=k8s-${terraform.workspace}",
    "--policy=sync",
    "--provider=cloudflare",
  ]
  create_namespace = false
}

moved {
  from = module.externaldns[0].module.namespace.kubernetes_namespace.this[0]
  to   = module.externaldns[0].module.namespace[0].kubernetes_namespace.this[0]
}
module "cert_manager" {
  count  = contains(local.workload, "cert_manager") ? 1 : 0
  source = "../modules/apps/certmanager"

  install_crd       = var.config[terraform.workspace].crds_installed
  issuer_type       = "acme"
  cloudflare_secret = local.secrets_json["kv/cloudflare"]["api-token"]
}

module "external_secrets" {
  count  = contains(local.workload, "external_secrets") ? 1 : 0
  source = "../modules/apps/external-secrets"

  install_crd = var.config[terraform.workspace].crds_installed
  secret_data = local.secret_data
  vault_addr  = try(var.config[terraform.workspace].vault_addr, "https://vault.toolz.homelabz.eu")
  vault_token = var.VAULT_TOKEN

  namespace_selector_type = "label"
  namespace_selector_label = {
    key   = "cluster-secrets"
    value = "true"
  }
}


module "github_runner" {
  count  = contains(local.workload, "github_runner") ? 1 : 0
  source = "../modules/apps/github-runner"

  github_token            = local.secrets_json["kv/cluster-secret-store/secrets/github_token"]["github_token"]
  install_crd             = var.config[terraform.workspace].crds_installed
  enable_buildkit_runners = true
  registry_server         = try(var.config[terraform.workspace].github_runner.registry_server, "")
  registry_username       = try(data.kubernetes_secret.harbor_credentials[0].data["admin_username"], "")
  registry_password       = try(data.kubernetes_secret.harbor_credentials[0].data["admin_password"], "")
}

module "gitlab_runner" {
  count  = contains(local.workload, "gitlab_runner") ? 1 : 0
  source = "../modules/apps/gitlab-runner"

  gitlab_token = local.secrets_json["kv/cluster-secret-store/secrets/GITLAB_TOKEN"]["GITLAB_TOKEN"]
}

module "gitea" {
  count  = contains(local.workload, "gitea") ? 1 : 0
  source = "../modules/git/gitea"

  domain     = try(var.config[terraform.workspace].gitea.domain, "git.homelabz.eu")
  ssh_domain = try(var.config[terraform.workspace].gitea.ssh_domain, "git.homelabz.eu")
  ssh_port   = try(var.config[terraform.workspace].gitea.ssh_port, 2222)

  admin_username = "gitea-admin"
  admin_password = try(local.secrets_json["kv/cluster-secret-store/secrets/GITEA"]["ADMIN_PASSWORD"], "")
  secret_key     = try(local.secrets_json["kv/cluster-secret-store/secrets/GITEA"]["SECRET_KEY"], "")
  internal_token = try(local.secrets_json["kv/cluster-secret-store/secrets/GITEA"]["INTERNAL_TOKEN"], "")

  external_database_host     = "postgres.homelabz.eu"
  external_database_name     = "gitea"
  external_database_username = "postgres"
  external_database_password = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]

  external_redis_host     = "redis-master.default.svc.cluster.local"
  external_redis_password = local.secrets_json["kv/cluster-secret-store/secrets/REDIS"]["REDIS_PASSWORD"]

  ingress_class_name = try(var.config[terraform.workspace].gitea.ingress_class, "traefik")
  ingress_annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = try(var.config[terraform.workspace].gitea.domain, "git.homelabz.eu")
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
  }

  default_actions_url = try(var.config[terraform.workspace].gitea.default_actions_url, "https://git.homelabz.eu")

  depends_on = [module.redis]
}

module "gitea_runner" {
  count  = contains(local.workload, "gitea_runner") ? 1 : 0
  source = "../modules/cicd/gitea-runner"

  gitea_url    = try(var.config[terraform.workspace].gitea.url, "https://git.homelabz.eu")
  runner_token = try(local.secrets_json["kv/cluster-secret-store/secrets/GITEA"]["RUNNER_TOKEN"], "")
  runner_name  = "k8s-runner-${terraform.workspace}"

  depends_on = [module.gitea]
}

module "ingress_nginx" {
  count  = contains(local.workload, "ingress_nginx") ? 1 : 0
  source = "../modules/apps/ingress-nginx"

}

module "istio" {
  count  = contains(local.workload, "istio") ? 1 : 0
  source = "../modules/apps/istio"

  gateway_service_type = "LoadBalancer"

  pilot_replicas   = 1
  gateway_replicas = 1

  enable_telemetry = true
  enable_tracing   = false # Can be enabled later to integrate with Jaeger
  access_log_file  = "/dev/stdout"

  istio_CRDs         = try(var.config[terraform.workspace].istio_CRDs, false)
  default_tls_secret = "default-gateway-tls"

  cert_issuer_name  = "letsencrypt-prod"
  cert_issuer_kind  = "ClusterIssuer"
  gateway_dns_names = try(var.config[terraform.workspace].gateway_dns_names, [])
}

module "argocd" {
  count  = contains(local.workload, "argocd") ? 1 : 0
  source = "../modules/apps/argocd"

  namespace              = "argocd"
  install_argocd         = terraform.workspace == "toolz"
  install_bootstrap      = try(var.config[terraform.workspace].argocd_install_bootstrap, false)
  argocd_version         = "7.7.12"
  argocd_domain          = var.config[terraform.workspace].argocd_domain
  ingress_enabled        = var.config[terraform.workspace].argocd_ingress_enabled
  ingress_class_name     = var.config[terraform.workspace].argocd_ingress_class
  cert_issuer            = "letsencrypt-prod"
  use_istio              = contains(local.workload, "istio")
  admin_password_bcrypt  = local.secrets_json["kv/cluster-secret-store/secrets/ARGOCD"]["ADMIN_PASSWORD_BCRYPT"]
  application_namespaces = "*"
  enable_notifications   = true
  enable_dex             = false
  istio_CRDs             = var.config[terraform.workspace].istio_CRDs
}

module "minio" {
  count                       = contains(local.workload, "minio") ? 1 : 0
  source                      = "../modules/apps/minio"
  ingress_annotations         = var.config[terraform.workspace].minio.ingress_annotations
  ingress_class_name          = var.config[terraform.workspace].minio.ingress_class_name
  ingress_host                = var.config[terraform.workspace].minio.ingress_host
  console_ingress_annotations = var.config[terraform.workspace].minio.console_ingress_annotations
  console_ingress_class_name  = var.config[terraform.workspace].minio.console_ingress_class_name
  console_ingress_host        = var.config[terraform.workspace].minio.console_ingress_host


  root_password  = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]
  memory_request = try(var.config[terraform.workspace].minio_memory_request, "256Mi")
  cpu_request    = try(var.config[terraform.workspace].minio_cpu_request, "50m")
  memory_limit   = try(var.config[terraform.workspace].minio_memory_limit, "512Mi")
  cpu_limit      = try(var.config[terraform.workspace].minio_cpu_limit, "200m")
}

module "oracle_backup" {
  count  = contains(keys(var.config[terraform.workspace]), "oracle_backup") ? 1 : 0
  source = "../modules/apps/oracle-backup"

  namespace        = "oracle-backup"
  create_namespace = true

  enable_s3_backup       = try(var.config[terraform.workspace].oracle_backup.enable_s3_backup, false)
  enable_postgres_backup = try(var.config[terraform.workspace].oracle_backup.enable_postgres_backup, false)

  s3_backup_name    = "terraform-state-backup"
  s3_schedule       = "0 2 * * *"
  minio_endpoint    = "https://s3.toolz.homelabz.eu"
  minio_bucket_path = "terraform"
  s3_backup_path    = "terraform-state-backup"

  postgres_backups = {
    for key, config in try(var.config[terraform.workspace].oracle_backup.postgres_backups, {}) : key => {
      namespace      = config.namespace
      host           = config.host
      port           = config.port
      database       = config.database
      username       = config.username
      ssl_enabled    = config.ssl_enabled
      schedule       = config.schedule
      backup_path    = config.backup_path
      databases      = try(config.databases, [])
      memory_request = try(config.memory_request, "256Mi")
      memory_limit   = try(config.memory_limit, "1Gi")
      cpu_request    = try(config.cpu_request, "200m")
      cpu_limit      = try(config.cpu_limit, "1000m")
      secret_name    = try(config.secret_name, "")
      secret_key     = try(config.secret_key, "password")
    }
  }

  memory_request = "256Mi"
  memory_limit   = "1Gi"
  cpu_request    = "200m"
  cpu_limit      = "1000m"

  depends_on = [module.minio, module.external_secrets]
}

module "registry" {
  count  = contains(local.workload, "registry") ? 1 : 0
  source = "../modules/apps/registry"

}

module "vault" {
  count                      = contains(local.workload, "vault") ? 1 : 0
  source                     = "../modules/apps/vault"
  initial_secrets            = local.vault_secrets
  ingress_class_name         = try(var.config[terraform.workspace].argocd_ingress_class, "traefik")
  data_storage_storage_class = try(var.config[terraform.workspace].vault_storage_class, "local-path")
  ingress_annotations = try(var.config[terraform.workspace].vault_ingress_annotations, {
    "external-dns.alpha.kubernetes.io/hostname" = "vault.toolz.homelabz.eu"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
  })
  ingress_host   = try(var.config[terraform.workspace].vault_ingress_host, "vault.toolz.homelabz.eu")
  memory_request = try(var.config[terraform.workspace].vault_memory_request, "256Mi")
  cpu_request    = try(var.config[terraform.workspace].vault_cpu_request, "100m")
  memory_limit   = try(var.config[terraform.workspace].vault_memory_limit, "512Mi")
  cpu_limit      = try(var.config[terraform.workspace].vault_cpu_limit, "300m")
}

module "observability" {
  count  = contains(local.workload, "observability") ? 1 : 0
  source = "../modules/apps/observability"

  minio_rootPassword = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]
  install_crd        = var.config[terraform.workspace].crds_installed
}

module "observability-box" {
  count  = contains(local.workload, "observability-box") ? 1 : 0
  source = "../modules/apps/observability-box"

  prometheus_namespaces     = try(var.config[terraform.workspace].prometheus_namespaces, [])
  prometheus_memory_limit   = try(var.config[terraform.workspace].prometheus_memory_limit, "1024Mi")
  prometheus_memory_request = try(var.config[terraform.workspace].prometheus_memory_request, "256Mi")
  prometheus_storage_size   = try(var.config[terraform.workspace].prometheus_storage_size, "")
}

module "redis" {
  count               = contains(local.workload, "redis") ? 1 : 0
  source              = "../modules/apps/redis"
  ingress_enabled     = try(var.config[terraform.workspace].redis.ingress_enabled, true)
  ingress_class_name  = var.config[terraform.workspace].redis.ingress_class_name
  ingress_annotations = var.config[terraform.workspace].redis.ingress_annotations
  ingress_host        = var.config[terraform.workspace].redis.ingress_host
  service_type        = try(var.config[terraform.workspace].redis.service_type, "ClusterIP")
  service_annotations = try(var.config[terraform.workspace].redis.service_annotations, {})
  memory_request      = try(var.config[terraform.workspace].redis_memory_request, "512Mi")
  cpu_request         = try(var.config[terraform.workspace].redis_cpu_request, "200m")
  memory_limit        = try(var.config[terraform.workspace].redis_memory_limit, "1Gi")
  cpu_limit           = try(var.config[terraform.workspace].redis_cpu_limit, "500m")
}


module "nats" {
  count  = contains(local.workload, "nats") ? 1 : 0
  source = "../modules/apps/nats"

}

module "harbor" {
  count  = contains(local.workload, "harbor") ? 1 : 0
  source = "../modules/apps/harbor"

  external_database_host     = "postgres.homelabz.eu"
  external_database_username = "postgres"
  external_database_password = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]
  external_redis_host        = data.kubernetes_secret.redis_credentials[0].data["redis_host"]
  external_redis_password    = data.kubernetes_secret.redis_credentials[0].data["redis_password"]
  harbor_domain              = var.config[terraform.workspace].harbor.harbor_domain
  ingress_class_name         = var.config[terraform.workspace].harbor.ingress_class_name
  ingress_annotations        = var.config[terraform.workspace].harbor.ingress_annotations
  ingress_enabled            = true
  admin_password             = local.secrets_json["kv/cluster-secret-store/secrets/HARBOR_KEY"]["HARBOR_KEY"]
  generate_admin_password    = false
  registry_existing_claim    = try(var.config[terraform.workspace].harbor.registry_existing_claim, "")
  registry_storage_size      = try(var.config[terraform.workspace].harbor.registry_storage_size, "5Gi")
}

module "harbor_replication" {
  count  = contains(local.workload, "harbor") ? 1 : 0
  source = "../modules/apps/harbor-replication"

  registries = {
    dockerhub = {
      endpoint_url  = "https://hub.docker.com"
      provider_name = "docker-hub"
      description   = "Docker Hub"
    }
    ghcr = {
      endpoint_url  = "https://ghcr.io"
      provider_name = "github"
      description   = "GitHub Container Registry"
    }
    k8s = {
      endpoint_url  = "https://registry.k8s.io"
      provider_name = "docker-registry"
      description   = "Kubernetes registry"
    }
    quay = {
      endpoint_url  = "https://quay.io"
      provider_name = "quay"
      description   = "Quay.io"
    }
    fluentbit = {
      endpoint_url  = "https://cr.fluentbit.io"
      provider_name = "docker-registry"
      description   = "Fluent Bit registry"
    }
    gcr = {
      endpoint_url  = "https://gcr.io"
      provider_name = "docker-registry"
      description   = "Google Container Registry"
    }
    ecr-public = {
      endpoint_url  = "https://public.ecr.aws"
      provider_name = "docker-registry"
      description   = "AWS ECR Public"
    }
    external-secrets = {
      endpoint_url  = "https://oci.external-secrets.io"
      provider_name = "docker-registry"
      description   = "External Secrets OCI registry"
    }
    gitlab = {
      endpoint_url  = "https://registry.gitlab.com"
      provider_name = "gitlab"
      description   = "GitLab Container Registry"
    }
  }

  images = {
    # docker.io
    alpine                           = { registry_key = "dockerhub", name = "library/alpine" }
    busybox                          = { registry_key = "dockerhub", name = "library/busybox" }
    nats                             = { registry_key = "dockerhub", name = "library/nats" }
    docker-dind                      = { registry_key = "dockerhub", name = "library/docker" }
    ubuntu                           = { registry_key = "dockerhub", name = "library/ubuntu" }
    bitnami-kubectl                  = { registry_key = "dockerhub", name = "bitnami/kubectl" }
    bitnami-os-shell                 = { registry_key = "dockerhub", name = "bitnami/os-shell" }
    bitnami-postgresql               = { registry_key = "dockerhub", name = "bitnami/postgresql" }
    bitnami-redis                    = { registry_key = "dockerhub", name = "bitnami/redis" }
    calico-cni                       = { registry_key = "dockerhub", name = "calico/cni" }
    calico-kube-controllers          = { registry_key = "dockerhub", name = "calico/kube-controllers" }
    calico-node                      = { registry_key = "dockerhub", name = "calico/node" }
    curlimages-curl                  = { registry_key = "dockerhub", name = "curlimages/curl" }
    falco                            = { registry_key = "dockerhub", name = "falcosecurity/falco" }
    falcoctl                         = { registry_key = "dockerhub", name = "falcosecurity/falcoctl" }
    harbor-core                      = { registry_key = "dockerhub", name = "goharbor/harbor-core" }
    harbor-jobservice                = { registry_key = "dockerhub", name = "goharbor/harbor-jobservice" }
    harbor-portal                    = { registry_key = "dockerhub", name = "goharbor/harbor-portal" }
    harbor-registryctl               = { registry_key = "dockerhub", name = "goharbor/harbor-registryctl" }
    registry-photon                  = { registry_key = "dockerhub", name = "goharbor/registry-photon" }
    trivy-adapter-photon             = { registry_key = "dockerhub", name = "goharbor/trivy-adapter-photon" }
    vault                            = { registry_key = "dockerhub", name = "hashicorp/vault" }
    vault-k8s                        = { registry_key = "dockerhub", name = "hashicorp/vault-k8s" }
    istio-pilot                      = { registry_key = "dockerhub", name = "istio/pilot" }
    istio-proxyv2                    = { registry_key = "dockerhub", name = "istio/proxyv2" }
    buildkit                         = { registry_key = "dockerhub", name = "moby/buildkit" }
    natsio-nats-box                  = { registry_key = "dockerhub", name = "natsio/nats-box" }
    nats-config-reloader             = { registry_key = "dockerhub", name = "natsio/nats-server-config-reloader" }
    otel-collector-contrib           = { registry_key = "dockerhub", name = "otel/opentelemetry-collector-contrib" }
    nicolaka-netshoot                = { registry_key = "dockerhub", name = "nicolaka/netshoot" }
    minio-mc                         = { registry_key = "dockerhub", name = "minio/mc" }
    pgvecto-rs                       = { registry_key = "dockerhub", name = "tensorchord/pgvecto-rs" }
    rancher-local-path-provisioner   = { registry_key = "dockerhub", name = "rancher/local-path-provisioner" }
    rancher-klipper-helm             = { registry_key = "dockerhub", name = "rancher/klipper-helm" }
    rancher-klipper-lb               = { registry_key = "dockerhub", name = "rancher/klipper-lb" }
    rancher-mirrored-coredns         = { registry_key = "dockerhub", name = "rancher/mirrored-coredns-coredns" }
    rancher-mirrored-busybox         = { registry_key = "dockerhub", name = "rancher/mirrored-library-busybox" }
    rancher-mirrored-traefik         = { registry_key = "dockerhub", name = "rancher/mirrored-library-traefik" }
    rancher-mirrored-metrics-server  = { registry_key = "dockerhub", name = "rancher/mirrored-metrics-server" }
    rancher-mirrored-pause           = { registry_key = "dockerhub", name = "rancher/mirrored-pause" }
    rancher-mirrored-calico-cni      = { registry_key = "dockerhub", name = "rancher/mirrored-calico-cni" }
    rancher-mirrored-calico-ctrl     = { registry_key = "dockerhub", name = "rancher/mirrored-calico-kube-controllers" }
    rancher-mirrored-calico-node     = { registry_key = "dockerhub", name = "rancher/mirrored-calico-node" }
    rancher-mirrored-calico-operator = { registry_key = "dockerhub", name = "rancher/mirrored-calico-operator" }
    rancher-mirrored-calico-flexvol  = { registry_key = "dockerhub", name = "rancher/mirrored-calico-pod2daemon-flexvol" }
    rancher-mirrored-calico-typha    = { registry_key = "dockerhub", name = "rancher/mirrored-calico-typha" }
    rancher-hardened-etcd            = { registry_key = "dockerhub", name = "rancher/hardened-etcd" }
    rancher-hardened-kubernetes      = { registry_key = "dockerhub", name = "rancher/hardened-kubernetes" }
    rancher-hardened-coredns         = { registry_key = "dockerhub", name = "rancher/hardened-coredns" }
    rancher-hardened-metrics-server  = { registry_key = "dockerhub", name = "rancher/hardened-k8s-metrics-server" }
    rancher-hardened-autoscaler      = { registry_key = "dockerhub", name = "rancher/hardened-cluster-autoscaler" }
    rancher-rke2-cloud-provider      = { registry_key = "dockerhub", name = "rancher/rke2-cloud-provider" }
    rancher-nginx-ingress-controller = { registry_key = "dockerhub", name = "rancher/nginx-ingress-controller" }
    rancher-mirrored-snapshot-ctrl   = { registry_key = "dockerhub", name = "rancher/mirrored-sig-storage-snapshot-controller" }
    longhornio-engine                = { registry_key = "dockerhub", name = "longhornio/longhorn-engine" }
    longhornio-manager               = { registry_key = "dockerhub", name = "longhornio/longhorn-manager" }
    longhornio-instance-manager      = { registry_key = "dockerhub", name = "longhornio/longhorn-instance-manager" }
    longhornio-share-manager         = { registry_key = "dockerhub", name = "longhornio/longhorn-share-manager" }
    longhornio-ui                    = { registry_key = "dockerhub", name = "longhornio/longhorn-ui" }
    longhornio-csi-attacher          = { registry_key = "dockerhub", name = "longhornio/csi-attacher" }
    longhornio-csi-node-registrar    = { registry_key = "dockerhub", name = "longhornio/csi-node-driver-registrar" }
    longhornio-csi-provisioner       = { registry_key = "dockerhub", name = "longhornio/csi-provisioner" }
    longhornio-csi-resizer           = { registry_key = "dockerhub", name = "longhornio/csi-resizer" }
    longhornio-csi-snapshotter       = { registry_key = "dockerhub", name = "longhornio/csi-snapshotter" }
    longhornio-livenessprobe         = { registry_key = "dockerhub", name = "longhornio/livenessprobe" }

    # ghcr.io
    actions-runner            = { registry_key = "ghcr", name = "actions/actions-runner" }
    gha-controller            = { registry_key = "ghcr", name = "actions/gha-runner-scale-set-controller" }
    cloudnative-pg            = { registry_key = "ghcr", name = "cloudnative-pg/cloudnative-pg" }
    cloudnative-pg-postgresql = { registry_key = "ghcr", name = "cloudnative-pg/postgresql" }
    goauthentik-server        = { registry_key = "ghcr", name = "goauthentik/server" }
    immich-server             = { registry_key = "ghcr", name = "immich-app/immich-server" }
    immich-ml                 = { registry_key = "ghcr", name = "immich-app/immich-machine-learning" }
    capmox                    = { registry_key = "ghcr", name = "ionos-cloud/cluster-api-provider-proxmox" }
    capi-k3s-bootstrap        = { registry_key = "ghcr", name = "k3s-io/cluster-api-k3s/bootstrap-controller" }
    capi-k3s-controlplane     = { registry_key = "ghcr", name = "k3s-io/cluster-api-k3s/controlplane-controller" }
    kube-vip                  = { registry_key = "ghcr", name = "kube-vip/kube-vip" }
    capi-rke2-bootstrap       = { registry_key = "ghcr", name = "rancher/cluster-api-provider-rke2-bootstrap" }
    capi-rke2-controlplane    = { registry_key = "ghcr", name = "rancher/cluster-api-provider-rke2-controlplane" }
    capi-talos-cp-controller  = { registry_key = "ghcr", name = "siderolabs/cluster-api-control-plane-talos-controller" }
    capi-talos-controller     = { registry_key = "ghcr", name = "siderolabs/cluster-api-talos-controller" }
    siderolabs-flannel        = { registry_key = "ghcr", name = "siderolabs/flannel" }
    talos-ccm                 = { registry_key = "ghcr", name = "siderolabs/talos-cloud-controller-manager" }
    kubelet-cert-approver     = { registry_key = "ghcr", name = "alex1989hu/kubelet-serving-cert-approver" }

    # registry.k8s.io
    k8s-coredns                 = { registry_key = "k8s", name = "coredns/coredns" }
    k8s-etcd                    = { registry_key = "k8s", name = "etcd" }
    k8s-kube-apiserver          = { registry_key = "k8s", name = "kube-apiserver" }
    k8s-kube-controller-manager = { registry_key = "k8s", name = "kube-controller-manager" }
    k8s-kube-proxy              = { registry_key = "k8s", name = "kube-proxy" }
    k8s-kube-scheduler          = { registry_key = "k8s", name = "kube-scheduler" }
    k8s-pause                   = { registry_key = "k8s", name = "pause" }
    k8s-external-dns            = { registry_key = "k8s", name = "external-dns/external-dns" }
    k8s-kube-state-metrics      = { registry_key = "k8s", name = "kube-state-metrics/kube-state-metrics" }
    k8s-metrics-server          = { registry_key = "k8s", name = "metrics-server/metrics-server" }
    k8s-cluster-autoscaler      = { registry_key = "k8s", name = "autoscaling/cluster-autoscaler" }
    k8s-capi-operator           = { registry_key = "k8s", name = "capi-operator/cluster-api-operator" }
    k8s-capi-controller         = { registry_key = "k8s", name = "cluster-api/cluster-api-controller" }
    k8s-capi-kubeadm-bootstrap  = { registry_key = "k8s", name = "cluster-api/kubeadm-bootstrap-controller" }
    k8s-capi-kubeadm-cp         = { registry_key = "k8s", name = "cluster-api/kubeadm-control-plane-controller" }
    k8s-capi-ipam               = { registry_key = "k8s", name = "capi-ipam-ic/cluster-api-ipam-in-cluster-controller" }
    k8s-snapshot-controller     = { registry_key = "k8s", name = "sig-storage/snapshot-controller" }

    # quay.io
    argocd                       = { registry_key = "quay", name = "argoproj/argocd" }
    argo-rollouts                = { registry_key = "quay", name = "argoproj/argo-rollouts" }
    kubectl-argo-rollouts        = { registry_key = "quay", name = "argoproj/kubectl-argo-rollouts" }
    cert-manager-cainjector      = { registry_key = "quay", name = "jetstack/cert-manager-cainjector" }
    cert-manager-controller      = { registry_key = "quay", name = "jetstack/cert-manager-controller" }
    cert-manager-webhook         = { registry_key = "quay", name = "jetstack/cert-manager-webhook" }
    cert-manager-startupapicheck = { registry_key = "quay", name = "jetstack/cert-manager-startupapicheck" }
    metallb-controller           = { registry_key = "quay", name = "metallb/controller" }
    metallb-speaker              = { registry_key = "quay", name = "metallb/speaker" }
    prometheus                   = { registry_key = "quay", name = "prometheus/prometheus" }
    node-exporter                = { registry_key = "quay", name = "prometheus/node-exporter" }
    prometheus-config-reloader   = { registry_key = "quay", name = "prometheus-operator/prometheus-config-reloader" }
    minio                        = { registry_key = "quay", name = "minio/minio" }
    minio-mc-quay                = { registry_key = "quay", name = "minio/mc" }
    frr                          = { registry_key = "quay", name = "frrouting/frr" }
    kubevirt-virt-operator       = { registry_key = "quay", name = "kubevirt/virt-operator" }
    kubevirt-virt-api            = { registry_key = "quay", name = "kubevirt/virt-api" }
    kubevirt-virt-controller     = { registry_key = "quay", name = "kubevirt/virt-controller" }
    kubevirt-virt-handler        = { registry_key = "quay", name = "kubevirt/virt-handler" }
    kubevirt-virt-launcher       = { registry_key = "quay", name = "kubevirt/virt-launcher" }
    kubevirt-virt-exportproxy    = { registry_key = "quay", name = "kubevirt/virt-exportproxy" }
    kubevirt-cdi-operator        = { registry_key = "quay", name = "kubevirt/cdi-operator" }
    kubevirt-cdi-controller      = { registry_key = "quay", name = "kubevirt/cdi-controller" }
    kubevirt-cdi-apiserver       = { registry_key = "quay", name = "kubevirt/cdi-apiserver" }
    kubevirt-cdi-uploadproxy     = { registry_key = "quay", name = "kubevirt/cdi-uploadproxy" }
    k0smotron                    = { registry_key = "quay", name = "k0sproject/k0smotron" }
    k0s                          = { registry_key = "quay", name = "k0sproject/k0s" }

    # cr.fluentbit.io
    fluent-bit = { registry_key = "fluentbit", name = "fluent/fluent-bit" }

    # gcr.io
    kube-rbac-proxy = { registry_key = "gcr", name = "kubebuilder/kube-rbac-proxy" }

    # public.ecr.aws
    ecr-redis           = { registry_key = "ecr-public", name = "docker/library/redis" }
    teleport-distroless = { registry_key = "ecr-public", name = "gravitational/teleport-distroless" }

    # oci.external-secrets.io
    external-secrets = { registry_key = "external-secrets", name = "external-secrets/external-secrets" }

    # registry.gitlab.com
    gitlab-runner = { registry_key = "gitlab", name = "gitlab-org/gitlab-runner" }
  }

  depends_on = [module.harbor]
}

module "immich" {
  count  = contains(local.workload, "immich") ? 1 : 0
  source = "../modules/apps/immich"

  redis         = "redis.toolz.homelabz.eu"
  redis_pass    = local.secrets_json["kv/cluster-secret-store/secrets/REDIS"]["REDIS_PASSWORD"]
  db_hostname   = "192.168.1.100"
  db_user       = "postgres"
  db_name       = "immich"
  db_pass       = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]
  immich_domain = "immich.homelabz.eu"

}

module "kubevirt_operator" {
  count  = contains(local.workload, "kubevirt") ? 1 : 0
  source = "../modules/apps/kubevirt-operator"

}

module "kubevirt" {
  count  = contains(local.workload, "kubevirt") ? 1 : 0
  source = "../modules/apps/kubevirt"

  namespace          = "kubevirt"
  create_kubevirt_cr = true
  create_cdi_cr      = true

  kubevirt_feature_gates = ["Snapshot", "VMExport"]
  cdi_feature_gates      = ["HonorWaitForFirstConsumer"]

  enable_cdi_uploadproxy_ingress = true
  cdi_uploadproxy_host           = try(var.config[terraform.workspace].kubevirt.cdi_uploadproxy_host, "cdi-uploadproxy.homelabz.eu")
  virt_exportproxy_host          = try(var.config[terraform.workspace].kubevirt.virt_exportproxy_host, "kubevirt-exportproxy.homelabz.eu")
  ingress_class_name             = try(var.config[terraform.workspace].kubevirt.ingress_class_name, "traefik")

  depends_on = [module.kubevirt_operator]
}

module "longhorn" {
  count  = contains(local.workload, "longhorn") ? 1 : 0
  source = "../modules/apps/longhorn"

  replica_count      = 1
  ingress_host       = try(var.config[terraform.workspace].longhorn.ingress_host, "longhorn.homelabz.eu")
  ingress_class_name = try(var.config[terraform.workspace].longhorn.ingress_class_name, "traefik")
  ingress_annotations = try(var.config[terraform.workspace].longhorn.ingress_annotations, {
    "external-dns.alpha.kubernetes.io/hostname" = "longhorn.homelabz.eu"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
  })
}

module "clusterapi_operator" {
  count  = contains(local.workload, "clusterapi-operator") ? 1 : 0
  source = "../modules/apps/clusterapi-operator"

  enable_core_provider      = true
  enable_talos_provider     = true
  enable_k3s_provider       = true
  enable_kubeadm_provider   = true
  enable_k0smotron_provider = false
  enable_rke2_provider      = true

  proxmox_secret_name = "proxmox-credentials"
  proxmox_url         = element(split("/api2", local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_URL"]["PROXMOX_URL"]), 0)
  proxmox_secret      = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_SECRET"]["PROXMOX_SECRET"]
  proxmox_token       = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_TOKEN_ID"]["PROXMOX_TOKEN_ID"]

}

module "kubernetes_clusters" {
  count  = contains(keys(var.config[terraform.workspace]), "kubernetes-cluster") ? 1 : 0
  source = "../modules/apps/kubernetes-cluster"

  clusters = try(var.config[terraform.workspace].kubernetes-cluster, [{}])

  cluster_api_dependencies = [module.clusterapi_operator]

  create_proxmox_secret = true
  proxmox_url           = element(split("/api2", local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_URL"]["PROXMOX_URL"]), 0)
  proxmox_secret        = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_SECRET"]["PROXMOX_SECRET"]
  proxmox_token         = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_TOKEN_ID"]["PROXMOX_TOKEN_ID"]
  ssh_authorized_keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+mJj63c+7o+Bu40wNnXwTpXkPTpGJA9OIprmNoljKI pedro@pedro-Legion-5-16IRX9"
  ]
}

data "kubernetes_secret" "redis_credentials" {
  count = contains(local.workload, "harbor") ? 1 : 0

  metadata {
    name      = "redis-credentials"
    namespace = "default"
  }
}


data "kubernetes_secret" "harbor_credentials" {
  count = contains(local.workload, "github_runner") ? 1 : 0

  metadata {
    name      = "harbor-credentials"
    namespace = "harbor"
  }
}

data "vault_kv_secret_v2" "postgres_ca" {
  for_each = local.postgres_ca_secrets
  mount    = "kv"
  name     = "cluster-secret-store/secrets/${each.key}"
}


module "teleport-agent" {
  count  = contains(local.workload, "teleport-agent") ? 1 : 0
  source = "../modules/apps/teleport-agent"

  kubernetes_cluster_name = terraform.workspace
  join_token              = local.secrets_json["kv/cluster-secret-store/secrets/TELEPORT"]["JOIN_TOKEN"]
  ca_pin                  = local.secrets_json["kv/cluster-secret-store/secrets/TELEPORT"]["CA_PIN"]
  roles                   = var.config[terraform.workspace].teleport.roles
  apps                    = var.config[terraform.workspace].teleport.apps
  databases = {
    for name, db in var.config[terraform.workspace].teleport.databases : name => {
      uri = db.uri
      ca_cert = db.ca_cert != "" ? (
        contains(keys(data.vault_kv_secret_v2.postgres_ca), db.ca_cert) ?
        data.vault_kv_secret_v2.postgres_ca[db.ca_cert].data[db.ca_cert] :
        try(local.secrets_json["kv/cluster-secret-store/secrets/${db.ca_cert}"][db.ca_cert], "")
      ) : ""
    }
  }
}

module "cloudnative_pg_operator" {
  count  = contains(local.workload, "cloudnative-pg-operator") ? 1 : 0
  source = "../modules/apps/cloudnative-postgres-operator"

  namespace        = "cnpg-system"
  create_namespace = true
  chart_version    = "0.27.0"
}

resource "kubernetes_secret" "teleport_postgres_password" {
  count = contains(local.workload, "postgres-cnpg") ? 1 : 0

  metadata {
    name      = "teleport-postgres-password"
    namespace = "default"
  }

  data = {
    password = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]
  }
}

module "postgres_cnpg" {
  count  = contains(local.workload, "postgres-cnpg") ? 1 : 0
  source = "../modules/apps/cloudnative-postgres"

  cluster_name     = "postgres"
  namespace        = "default"
  create_namespace = false
  create_cluster   = try(var.config[terraform.workspace].postgres_cnpg.crds_installed, false)

  registry   = "registry.toolz.homelabz.eu"
  repository = "library/cloudnative-postgres"
  pg_version = "15-latest"

  postgres_generate_password = try(var.config[terraform.workspace].postgres_cnpg.generate_password, true)
  postgres_password          = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]

  persistence_size = try(var.config[terraform.workspace].postgres_cnpg.persistence_size, "10Gi")
  storage_class    = ""

  memory_request = try(var.config[terraform.workspace].postgres_memory_request, "512Mi")
  cpu_request    = try(var.config[terraform.workspace].postgres_cpu_request, "250m")
  memory_limit   = try(var.config[terraform.workspace].postgres_memory_limit, "1Gi")
  cpu_limit      = try(var.config[terraform.workspace].postgres_cpu_limit, "500m")

  enable_ssl                  = true
  require_cert_auth_for_admin = true

  create_app_user            = true
  app_username               = "appuser"
  app_user_generate_password = true

  export_credentials_to_namespace = "default"
  export_credentials_secret_name  = try(var.config[terraform.workspace].postgres_cnpg.export_credentials_secret_name, "postgres-credentials")

  additional_client_ca_certs = [local.secrets_json["kv/cluster-secret-store/secrets/TELEPORT_DB_CA"]["TELEPORT_DB_CA"]]

  export_ca_to_vault   = true
  vault_ca_secret_path = try(var.config[terraform.workspace].postgres_cnpg.vault_ca_secret_path, "cluster-secret-store/secrets/POSTGRES_CA")
  vault_ca_secret_key  = try(var.config[terraform.workspace].postgres_cnpg.vault_ca_secret_key, "POSTGRES_CA")

  ingress_enabled    = try(var.config[terraform.workspace].postgres_cnpg.ingress_enabled, true)
  ingress_host       = try(var.config[terraform.workspace].postgres_cnpg.ingress_host, "")
  ingress_class_name = try(var.config[terraform.workspace].postgres_cnpg.ingress_class_name, "traefik")
  use_istio          = try(var.config[terraform.workspace].postgres_cnpg.use_istio, false)
  istio_CRDs         = try(var.config[terraform.workspace].istio_CRDs, false)
  create_lb_service  = try(var.config[terraform.workspace].postgres_cnpg.create_lb_service, false)

  enable_superuser_access = try(var.config[terraform.workspace].postgres_cnpg.enable_superuser_access, true)
  managed_roles           = try(var.config[terraform.workspace].postgres_cnpg.managed_roles, [])

  depends_on = [module.cloudnative_pg_operator]
}

module "postgres_databases" {
  source   = "../modules/base/cnpg-database"
  for_each = { for db in try(var.config[terraform.workspace].postgres_cnpg.databases, []) : db.name => db }

  create        = contains(local.workload, "postgres-cnpg")
  name          = each.value.name
  namespace     = "default"
  database_name = each.value.name
  owner         = each.value.owner
  cluster_name  = "postgres"

  locale_collate = try(each.value.locale_collate, null)
  locale_ctype   = try(each.value.locale_ctype, null)

  depends_on = [module.postgres_cnpg]
}

# module "freqtrade" {
#   count  = contains(local.workload, "freqtrade") ? 1 : 0
#   source = "../modules/apps/freqtrade"

#   environment     = terraform.workspace
#   domain          = var.config[terraform.workspace].freqtrade.domain
#   dry_run         = var.config[terraform.workspace].freqtrade.dry_run
#   stake_amount    = var.config[terraform.workspace].freqtrade.stake_amount
#   max_open_trades = var.config[terraform.workspace].freqtrade.max_open_trades
#   freqai_enabled  = var.config[terraform.workspace].freqtrade.freqai

#   binance_api_key    = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["BINANCE_API_KEY"]
#   binance_api_secret = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["BINANCE_API_SECRET"]
#   frequi_password    = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["FREQUI_PASSWORD"]
#   jwt_secret_key     = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["JWT_SECRET_KEY"]
#   telegram_token     = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["TELEGRAM_TOKEN"]
#   telegram_chat_id   = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["TELEGRAM_CHAT_ID"]

#   minio_endpoint   = "minio.homelabz.eu"
#   minio_bucket     = "freqtrade"
#   minio_access_key = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootUser"]
#   minio_secret_key = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]

#   storage_class = "local-path"
#   use_istio     = contains(local.workload, "istio")
#   istio_gateway = "istio-system/default-gateway"
# }

module "cluster_autoscaler" {
  count  = contains(local.workload, "cluster-autoscaler") ? 1 : 0
  source = "../modules/apps/cluster-autoscaler"

  managed_clusters = var.config[terraform.workspace].cluster_autoscaler_managed_clusters
  chart_version    = lookup(var.config[terraform.workspace], "cluster_autoscaler_chart_version", "9.54.0")
  image_tag        = lookup(var.config[terraform.workspace], "cluster_autoscaler_image_tag", "v1.34.2")

  scale_down_enabled         = lookup(var.config[terraform.workspace], "cluster_autoscaler_scale_down_enabled", true)
  scale_down_delay_after_add = lookup(var.config[terraform.workspace], "cluster_autoscaler_scale_down_delay", "10m")
  scale_down_unneeded_time   = lookup(var.config[terraform.workspace], "cluster_autoscaler_unneeded_time", "10m")

  skip_nodes_with_local_storage    = lookup(var.config[terraform.workspace], "cluster_autoscaler_skip_local_storage", true)
  scale_down_utilization_threshold = lookup(var.config[terraform.workspace], "cluster_autoscaler_utilization_threshold", "0.5")
  max_graceful_termination_sec     = lookup(var.config[terraform.workspace], "cluster_autoscaler_max_graceful_termination", "600")
  scale_down_delay_after_delete    = lookup(var.config[terraform.workspace], "cluster_autoscaler_delay_after_delete", "15m")
  scale_down_delay_after_failure   = lookup(var.config[terraform.workspace], "cluster_autoscaler_delay_after_failure", "10m")
  max_node_provision_time          = lookup(var.config[terraform.workspace], "cluster_autoscaler_max_provision_time", "15m")

  replicas = lookup(var.config[terraform.workspace], "cluster_autoscaler_replicas", 1)
}

module "falco" {
  count  = contains(local.workload, "falco") ? 1 : 0
  source = "../modules/apps/falco"
}

module "authentik" {
  count  = contains(local.workload, "authentik") ? 1 : 0
  source = "../modules/apps/authentik"

  domain = var.config[terraform.workspace].authentik.domain

  postgres_host        = "postgres.homelabz.eu"
  postgres_name        = "authentik"
  postgres_user        = "postgres"
  postgres_secret_name = "postgres-superuser"

  redis_host     = "redis-master.default.svc.cluster.local"
  redis_password = local.secrets_json["kv/cluster-secret-store/secrets/REDIS"]["REDIS_PASSWORD"]
  redis_db       = var.config[terraform.workspace].authentik.redis_db

  authentik_secret_key = local.secrets_json["kv/cluster-secret-store/secrets/AUTHENTIK"]["AUTHENTIK_SECRET_KEY"]
  admin_password       = local.secrets_json["kv/cluster-secret-store/secrets/AUTHENTIK"]["AUTHENTIK_ADMIN_PASSWORD"]

  depends_on = [module.redis]
}
