variable "namespace" {
  type    = string
  default = "flaresolverr"
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

variable "timezone" {
  type    = string
  default = "Europe/Lisbon"
}
