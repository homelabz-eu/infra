resource "github_organization_settings" "org" {
  billing_email = "pedropasouza@outlook.com"
  name          = "homelabz-eu"
  description   = "Homelab infrastructure and applications"
  blog          = "https://homelabz.eu"
}

resource "github_actions_organization_permissions" "org" {
  allowed_actions      = "all"
  enabled_repositories = "all"
}

resource "github_actions_runner_group" "default" {
  name                       = "Default"
  visibility                 = "selected"
  selected_repository_ids    = [for repo in github_repository.repo : repo.repo_id]
  allows_public_repositories = true

  depends_on = [github_repository.repo]
}

resource "github_repository" "repo" {
  for_each = var.repositories

  name        = each.key
  description = each.value.description
  visibility  = each.value.visibility

  has_issues   = true
  has_projects = false
  has_wiki     = false

  delete_branch_on_merge = true
  auto_init              = false

  dynamic "pages" {
    for_each = try(each.value.has_pages, false) ? [1] : []
    content {
      build_type = "workflow"
      cname      = "${coalesce(each.value.pages_subdomain, each.key)}.${var.cloudflare_zone_name}"
    }
  }
}
