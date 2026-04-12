variable "namespace" {
  type    = string
  default = "sonarr"
}

variable "create_namespace" {
  type    = bool
  default = true
}

variable "chart_version" {
  type    = string
  default = "3.7.3"
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
  default = "2Gi"
}

variable "media_pvc_name" {
  type    = string
  default = "media-data"
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

variable "puid" {
  type    = number
  default = 1000
}

variable "pgid" {
  type    = number
  default = 1000
}

variable "timezone" {
  type    = string
  default = "Europe/Lisbon"
}
