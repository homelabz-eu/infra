resource "gitlab_group" "org" {
  name             = var.github_org
  path             = var.github_org
  description      = "Homelab infrastructure and applications"
  visibility_level = "private"
}

resource "gitlab_project" "repo" {
  for_each = var.repositories

  name         = each.key
  description  = each.value.description
  namespace_id = gitlab_group.org.id

  visibility_level                 = "private"
  issues_access_level              = "enabled"
  merge_requests_access_level      = "enabled"
  wiki_access_level                = "disabled"
  snippets_access_level            = "disabled"
  remove_source_branch_after_merge = true
  shared_runners_enabled           = true
}
