module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
}

module "helm" {
  source = "../../base/helm"

  release_name     = "ollama"
  namespace        = module.namespace.name
  chart            = "ollama"
  repository       = "oci://registry.homelabz.eu/helm-charts"
  chart_version    = var.chart_version
  timeout          = 600
  create_namespace = false

  values_files = [
    <<-EOT
      image:
        repository: registry.homelabz.eu/mirror-dockerhub/ollama/ollama

      ollama:
        gpu:
          enabled: false
        models:
          pull:
            - ${var.model}
            - nomic-embed-text

      extraEnv:
        - name: OLLAMA_NUM_PARALLEL
          value: "1"
        - name: OLLAMA_MAX_LOADED_MODELS
          value: "1"
        - name: OLLAMA_FLASH_ATTENTION
          value: "true"
        - name: OLLAMA_KEEP_ALIVE
          value: "24h"

      resources:
        requests:
          cpu: ${var.cpu_request}
          memory: ${var.memory_request}
        limits:
          cpu: ${var.cpu_limit}
          memory: ${var.memory_limit}

      persistentVolume:
        enabled: ${var.persistence_enabled}
        size: ${var.persistence_size}
        storageClass: ${var.storage_class}

      livenessProbe:
        enabled: true
        initialDelaySeconds: 60
        periodSeconds: 10
        failureThreshold: 10

      readinessProbe:
        enabled: true
        initialDelaySeconds: 30
        periodSeconds: 5

%{if length(var.tolerations) > 0~}
      tolerations:
%{for t in var.tolerations~}
        - key: "${t.key}"
          operator: "${t.operator}"
          value: "${t.value}"
          effect: "${t.effect}"
%{endfor~}
%{endif~}
%{if length(var.node_selector) > 0~}
      nodeSelector:
%{for k, v in var.node_selector~}
        ${k}: "${v}"
%{endfor~}
%{endif~}

      ingress:
        enabled: ${var.ingress_enabled}
        className: ${var.ingress_class_name}
        annotations:
          external-dns.alpha.kubernetes.io/hostname: ${var.ingress_host}
          cert-manager.io/cluster-issuer: letsencrypt-prod
        hosts:
          - host: ${var.ingress_host}
            paths:
              - path: /
                pathType: Prefix
        tls:
          - secretName: ${replace(var.ingress_host, ".", "-")}-tls
            hosts:
              - ${var.ingress_host}
    EOT
  ]

  set_values = []
}

module "open_webui" {
  count  = var.webui_enabled ? 1 : 0
  source = "../../base/helm"

  release_name     = "open-webui"
  namespace        = module.namespace.name
  chart            = "open-webui"
  repository       = "oci://registry.homelabz.eu/helm-charts"
  chart_version    = var.webui_chart_version
  timeout          = 600
  create_namespace = false

  values_files = [
    <<-EOT
      image:
        repository: registry.homelabz.eu/mirror-ghcr/open-webui/open-webui

      ollama:
        enabled: false
      pipelines:
        enabled: false
      websocket:
        enabled: false

      persistence:
        enabled: true
        size: ${var.webui_persistence_size}

      ollamaUrls:
        - http://ollama.${var.namespace}.svc:11434
%{for url in var.extra_ollama_urls~}
        - ${url}
%{endfor~}

      extraEnvVars:
        - name: WEBUI_SECRET_KEY
          value: "ollama-webui-secret-key"
        - name: OLLAMA_BASE_URL
          value: "http://ollama.${var.namespace}.svc:11434"
        - name: ENABLE_RAG_WEB_SEARCH
          value: "true"
        - name: ENABLE_RAG_LOCAL_WEB_FETCH
          value: "true"
        - name: RAG_WEB_SEARCH_ENGINE
          value: "searxng"
        - name: SEARXNG_QUERY_URL
          value: "http://searxng.${var.namespace}.svc:8080/search?q=<query>&format=json"
        - name: RAG_WEB_SEARCH_RESULT_COUNT
          value: "3"
        - name: RAG_WEB_SEARCH_CONCURRENT_REQUESTS
          value: "3"
        - name: CHUNK_SIZE
          value: "500"
        - name: CHUNK_OVERLAP
          value: "50"
        - name: RAG_EMBEDDING_ENGINE
          value: "ollama"
        - name: RAG_EMBEDDING_MODEL
          value: "nomic-embed-text"
%{if length(var.openai_api_endpoints) > 0~}
        - name: OPENAI_API_BASE_URLS
          value: "${join(";", [for ep in var.openai_api_endpoints : ep.url])}"
        - name: OPENAI_API_KEYS
          value: "${join(";", [for ep in var.openai_api_endpoints : ep.api_key])}"
%{endif~}
%{if var.pgvector_db_url != ""~}
        - name: DATABASE_URL
          value: "${var.pgvector_db_url}"
%{endif~}

      ingress:
        enabled: ${var.webui_ingress_enabled}
        class: ${var.ingress_class_name}
        annotations:
          external-dns.alpha.kubernetes.io/hostname: ${var.webui_ingress_host}
          cert-manager.io/cluster-issuer: letsencrypt-prod
        host: ${var.webui_ingress_host}
        tls: true
        existingSecret: ${replace(var.webui_ingress_host, ".", "-")}-tls

    EOT
  ]

  set_values = []

  depends_on = [kubernetes_deployment.searxng]
}

resource "kubernetes_config_map" "searxng_settings" {
  count = var.webui_enabled ? 1 : 0

  metadata {
    name      = "searxng-settings"
    namespace = module.namespace.name
  }

  data = {
    "settings.yml" = yamlencode({
      use_default_settings = {
        engines = {
          keep_only = []
        }
      }
      server = {
        secret_key   = "searxng-secret-key" # pragma: allowlist secret
        bind_address = "0.0.0.0"
        port         = 8080
      }
      search = {
        formats      = ["html", "json"]
        default_lang = "en"
      }
      engines = concat(
        [
          {
            name          = "kiwix"
            engine        = "xpath"
            shortcut      = "kw"
            search_url    = "${var.kiwix_url}/search?pattern={query}&pageLength=10"
            url_xpath     = "//div[@class='results']//li/a/@href"
            title_xpath   = "//div[@class='results']//li/a/text()"
            content_xpath = "//div[@class='results']//li/cite/text()"
            categories    = ["general"]
            disabled      = false
            timeout       = 10.0
          },
        ],
        var.paperless_url != "" && var.paperless_api_token != "" ? [
          {
            name                 = "paperless"
            engine               = "json_engine"
            shortcut             = "pl"
            search_url           = "${var.paperless_url}/api/documents/?query={query}&page_size=5"
            results_query        = "results"
            url_query            = "id"
            url_prefix           = "${var.paperless_url}/documents/"
            title_query          = "title"
            content_query        = "__search_hit__/highlights"
            content_html_to_text = true
            categories           = ["general"]
            disabled             = false
            timeout              = 10.0
            headers              = { Authorization = "Token ${var.paperless_api_token}" }
          },
        ] : []
      )
    })
  }
}

resource "kubernetes_deployment" "searxng" {
  count = var.webui_enabled ? 1 : 0

  metadata {
    name      = "searxng"
    namespace = module.namespace.name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "searxng"
      }
    }

    template {
      metadata {
        labels = {
          app = "searxng"
        }
      }

      spec {
        container {
          name  = "searxng"
          image = "registry.homelabz.eu/mirror-dockerhub/searxng/searxng:latest"

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "settings"
            mount_path = "/etc/searxng/settings.yml"
            sub_path   = "settings.yml"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }
        }

        volume {
          name = "settings"

          config_map {
            name = kubernetes_config_map.searxng_settings[0].metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "searxng" {
  count = var.webui_enabled ? 1 : 0

  metadata {
    name      = "searxng"
    namespace = module.namespace.name
  }

  spec {
    selector = {
      app = "searxng"
    }

    port {
      port        = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_config_map" "mcpo_config" {
  count = var.webui_enabled ? 1 : 0

  metadata {
    name      = "mcpo-config"
    namespace = module.namespace.name
  }

  data = {
    "config.json" = jsonencode({
      mcpServers = {
        fetch = {
          command = "uvx"
          args    = ["mcp-server-fetch"]
        }
        memory = {
          command = "uvx"
          args    = ["mcp-server-memory"]
        }
      }
    })
  }
}

resource "kubernetes_deployment" "mcpo" {
  count = var.webui_enabled ? 1 : 0

  metadata {
    name      = "mcpo"
    namespace = module.namespace.name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mcpo"
      }
    }

    template {
      metadata {
        labels = {
          app = "mcpo"
        }
      }

      spec {
        container {
          name  = "mcpo"
          image = "registry.homelabz.eu/mirror-ghcr/open-webui/mcpo:latest"

          args = ["--config", "/config/config.json", "--port", "8000"]

          port {
            container_port = 8000
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        volume {
          name = "config"

          config_map {
            name = kubernetes_config_map.mcpo_config[0].metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mcpo" {
  count = var.webui_enabled ? 1 : 0

  metadata {
    name      = "mcpo"
    namespace = module.namespace.name
  }

  spec {
    selector = {
      app = "mcpo"
    }

    port {
      port        = 8000
      target_port = 8000
    }
  }
}
