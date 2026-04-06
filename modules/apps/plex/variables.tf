variable "namespace" {
  type    = string
  default = "plex"
}

variable "chart_version" {
  type    = string
  default = "0.6.0"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "storage_class" {
  type    = string
  default = "local-path"
}

variable "config_storage_size" {
  type    = string
  default = "5Gi"
}

variable "media_pvc_name" {
  type    = string
  default = "media-data"
}

variable "host_network" {
  type    = bool
  default = true
}

variable "ingress_enabled" {
  type    = bool
  default = false
}

variable "ingress_host" {
  type    = string
  default = ""
}

variable "ingress_class_name" {
  type    = string
  default = "traefik"
}

variable "claim_token" {
  type      = string
  sensitive = true
  default   = ""
}
