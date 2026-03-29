variable "namespace" {
  type    = string
  default = "ollama"
}

variable "chart_version" {
  type    = string
  default = "1.52.0"
}

variable "model" {
  type    = string
  default = "qwen3.5:2b"
}

variable "cpu_request" {
  type    = string
  default = "500m"
}

variable "cpu_limit" {
  type    = string
  default = "36000m"
}

variable "memory_request" {
  type    = string
  default = "2Gi"
}

variable "memory_limit" {
  type    = string
  default = "14Gi"
}

variable "persistence_enabled" {
  type    = bool
  default = true
}

variable "persistence_size" {
  type    = string
  default = "15Gi"
}

variable "storage_class" {
  type    = string
  default = "longhorn"
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
  default = "nginx"
}

variable "tolerations" {
  type = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  default = []
}

variable "node_selector" {
  type    = map(string)
  default = {}
}

variable "webui_enabled" {
  type    = bool
  default = false
}

variable "webui_chart_version" {
  type    = string
  default = "12.10.0"
}

variable "webui_ingress_enabled" {
  type    = bool
  default = false
}

variable "webui_ingress_host" {
  type    = string
  default = ""
}

variable "pgvector_db_url" {
  type    = string
  default = ""
}

variable "webui_persistence_size" {
  type    = string
  default = "20Gi"
}

variable "kiwix_url" {
  type    = string
  default = ""
}

variable "paperless_url" {
  type    = string
  default = ""
}

variable "paperless_api_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "extra_ollama_urls" {
  type    = list(string)
  default = []
}

variable "openai_api_endpoints" {
  type = list(object({
    url     = string
    api_key = string
  }))
  default   = []
  sensitive = true
}
