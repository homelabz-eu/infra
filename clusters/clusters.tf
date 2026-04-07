variable "workload" {
  description = "map"
  type        = map(list(string))
  default = {
    clustermgmt = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability-box",
      "clusterapi-operator",
      "cluster-autoscaler",
    ]
    toolz = [
      "local-path-provisioner",
      "metallb",
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability-box",
      "gitlab_runner",
      "harbor_replication",
      "vault",
      "argocd",
      "teleport-agent",
      "kubevirt",
      "longhorn",
      "ollama",
    ]
    observability = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability"
    ]
    home = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability-box",
      "immich",
      "kiwix",
      "paperless_ngx"
    ]
    media = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "media_storage",
      "prowlarr",
      "radarr",
      "sonarr",
      "qbittorrent",
      "plex",
    ]
    prod = [
      "local-path-provisioner",
      "metrics-server",
      "metallb",
      "externaldns",
      "cert_manager",
      "external_secrets",
      "istio",
      "argocd",
      "teleport-agent",
      "observability-box",
    ]
  }
}

variable "config" {
  description = "Map of providers with configuration per workspace."
  default = {
    clustermgmt = {
      kubernetes_context = "clustermgmt"
      crds_installed     = true
      istio_CRDs         = false
      teleport = {
        apps = {
          "harbor" = "http://harbor-portal.harbor.svc.cluster.local"
          "vault"  = "http://vault.vault.svc.cluster.local:8200"
        }
        roles = "kube,app"
      }
      prometheus_namespaces     = []
      prometheus_memory_limit   = "2048Mi"
      prometheus_memory_request = "512Mi"
      oracle_backup = {
        enable_s3_backup       = true
        enable_postgres_backup = true
        postgres_backups = {
          "postgres" = {
            namespace   = "oracle-backup"
            host        = "postgres.homelabz.eu"
            port        = 5432
            database    = "postgres"
            username    = "postgres"
            ssl_enabled = false
            schedule    = "0 3 * * *"
            backup_path = "postgres-backup/tools"
            secret_name = "cluster-secrets"   #pragma: allowlist secret
            secret_key  = "POSTGRES_PASSWORD" #pragma: allowlist secret
          }
        }
      }

      cluster_autoscaler_managed_clusters = [
        {
          name      = "toolz"
          namespace = "toolz"
        }
      ]
      cluster_autoscaler_chart_version            = "9.54.0"
      cluster_autoscaler_image_tag                = "v1.33.0"
      cluster_autoscaler_scale_down_enabled       = false
      cluster_autoscaler_scale_down_delay         = "10m"
      cluster_autoscaler_unneeded_time            = "10m"
      cluster_autoscaler_skip_local_storage       = true
      cluster_autoscaler_utilization_threshold    = "1.0"
      cluster_autoscaler_max_graceful_termination = "600"
      cluster_autoscaler_delay_after_delete       = "15m"
      cluster_autoscaler_delay_after_failure      = "10m"
      cluster_autoscaler_max_provision_time       = "15m"
      cluster_autoscaler_replicas                 = 1

      kubernetes-cluster = [
        {
          cluster_type              = "kubeadm"
          name                      = "prod"
          kubernetes_version        = "v1.31.4"
          control_plane_endpoint_ip = "192.168.1.70"
          ip_range_start            = "192.168.1.71"
          ip_range_end              = "192.168.1.79"
          gateway                   = "192.168.1.1"
          prefix                    = 24
          dns_servers               = ["192.168.1.3"]

          source_node   = "node03"
          template_id   = 9004
          allowed_nodes = ["node03"]

          cp_replicas = 1
          wk_replicas = 2

          cp_disk_size           = 20
          cp_memory              = 4096
          cp_cores               = 4
          wk_disk_size           = 30
          wk_memory              = 8192
          wk_cores               = 8
          skip_cloud_init_status = false
          skip_qemu_guest_agent  = false
          provider_id_injection  = false

          cni_manifest_url = "https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml"

          autoscaler_enabled = true
          autoscaler_min     = 2
          autoscaler_max     = 4
        },
        {
          cluster_type              = "rke2"
          name                      = "toolz"
          kubernetes_version        = "v1.33.0"
          rke2_version              = "v1.33.1+rke2r1"
          control_plane_endpoint_ip = "192.168.1.30"
          ip_range_start            = "192.168.1.31"
          ip_range_end              = "192.168.1.49"
          gateway                   = "192.168.1.1"
          prefix                    = 24
          dns_servers               = ["192.168.1.3", "8.8.4.4"]

          source_node        = "node03"
          template_id        = 9006
          allowed_nodes      = ["node03"]
          kube_vip_interface = "ens18"

          cp_replicas = 1
          wk_replicas = 1

          cp_disk_size = 50
          cp_memory    = 8192
          cp_cores     = 8
          wk_disk_size = 100
          wk_memory    = 16384
          wk_cores     = 8

          autoscaler_enabled = true
          autoscaler_min     = 1
          autoscaler_max     = 5

          extra_wk_enabled   = true
          extra_wk_replicas  = 1
          extra_wk_cores     = 36
          extra_wk_memory    = 16384
          extra_wk_disk_size = 100
          extra_wk_taints    = ["dedicated=ollama:NoSchedule"]
          extra_wk_labels    = { "dedicated" = "ollama" }
        },
        {
          cluster_type              = "k3s"
          name                      = "media"
          k3s_version               = "v1.30.6+k3s1"
          control_plane_endpoint_ip = "192.168.1.50"
          ip_range_start            = "192.168.1.51"
          ip_range_end              = "192.168.1.55"
          gateway                   = "192.168.1.1"
          prefix                    = 24
          dns_servers               = ["192.168.1.3"]

          source_node   = "node01"
          template_id   = 9014
          allowed_nodes = ["node01"]

          cp_replicas = 1
          wk_replicas = 0

          cp_disk_size = 50
          cp_memory    = 10240
          cp_cores     = 4

          disable_components = []
          autoscaler_enabled = false
        },
        # {
        #   cluster_type              = "talos"
        #   name                      = "test"
        #   kubernetes_version        = "v1.33.0"
        #   control_plane_endpoint_ip = "192.168.1.60"
        #   ip_range_start            = "192.168.1.61"
        #   ip_range_end              = "192.168.1.66"
        #   gateway                   = "192.168.1.1"
        #   prefix                    = 24
        #   dns_servers               = ["192.168.1.3", "8.8.4.4"]

        #   source_node   = "node03"
        #   template_id   = 9005
        #   allowed_nodes = ["node03"]

        #   cp_replicas = 1
        #   wk_replicas = 0

        #   cp_disk_size = 20
        #   cp_memory    = 8192
        #   cp_cores     = 8
        #   wk_disk_size = 30
        #   wk_memory    = 8192
        #   wk_cores     = 8
        # },
        # {
        #   cluster_type              = "talos"
        #   name                      = "test"
        #   kubernetes_version        = "v1.33.0"
        #   control_plane_endpoint_ip = "192.168.1.80"
        #   ip_range_start            = "192.168.1.81"
        #   ip_range_end              = "192.168.1.85"
        #   gateway                   = "192.168.1.1"
        #   prefix                    = 24
        #   dns_servers               = ["192.168.1.3", "8.8.4.4"]

        #   source_node   = "node03"
        #   template_id   = 9005
        #   allowed_nodes = ["node03"]

        #   cp_replicas = 1
        #   wk_replicas = 1

        #   cp_disk_size = 20
        #   cp_memory    = 4096
        #   cp_cores     = 4
        #   wk_disk_size = 20
        #   wk_memory    = 4096
        #   wk_cores     = 4

        #   autoscaler_enabled = false
        # },
        # {
        #   cluster_type              = "kubeadm"
        #   name                      = "kubeadm-test"
        #   kubernetes_version        = "v1.31.4"
        #   control_plane_endpoint_ip = "192.168.1.100"
        #   ip_range_start            = "192.168.1.101"
        #   ip_range_end              = "192.168.1.105"
        #   gateway                   = "192.168.1.1"
        #   prefix                    = 24
        #   dns_servers               = ["192.168.1.3"]

        #   source_node   = "node03"
        #   template_id   = 9004
        #   allowed_nodes = ["node03"]

        #   cp_replicas = 1
        #   wk_replicas = 1

        #   cp_disk_size           = 20
        #   cp_memory              = 4096
        #   cp_cores               = 4
        #   wk_disk_size           = 20
        #   wk_memory              = 4096
        #   wk_cores               = 4
        #   skip_cloud_init_status = false
        #   skip_qemu_guest_agent  = false
        #   provider_id_injection  = false

        #   cni_manifest_url = "https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml"

        #   autoscaler_enabled = false
        # },
        # {
        #   cluster_type              = "k3s"
        #   name                      = "k3s-test"
        #   k3s_version               = "v1.30.6+k3s1"
        #   control_plane_endpoint_ip = "192.168.1.110"
        #   ip_range_start            = "192.168.1.111"
        #   ip_range_end              = "192.168.1.115"
        #   gateway                   = "192.168.1.1"
        #   prefix                    = 24
        #   dns_servers               = ["192.168.1.3"]

        #   source_node   = "node03"
        #   template_id   = 9004
        #   allowed_nodes = ["node03"]

        #   cp_replicas = 1
        #   wk_replicas = 0

        #   cp_disk_size = 20
        #   cp_memory    = 8192
        #   cp_cores     = 8
        #   wk_disk_size = 20
        #   wk_memory    = 4096
        #   wk_cores     = 4

        #   disable_components = []
        #   autoscaler_enabled = false
        # }
      ]
    }
    toolz = {
      kubernetes_context  = "toolz"
      crds_installed      = true
      istio_CRDs          = false
      vault_addr          = "https://vault.toolz.homelabz.eu"
      vault_storage_class = "local-path"
      vault_ingress_annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = "vault.toolz.homelabz.eu"
        "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
      }
      vault_ingress_host       = "vault.toolz.homelabz.eu"
      argocd_ingress_class     = "nginx"
      argocd_ingress_enabled   = true
      argocd_domain            = "argocd.toolz.homelabz.eu"
      argocd_install_bootstrap = true
      teleport = {
        apps = {
          "harbor"   = "http://harbor-portal.harbor.svc.cluster.local"
          "vault"    = "http://vault.vault.svc.cluster.local:8200"
          "minio"    = "https://minio.homelabz.eu:9001"
          "longhorn" = "http://longhorn-frontend.longhorn-system.svc.cluster.local"
        }
        databases = {}
        roles     = "kube,app"
      }
      longhorn = {
        ingress_host       = "longhorn.toolz.homelabz.eu"
        ingress_class_name = "nginx"
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = "longhorn.toolz.homelabz.eu"
          "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
        }
      }
      kubevirt = {
        ingress_class_name    = "nginx"
        cdi_uploadproxy_host  = "cdi-uploadproxy.toolz.homelabz.eu"
        virt_exportproxy_host = "kubevirt-exportproxy.toolz.homelabz.eu"
      }
      prometheus_namespaces = [
        # "cluster1",
        # "cluster2",
        # "cluster3",
        "kubevirt",
        "teleport-agent",
        "observability",
        "external-dns",
        "external-secrets",
        "kube-system",
        # "cabpt-system",
        # "cacppt-system",
        # "capi-ipam-in-cluster-system",
        # "capi-system",
        # "capmox-system"
      ]
      metallb_create_ip_pool    = true
      metallb_ip_pool_addresses = ["192.168.1.40-192.168.1.49"]

      vault_memory_request = "300Mi"
      vault_cpu_request    = "100m"
      vault_memory_limit   = "600Mi"
      vault_cpu_limit      = "300m"

      prometheus_memory_request = "256Mi"
      prometheus_memory_limit   = "512Mi"

      ollama = {
        ingress_host       = "ollama.toolz.homelabz.eu"
        webui_ingress_host = "chat.toolz.homelabz.eu"
        kiwix_url          = "https://wikipedia.homelabz.eu"
        paperless_url      = "https://paperless.homelabz.eu"
        extra_ollama_urls  = ["http://192.168.1.99:11434"]
        openai_api_endpoints = [
          {
            url     = "http://192.168.1.99:1234/v1"
            api_key = "lm-studio" #pragma: allowlist secret
          }
        ]
      }
    }
    observability = {
      kubernetes_context = "k8s-observability"
      crds_installed     = true
    }
    home = {
      kubernetes_context = "home"
      crds_installed     = true
      kiwix = {
        ingress_host = "wikipedia.homelabz.eu"
      }
      paperless_ngx = {
        ingress_host = "paperless.homelabz.eu"
      }
    }
    media = {
      kubernetes_context = "media"
      crds_installed     = true
      prowlarr = {
        ingress_host = "prowlarr.homelabz.eu"
      }
      radarr = {
        ingress_host = "radarr.homelabz.eu"
      }
      sonarr = {
        ingress_host = "sonarr.homelabz.eu"
      }
      qbittorrent = {
        ingress_host = "qbittorrent.homelabz.eu"
      }
      plex = {
        ingress_host = "plex.homelabz.eu"
      }
    }
    prod = {
      kubernetes_context     = "prod"
      crds_installed         = true
      istio_CRDs             = true
      argocd_ingress_class   = "istio"
      argocd_ingress_enabled = false
      argocd_domain          = "argocd.homelabz.eu"
      gateway_dns_names = [
        "api.cks.homelabz.eu",
        "cks.homelabz.eu",
        "argocd.homelabz.eu",
      ]
      teleport = {
        apps = {
          "cks" = "http://cks-frontend.default.svc.cluster.local:3000"
        }
        databases = {}
        roles     = "kube,app"
      }
      prometheus_namespaces     = []
      prometheus_memory_limit   = "1024Mi"
      prometheus_memory_request = "256Mi"
      prometheus_storage_size   = "2Gi"
      metallb_create_ip_pool    = true
      metallb_ip_pool_addresses = ["192.168.1.81-192.168.1.90"]
    }
  }
}
