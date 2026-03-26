variable "namespace" {
  type    = string
  default = "paperless-ngx"
}

variable "chart_version" {
  type    = string
  default = "0.24.1"
}

variable "storage_class" {
  type    = string
  default = "local-path"
}

variable "media_storage_size" {
  type    = string
  default = "150Gi"
}

variable "consume_storage_size" {
  type    = string
  default = "150Gi"
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

variable "db_host" {
  type    = string
  default = "192.168.1.100"
}

variable "db_name" {
  type    = string
  default = "paperless"
}

variable "db_user" {
  type    = string
  default = "postgres"
}

variable "db_pass" {
  type      = string
  sensitive = true
}

variable "redis_url" {
  type      = string
  sensitive = true
}

variable "admin_user" {
  type    = string
  default = "admin"
}

variable "admin_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "secret_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "task_workers" {
  type    = number
  default = 2
}

variable "time_zone" {
  type    = string
  default = "Europe/Lisbon"
}
