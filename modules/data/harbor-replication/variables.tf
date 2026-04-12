variable "registries" {
  type = map(object({
    endpoint_url  = string
    provider_name = string
    description   = optional(string, "")
    access_key    = optional(string, "")
    access_secret = optional(string, "")
  }))
}

variable "images" {
  type = map(object({
    registry_key = string
    name         = string
    tag          = optional(string, "**")
  }))
}

variable "helm_charts_project" {
  type    = bool
  default = true
}
