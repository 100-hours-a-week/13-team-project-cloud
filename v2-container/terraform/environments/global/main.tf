# =============================================================================
# GitHub Actions OIDC Provider (계정당 1개 — dev/prod 공용)
# =============================================================================
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", # pragma: allowlist secret
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd", # pragma: allowlist secret
  ]

  tags = {
    Name      = "github-actions-oidc"
    Project   = "moyeobab"
    ManagedBy = "terraform"
  }
}
