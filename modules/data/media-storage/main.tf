module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
}

resource "kubernetes_persistent_volume" "media_data" {
  metadata {
    name = "media-data"
  }
  spec {
    capacity = {
      storage = var.storage_size
    }
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "manual"
    persistent_volume_source {
      host_path {
        path = var.host_path
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "media_data" {
  metadata {
    name      = "media-data"
    namespace = module.namespace.name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "manual"
    resources {
      requests = {
        storage = var.storage_size
      }
    }
    volume_name = kubernetes_persistent_volume.media_data.metadata[0].name
  }
}
