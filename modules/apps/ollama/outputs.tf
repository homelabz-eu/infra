output "namespace" {
  value = module.namespace.name
}

output "service_url" {
  value = "http://ollama.${module.namespace.name}.svc:11434"
}
