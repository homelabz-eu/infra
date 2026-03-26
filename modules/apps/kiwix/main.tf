module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
}

resource "kubernetes_stateful_set" "kiwix" {
  metadata {
    name      = "kiwix"
    namespace = module.namespace.name
  }

  spec {
    service_name = "kiwix"
    replicas     = 1

    selector {
      match_labels = {
        app = "kiwix"
      }
    }

    template {
      metadata {
        labels = {
          app = "kiwix"
        }
      }

      spec {
        container {
          name  = "kiwix-serve"
          image = "ghcr.io/kiwix/kiwix-serve:3.7.0"

          args = ["/data/*.zim"]

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "zim-data"
            mount_path = "/data"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "2000m"
              memory = "2Gi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 30
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            failure_threshold     = 3
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "zim-data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class

        resources {
          requests = {
            storage = var.storage_size
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "kiwix" {
  metadata {
    name      = "kiwix"
    namespace = module.namespace.name
  }

  spec {
    selector = {
      app = "kiwix"
    }

    port {
      port        = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_ingress_v1" "kiwix" {
  count = var.ingress_enabled ? 1 : 0

  metadata {
    name      = "kiwix"
    namespace = module.namespace.name

    annotations = {
      "external-dns.alpha.kubernetes.io/hostname" = var.ingress_host
      "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name

    tls {
      secret_name = "${replace(var.ingress_host, ".", "-")}-tls"
      hosts       = [var.ingress_host]
    }

    rule {
      host = var.ingress_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.kiwix.metadata[0].name

              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}
