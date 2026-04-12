output "mirror_projects" {
  description = "Map of mirror project names"
  value       = { for k, v in harbor_project.mirror : k => v.name }
}

output "helm_charts_project" {
  description = "Name of the helm-charts project"
  value       = var.helm_charts_project ? harbor_project.helm_charts[0].name : ""
}
