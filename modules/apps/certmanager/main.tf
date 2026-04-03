/**
 * Cert Manager Module
 *
 * This module deploys cert-manager with a Cloudflare DNS solver for ACME challenges.
 */

module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = merge(
    {
      "kubernetes.io/metadata.name" = var.namespace
    },
    var.cloudflare_secret_ref != null ? {
      "cluster-secrets" = "true" # pragma: allowlist secret
    } : {}
  )
}

// Deploy cert-manager via Helm
module "helm" {
  source = "../../base/helm"

  release_name     = "cert-manager"
  namespace        = module.namespace.name
  chart            = "cert-manager"
  repository       = "oci://registry.homelabz.eu/helm-charts"
  chart_version    = var.chart_version
  timeout          = 300
  create_namespace = false
  values_files = [
    <<-EOT
      installCRDs: true
      image:
        repository: registry.homelabz.eu/mirror-quay/jetstack/cert-manager-controller
      webhook:
        image:
          repository: registry.homelabz.eu/mirror-quay/jetstack/cert-manager-webhook
      cainjector:
        image:
          repository: registry.homelabz.eu/mirror-quay/jetstack/cert-manager-cainjector
      acmesolver:
        image:
          repository: registry.homelabz.eu/mirror-quay/jetstack/cert-manager-acmesolver
      startupapicheck:
        image:
          repository: registry.homelabz.eu/mirror-quay/jetstack/cert-manager-startupapicheck
    EOT
  ]
  set_values = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}

module "cloudflare_secret" {
  count  = var.issuer_type == "acme" && var.cloudflare_secret_ref == null ? 1 : 0
  source = "../../base/credentials"

  name              = "cloudflare-api-token"
  namespace         = module.namespace.name
  create_secret     = true
  generate_password = false

  data = {
    "api-token" = var.cloudflare_secret
  }
}

locals {
  cloudflare_secret_name = var.cloudflare_secret_ref != null ? var.cloudflare_secret_ref.name : try(module.cloudflare_secret[0].name, "cloudflare-api-token")
  cloudflare_secret_key  = var.cloudflare_secret_ref != null ? var.cloudflare_secret_ref.key : "api-token"
}

resource "kubernetes_manifest" "letsencrypt_issuer" {
  count      = var.install_crd && var.issuer_type == "acme" ? 1 : 0
  depends_on = [module.helm]

  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = var.cluster_issuer
    }
    "spec" = {
      "acme" = {
        "server" = var.acme_server
        "email"  = var.email
        "privateKeySecretRef" = {
          "name" = var.cluster_issuer
        }
        "solvers" = [
          {
            "dns01" = {
              "cloudflare" = {
                "email" = var.email
                "apiTokenSecretRef" = {
                  "name" = local.cloudflare_secret_name
                  "key"  = local.cloudflare_secret_key
                }
              }
            }
          }
        ]
      }
    }
  }
}

resource "kubernetes_manifest" "selfsigned_issuer" {
  count      = var.install_crd && var.issuer_type == "selfsigned" ? 1 : 0
  depends_on = [module.helm]

  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = var.cluster_issuer
    }
    "spec" = {
      "selfSigned" = {}
    }
  }
}
