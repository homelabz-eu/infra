resource "cloudflare_zone" "main" {
  account = {
    id = var.cloudflare_account_id
  }
  name = var.cloudflare_zone_name
}

resource "cloudflare_dns_record" "github_pages" {
  for_each = { for k, v in var.repositories : k => v if try(v.has_pages, false) }

  zone_id = cloudflare_zone.main.id
  name    = coalesce(each.value.pages_subdomain, each.key)
  type    = "CNAME"
  content = "${var.github_org}.github.io"
  proxied = false
  ttl     = 1
}

resource "cloudflare_dns_record" "vm" {
  for_each = var.vm_dns_records

  zone_id = cloudflare_zone.main.id
  name    = each.value.domain
  type    = "A"
  content = each.value.ip
  proxied = false
  ttl     = 1
}
