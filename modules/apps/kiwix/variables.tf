variable "namespace" {
  type    = string
  default = "kiwix"
}

variable "storage_size" {
  type    = string
  default = "300Gi"
}

variable "storage_class" {
  type    = string
  default = "local-path"
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
