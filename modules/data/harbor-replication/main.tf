resource "harbor_registry" "upstream" {
  for_each      = var.registries
  provider_name = each.value.provider_name
  name          = each.key
  endpoint_url  = each.value.endpoint_url
  description   = each.value.description
  access_id     = each.value.access_key != "" ? each.value.access_key : null
  access_secret = each.value.access_secret != "" ? each.value.access_secret : null
}

resource "harbor_project" "mirror" {
  for_each               = var.registries
  name                   = "mirror-${each.key}"
  vulnerability_scanning = true
  public                 = true
}

resource "harbor_replication" "pull" {
  for_each    = var.images
  name        = "pull-${each.key}"
  action      = "pull"
  registry_id = harbor_registry.upstream[each.value.registry_key].registry_id
  override    = true
  enabled     = true

  dest_namespace         = harbor_project.mirror[each.value.registry_key].name
  dest_namespace_replace = 0

  filters {
    name = each.value.name
  }

  filters {
    tag = each.value.tag
  }
}

resource "harbor_project" "helm_charts" {
  count                  = var.helm_charts_project ? 1 : 0
  name                   = "helm-charts"
  vulnerability_scanning = false
  public                 = true
}
