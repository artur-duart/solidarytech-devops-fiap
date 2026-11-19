output "github_actions_role_arn" {
  description = "ARN da role que o GitHub Actions assume via OIDC."
  value       = aws_iam_role.github_actions.arn
}

output "ecr_repositories" {
  description = "URL de cada repositório de imagens."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}
