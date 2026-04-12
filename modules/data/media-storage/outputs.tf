output "namespace" {
  value = module.namespace.name
}

output "pvc_name" {
  value = kubernetes_persistent_volume_claim.media_data.metadata[0].name
}
