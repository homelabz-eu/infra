resource "pihole_dns_record" "vm" {
  for_each = var.vm_dns_records

  domain = "${each.value.domain}.${var.cloudflare_zone_name}"
  ip     = each.value.ip
}
