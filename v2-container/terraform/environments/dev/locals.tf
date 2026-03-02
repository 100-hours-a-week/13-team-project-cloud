locals {
  project     = "moyeobab"
  environment = "dev"
  version     = "v2"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    Version     = local.version
    ManagedBy   = "terraform"
  }

  # GitHub Actions OIDC
  github_org   = "100-hours-a-week"
  github_repos = ["13-team-project-ai", "13-team-project-be", "13-team-project-fe"]

  oidc_subjects = flatten([
    for repo in local.github_repos : [
      "repo:${local.github_org}/${repo}:ref:refs/heads/develop",
      "repo:${local.github_org}/${repo}:environment:develop",
    ]
  ])

}
